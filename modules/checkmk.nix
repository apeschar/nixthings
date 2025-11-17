{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.kibo.checkmk;
  check_mk_agent = pkgs.check_mk_agent.override (_: {
    enablePluginSmart = true;
    localChecks = lib.mapAttrsToList (name: options: {inherit name;} // options) cfg.localChecks;
  });
  userOpts = _: {
    options = {
      enableCheckmkJobs = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };
in {
  options = {
    kibo.checkmk = {
      enable = lib.mkEnableOption "Check_MK agent";
      localChecks = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            script = lib.mkOption {type = lib.types.str;};
            deps = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              default = [];
            };
          };
        });
        default = {};
      };
    };

    users.users = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule userOpts);
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [check_mk_agent];

    users.users.root.openssh.authorizedKeys.keys = [
      ''restrict,command="/run/current-system/sw/bin/check_mk_agent || true" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINO8C6W9yu7jokdtA5RWJ5n4pD7zpfoOa/zz1KXz3F8C''
    ];

    systemd.services = lib.mapAttrs' (_: {name, ...}: {
      name = "checkmk-jobs-${name}";
      value = {
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = let
            dir = "/var/lib/check_mk_agent/job/${name}";
          in [
            ["${pkgs.coreutils}/bin/mkdir" "-p" dir]
            ["${pkgs.coreutils}/bin/chmod" "700" dir]
            ["${pkgs.coreutils}/bin/chown" "--" name dir]
          ];
        };
      };
    }) (lib.filterAttrs (_: u: u.enableCheckmkJobs) config.users.users);
  };
}
