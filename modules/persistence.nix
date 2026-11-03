{
  config,
  lib,
  ...
}: let
  fileSystems = config.fileSystems;
  rootIsTmpfs = (fileSystems."/" or {}).fsType or null == "tmpfs";
  # NixOS records dynamically allocated uids/gids in /var/lib/nixos. If that
  # directory is wiped at boot, ids are reallocated and persistent files end up
  # owned by unrelated accounts.
  candidates = ["/var/lib/nixos" "/var/lib" "/var"];
  persistent =
    lib.findFirst
    (path: fileSystems ? ${path} && fileSystems.${path}.fsType != "tmpfs")
    null
    candidates;
in {
  options.nixthings.allowEphemeralIdAllocations = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Permit a tmpfs root without persistent /var/lib/nixos. Only for hosts
      whose persistent data does not depend on dynamically allocated ids.
    '';
  };

  config.assertions = lib.mkIf (rootIsTmpfs && !config.boot.isContainer) [
    {
      assertion = config.nixthings.allowEphemeralIdAllocations || persistent != null;
      message = ''
        nixthings: / is tmpfs, but /var/lib/nixos is not on persistent storage.
        NixOS stores dynamic uid/gid allocations there; without it, ids are
        reshuffled at boot and files on persistent datasets change owner.
        Mount a persistent filesystem at /var/lib/nixos (neededForBoot = true).
      '';
    }
    {
      assertion =
        config.nixthings.allowEphemeralIdAllocations
        || persistent == null
        || fileSystems.${persistent}.neededForBoot;
      message = ''
        nixthings: ${toString persistent} holds /var/lib/nixos and must set
        neededForBoot = true, so it is mounted before users are created.
      '';
    }
  ];
}
