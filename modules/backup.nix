{ config, lib, pkgs, ... }:

let

  inherit (lib) mkIf mkOption types;

  cfg = config.kibo.backup;

in

{

  options.kibo.backup = {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    destination = mkOption {
      type = types.str;
      example = "piotr@backup.cx:my-host";
    };

    exclude = mkOption {
      type = types.listOf types.str;
      default = [
        "/swap"
        "/swapfile"
        "/tmp"
        "/var/lib/mysql"
        "/var/tmp"
      ];
    };

  };

  config = lib.mkIf cfg.enable {

    systemd.services.backup = {
      serviceConfig = {
        Type = "simple";
      };
      path = with pkgs; [ rsync config.programs.ssh.package ];
      script = ''
        rsync \
          -e "ssh -oStrictHostKeyChecking=no" \
          -avz --rsync-path="rsync --fake-super" \
          --delete --delete-excluded \
          --one-file-system \
          --exclude-from ${
            builtins.toFile "backup-exclude" (builtins.concatStringsSep "\n" cfg.exclude)} \
          / ${cfg.destination}
      '';
    };

    systemd.timers.backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "backup.service";
        OnCalendar = "00:00";
        RandomizedDelaySec = "3h";
      };
    };

  };

}
