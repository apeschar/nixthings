{ config, lib, pkgs, ... }:

{

  imports = [
    ../configuration/vm-image.nix
  ];

  config = {

    system.build.myImage = import <nixpkgs/nixos/lib/make-disk-image.nix> {
      inherit lib config pkgs;
      diskSize = 2048;
    };

  };

}
