{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.kibo.postgresql;
  cert = config.security.acme.certs.${cfg.certName};
  copyCerts = pkgs.writeShellScript "postgresql-copy-certs" ''
    set -euo pipefail

    ${pkgs.rsync}/bin/rsync \
      -avL --chown=root:postgres --chmod=o= \
      ${lib.escapeShellArgs (builtins.map (file: "${cert.directory}/${file}") ["fullchain.pem" "key.pem"])} \
      /var/lib/postgresql/ssl/

    ${pkgs.systemd}/bin/systemctl reload --no-block postgresql
  '';
in {
  options = {
    kibo.postgresql = {
      certName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      nextPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
      };
    };
  };

  config = let
    ifCert = lib.mkIf (cfg.certName != null);
  in {
    systemd.services = {
      postgresql-certs = ifCert {
        wants = ["acme-finished-${cfg.certName}.target"];
        after = ["acme-selfsigned-${cfg.certName}.service" "acme-finished-${cfg.certName}.target"];
        wantedBy = ["acme-selfsigned-${cfg.certName}.service" "acme-finished-${cfg.certName}.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = copyCerts;
        };
      };

      postgresql = ifCert {
        wants = ["postgresql-certs.service"];
        after = ["postgresql-certs.service"];
      };

      postgresql-upgrade = lib.mkIf (cfg.nextPackage != null && cfg.nextPackage.psqlSchema > config.services.postgresql.package.psqlSchema) {
        conflicts = ["postgresql.service"];
        wants = ["postgresql-certs.service"];
        after = ["postgresql-certs.service"];
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "postgresql";
          User = "postgres";
          Group = "postgres";
          ExecStart = pkgs.writeShellScript "postgresql-upgrade" ''
            set -euxo pipefail

            NEWDATA="/var/lib/postgresql/${cfg.nextPackage.psqlSchema}"
            NEWBIN="${cfg.nextPackage}/bin"
            OLDDATA="${config.services.postgresql.dataDir}"
            OLDBIN="${config.services.postgresql.package}/bin"

            rm -rf "$NEWDATA"

            install -d -m 0700 -o postgres -g postgres "$NEWDATA"

            cd "$NEWDATA"

            "$NEWBIN/initdb" --no-sync --no-data-checksums -D "$NEWDATA"

            "$NEWBIN/pg_upgrade" \
              --old-datadir "$OLDDATA" --new-datadir "$NEWDATA" \
              --old-bindir "$OLDBIN" --new-bindir "$NEWBIN" \
              --clone --jobs "$(nproc)" --no-sync -o '-F' -O '-F'

            chmod = "$OLDDATA"
          '';
        };
      };
    };

    services.postgresql.settings = ifCert {
      ssl = true;
      ssl_cert_file = "/var/lib/postgresql/ssl/fullchain.pem";
      ssl_key_file = "/var/lib/postgresql/ssl/key.pem";
    };
  };
}
