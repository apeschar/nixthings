{
  config,
  lib,
  ...
}: let
  cfg = config.nixthings.localDns;
in {
  options.nixthings.localDns = {
    enable = lib.mkEnableOption ''
      a local caching unbound resolver used by the system instead of
      systemd-resolved. Popular names are refreshed before they expire and
      expired answers are served immediately while being refreshed, so a slow
      upstream does not block lookups. Containers with a private network
      cannot reach the loopback resolver; configure their DNS separately'';

    forwarders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["185.12.64.1" "2a01:4ff:ff00::add:1"];
      description = ''
        Upstream resolvers. Unbound falls back to full recursion when they
        fail. Empty means always recurse.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.resolved.enable = false;

    services.unbound = {
      enable = true;
      resolveLocalQueries = true;
      # Match the previous systemd-resolved behaviour (DNSSEC=false): broken
      # DNSSEC on third-party domains must not turn into lookup failures.
      enableRootTrustAnchor = false;
      settings = {
        server = {
          module-config = ''"iterator"'';
          num-threads = 4;
          so-reuseport = true;
          msg-cache-size = "64m";
          rrset-cache-size = "128m";
          prefetch = true;
          serve-expired = true;
          serve-expired-ttl = 86400;
          serve-expired-client-timeout = 0;
          hide-identity = true;
          hide-version = true;
        };
        forward-zone = lib.mkIf (cfg.forwarders != []) [
          {
            name = ".";
            forward-addr = cfg.forwarders;
            forward-first = true;
          }
        ];
      };
    };
  };
}
