{
  lib,
  pkgs,
  ...
}: let
  nixPath = "nixpkgs=${pkgs.path}";
in {
  nix = {
    channel.enable = false;
    nixPath = [nixPath];
    settings.nix-path = nixPath;

    # boot.loader.grub.configurationLimit only trims boot entries; without
    # collection, old generations keep their closures in the store forever.
    # The current generation and other GC roots are always kept.
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "daily";
      randomizedDelaySec = lib.mkDefault "1h";
      options = lib.mkDefault "--delete-older-than 14d";
    };
  };
}
