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

    useAsSystemResolver = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Point /etc/resolv.conf at unbound and disable systemd-resolved. Set
        to false first when migrating a running host: unbound then starts
        next to systemd-resolved. Switching resolvers in one step stops
        systemd-resolved at the start of activation and starts unbound only
        at the end, leaving the host without DNS for the whole activation.
      '';
    };

    validateDnssec = lib.mkEnableOption ''
      DNSSEC validation. Off by default: hosts that resolve arbitrary
      third-party domains (scrapers, host checks) must not turn broken DNSSEC
      into lookup failures'';

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
    services.resolved.enable = lib.mkIf cfg.useAsSystemResolver false;

    # A config change would otherwise stop unbound at the start of activation
    # and start it at the end, leaving the host without DNS meanwhile.
    systemd.services.unbound.stopIfChanged = false;

    # glibc retries a lost UDP query only after its 5s default timeout (seen
    # once while unbound restarted). The local resolver answers in
    # milliseconds, so retry after 1s.
    networking.resolvconf.extraOptions =
      lib.mkIf cfg.useAsSystemResolver ["timeout:1" "attempts:3"];

    services.unbound = {
      enable = true;
      resolveLocalQueries = cfg.useAsSystemResolver;
      enableRootTrustAnchor = cfg.validateDnssec;
      settings = {
        server = {
          module-config =
            if cfg.validateDnssec
            then ''"validator iterator"''
            else ''"iterator"'';
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
