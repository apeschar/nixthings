{ config, lib, pkgs, ... }:

let

  inherit (lib) concatMapStrings mkIf mkOption types;

  cfg = config.kibo.backup-mysql;

  excludeDatabases = [
    "information_schema"
    "performance_schema"
  ] ++ cfg.excludeDatabases;

in

{

  options.kibo.backup-mysql = {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    destination = mkOption {
      type = types.str;
      example = "piotr@backup.cx:mysql";
    };

    excludeDatabases = mkOption {
      type = types.listOf types.str;
      default = [];
    };

  };

  config = lib.mkIf cfg.enable {

    systemd.services.backup-mysql = {
      serviceConfig = {
        Type = "simple";
      };
      path = with pkgs; [ coreutils mariadb rsync config.programs.ssh.package ];
      environment = {
        HOME = "/root";
      };
      script = ''
        set -euo pipefail

        status=0

        tmp="$(mktemp -d)"
        cd "$tmp"

        echo "SHOW DATABASES" | mysql --skip-column-names | while read database; do
          ${concatMapStrings (db: "[[ $database = '${db}' ]] && continue\n") excludeDatabases}

          echo "$database" >&2

          if ! mysqldump --order-by-primary --single-transaction "$database" > "$database.sql"; then
            echo "Dump of $database failed!" >&2
          fi
        done

        ls -lh || true

        if ! rsync \
          -e "ssh -oStrictHostKeyChecking=no" \
          -avz --delete \
          ./ ${cfg.destination}
        then
          status=1
          echo "Rsync failed!" >&2
        fi

        cd /
        rm -r "$tmp"

        exit $status
      '';
    };

    systemd.timers.backup-mysql = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "backup-mysql.service";
        OnCalendar = "01:00";
      };
    };

  };

}
