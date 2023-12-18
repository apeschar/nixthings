{pkgs, ...}: let
  nixPath = "nixpkgs=${pkgs.path}";
in {
  nix = {
    channel.enable = false;
    nixPath = [nixPath];
    settings.nix-path = nixPath;
  };
}
