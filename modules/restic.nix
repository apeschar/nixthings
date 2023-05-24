{
  config,
  pkgs,
  lib,
  ...
}:
with lib; {
  options = {
    kibo.restic = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };

      package = mkOption {
        type = types.package;
        default = pkgs.restic;
      };

      pool = mkOption {
        type = types.str;
        default = "rpool";
        description = ''
          ZFS pool to back up
        '';
      };

      secrets = mkOption {
        type = types.path;
        description = ''
          A file which contains environment variable definitions which Restic
          needs to do its magic. Required variables are:

          - RESTIC_REPOSITORY
          - RESTIC_PASSWORD
          - CHECK_UUID
        '';
      };

      excludeFilesystems = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
  };

  config = let
    cfg = config.kibo.restic;
  in
    mkIf cfg.enable {
      systemd.services.restic = let
        inherit (cfg) pool;
        snapshotName = "restic";
        script = pkgs.writeShellScript "restic" ''
          set -euo pipefail

          cleanup() {
            zfs destroy -f -r ${pkgs.lib.escapeShellArg "${pool}@${snapshotName}"}
          }

          snapshot() {
            zfs snapshot -r ${pkgs.lib.escapeShellArg "${pool}@${snapshotName}"}
          }

          if ! snapshot; then
            cleanup
            snapshot
          fi

          zfs list -H -o name -r ${pkgs.lib.escapeShellArg pool} | while read dataset; do
            ${pkgs.lib.concatMapStringsSep "\n" (fs: ''
              if [[ $dataset = ${pkgs.lib.escapeShellArg fs} ]]; then continue; fi
            '')
            cfg.excludeFilesystems}
            echo "Mounting filesystem: $dataset" >&2
            ramfs="/tmp/$(uuidgen)"
            mkdir "$ramfs"
            mount -t ramfs ramfs "$ramfs"
            mkdir "$ramfs/lower" "$ramfs/upper" "$ramfs/work"
            mount -t zfs "$dataset@"${pkgs.lib.escapeShellArg snapshotName} "$ramfs/lower"
            mkdir -p "/tmp/$dataset"
            mount -t overlay overlay -o "lowerdir=$ramfs/lower,upperdir=$ramfs/upper,workdir=$ramfs/work" "/tmp/$dataset"
          done

          cd /tmp

          restic backup --cache-dir /var/cache/restic --verbose ${pkgs.lib.escapeShellArg pool}
        '';
      in {
        path = with pkgs; [zfs mount util-linux cfg.package];
        serviceConfig = {
          Type = "oneshot";
          PrivateMounts = true;
          PrivateTmp = true;
          CacheDirectory = "restic";
          Environment = [
            "HC_API_URL=https://ping.kibo.li"
          ];
          EnvironmentFile = cfg.secrets;
          ExecStart = pkgs.lib.escapeShellArgs ["${pkgs.runitor}/bin/runitor" script];
          ExecStopPost = pkgs.lib.escapeShellArgs ["${pkgs.zfs}/bin/zfs" "destroy" "-f" "-r" "${pool}@${snapshotName}"];
        };
        startAt = "hourly";
        stopIfChanged = false;
        restartIfChanged = false;
      };

      systemd.services.restic-init = {
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = cfg.secrets;
          ExecStart = pkgs.lib.escapeShellArgs ["${cfg.package}/bin/restic" "init"];
        };
      };

      environment.systemPackages = [
        cfg.package
        (pkgs.writeShellScriptBin "restic-authenticated" ''
          set -euo pipefail

          set -a
          source /run/secrets/restic
          set +a

          exec ${cfg.package}/bin/restic "$@"
        '')
      ];
    };
}
