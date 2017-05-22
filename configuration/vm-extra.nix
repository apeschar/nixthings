{ config, pkgs, ... }:

{

  imports = [
    ./vm-image.nix
  ];

  nix.maxJobs = 6;
  nix.buildCores = 6;

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 8096;
    }
  ];

}
