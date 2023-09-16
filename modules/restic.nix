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
        default = "rpool/state";
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

      cacheDataset = mkOption {
        type = types.str;
        default = "rpool/local/restic";
      };

      cacheDirectory = mkOption {
        type = types.path;
        default = "/var/cache/restic";
      };
    };
  };

  config = let
    cfg = config.kibo.restic;
    excludeFilesystems = [cfg.cacheDataset] ++ cfg.excludeFilesystems;
  in
    mkIf cfg.enable {
      fileSystems.${cfg.cacheDirectory} = {
        fsType = "zfs";
        device = cfg.cacheDataset;
        options = ["noauto" "x-systemd.requires=restic-create-cache.service"];
      };

      systemd.services.restic = let
        inherit (cfg) pool;
        snapshotName = "restic";
        script = pkgs.writeShellScript "restic" ''
          set -euo pipefail

          cleanup() {
            zfs destroy -f -r ${lib.escapeShellArg "${pool}@${snapshotName}"}
          }

          snapshot() {
            zfs snapshot -r ${lib.escapeShellArg "${pool}@${snapshotName}"}
          }

          if ! snapshot; then
            echo "Snapshot creation failed; retrying after cleanup..." >&2
            cleanup
            snapshot
          fi

          zfs list -H -o name -r ${lib.escapeShellArg pool} | while read dataset; do
            ${lib.concatMapStringsSep "\n" (fs: ''
              if [[ $dataset = ${lib.escapeShellArg fs} ]]; then
                echo "Skipping filesystem: $dataset" >&2
                continue
              fi
            '')
            excludeFilesystems}
            echo "Mounting filesystem: $dataset" >&2
            ramfs="/tmp/$(uuidgen)"
            mkdir "$ramfs"
            mount -t ramfs ramfs "$ramfs"
            mkdir "$ramfs/lower" "$ramfs/upper" "$ramfs/work"
            mount -t zfs "$dataset@"${lib.escapeShellArg snapshotName} "$ramfs/lower"
            mkdir -p "/tmp/$dataset"
            mount -t overlay overlay -o "lowerdir=$ramfs/lower,upperdir=$ramfs/upper,workdir=$ramfs/work" "/tmp/$dataset"
          done

          cd /tmp

          restic backup --cache-dir ${lib.escapeShellArg cfg.cacheDirectory} --verbose ${lib.escapeShellArg pool}
        '';
      in {
        path = with pkgs; [zfs mount util-linux cfg.package];
        unitConfig = {
          RequiresMountsFor = [cfg.cacheDirectory];
        };
        serviceConfig = {
          Type = "oneshot";
          PrivateMounts = true;
          PrivateTmp = true;
          Environment = [
            "HC_API_URL=https://ping.kibo.li"
          ];
          EnvironmentFile = cfg.secrets;
          ExecStart = lib.escapeShellArgs ["${pkgs.runitor}/bin/runitor" script];
          ExecStopPost = lib.escapeShellArgs ["${pkgs.zfs}/bin/zfs" "destroy" "-f" "-r" "${pool}@${snapshotName}"];
        };
        startAt = "hourly";
        stopIfChanged = false;
        restartIfChanged = false;
      };

      systemd.services.restic-init = {
        unitConfig = {
          RequiresMountsFor = [cfg.cacheDirectory];
        };
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = cfg.secrets;
          ExecStart = lib.escapeShellArgs ["${cfg.package}/bin/restic" "init"];
        };
      };

      systemd.services.restic-create-cache = {
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.zfs}/bin/zfs create -pv -o mountpoint=legacy -o refquota=50G ${lib.escapeShellArg cfg.cacheDataset}";
        };
      };

      systemd.services.restic-prune-cache = {
        unitConfig = {
          RequiresMountsFor = [cfg.cacheDirectory];
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.escapeShellArgs ["${pkgs.findutils}/bin/find" cfg.cacheDirectory "-xdev" "-atime" "+7" "-type" "f" "-not" "-name" "*.TAG" "-delete"];
          ProtectSystem = true;
          ReadWritePaths = [cfg.cacheDirectory];
        };
        startsAt = "daily";
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
