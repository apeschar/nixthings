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
        default = pkgs.restic.overrideAttrs (old: {
          patches =
            old.patches
            ++ [
              (builtins.fetchurl {
                url = "https://github.com/apeschar/restic/commit/c049490ce1d83c6c7c9e579a3ad8668e408d5a30.patch";
                sha256 = "0klb6vzw95awar65hprw4i298ka521sgr0vsa28lddzjq04kh2c8";
              })
            ];
        });
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

      excludePatterns = mkOption {
        type = types.listOf types.str;
        default = [];
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

          ${lib.escapeShellArgs ([
              "restic"
              "backup"
              "--cache-dir=${cfg.cacheDirectory}"
              "--verbose"
              pool
            ]
            ++ builtins.map (path: "--exclude=${lib.optionalString (lib.hasPrefix "/" path) "/tmp"}${path}") cfg.excludePatterns)}
        '';
      in {
        path = with pkgs; [zfs mount util-linux cfg.package];
        environment = {
          GOGC = "20";
        };
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
          MemoryHigh = "8G";
          MemoryMax = "12G";
          MemorySwapMax = 0;
          CPUWeight = 50;
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
        startAt = "daily";
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
