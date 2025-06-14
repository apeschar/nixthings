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
            ++ lib.optional (builtins.compareVersions old.version "0.17" < 0) (builtins.fetchurl {
              url = "https://github.com/apeschar/restic/commit/c049490ce1d83c6c7c9e579a3ad8668e408d5a30.patch";
              sha256 = "0klb6vzw95awar65hprw4i298ka521sgr0vsa28lddzjq04kh2c8";
            });
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

      startAt = mkOption {
        type = types.str;
        default = "hourly";
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
        destroySnapshotsScript = pkgs.writeShellScript "restic-destroy-snapshots" ''
          tries=30

          sleep 1

          while ! zfs list -t snapshot -Ho name ${lib.escapeShellArg pool} |
            grep ${lib.escapeShellArg "@${snapshotName}-"} |
            xargs -r -d'\n' -n 1 zfs destroy -R -f
          do
            sleep 10
            ((tries--))
            if [[ $tries -le 0 ]]; then
              echo "Could not destroy snapshots" >&2
              exit 1
            fi
          done

          echo "Successfully destroyed snapshots" >&2
        '';
        script = pkgs.writeShellScript "restic" ''
          set -euo pipefail

          ${destroySnapshotsScript}

          snapshotName=${lib.escapeShellArg snapshotName}-$(xxd -l 8 -p /dev/urandom)

          zfs snapshot -r ${lib.escapeShellArg pool}"@$snapshotName"

          zfs list -H -o name -r ${lib.escapeShellArg pool} | while read dataset; do
            ${lib.concatMapStringsSep "\n" (fs: ''
              if [[ $dataset = */restic-clone--* ]]; then
                continue
              fi
              if [[ $dataset = ${lib.escapeShellArg fs} ]]; then
                echo "Skipping filesystem: $dataset" >&2
                continue
              fi
            '')
            excludeFilesystems}
            echo "Mounting filesystem: $dataset" >&2
            cloneName=''${dataset//-/--}
            cloneName=''${dataset//\//-}
            clone=${lib.escapeShellArg (builtins.elemAt (builtins.split "/" pool) 0)}"/restic-clone--$cloneName--$snapshotName"
            zfs clone -o mountpoint=legacy "$dataset@$snapshotName" "$clone"
            mkdir -p "/tmp/$dataset"
            mount -t zfs "$clone" "/tmp/$dataset"
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
        path = with pkgs; [zfs mount util-linux cfg.package unixtools.xxd];
        environment = {
          GOGC = "20";
          # This can be removed at some point in the future
          # when this feature flag is removed from restic.
          RESTIC_FEATURES = "device-id-for-hardlinks=true";
        };
        unitConfig = {
          RequiresMountsFor = [cfg.cacheDirectory];
        };
        serviceConfig = {
          Type = "oneshot";
          PrivateMounts = true;
          PrivateTmp = true;
          EnvironmentFile = cfg.secrets;
          ExecStart = lib.escapeShellArgs ["${pkgs.runitor}/bin/runitor" script];
          ExecStopPost = destroySnapshotsScript;
          MemoryHigh = "8G";
          MemoryMax = "12G";
          MemorySwapMax = 0;
          CPUWeight = 50;
        };
        inherit (cfg) startAt;
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
