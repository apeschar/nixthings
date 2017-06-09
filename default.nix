{ config, lib, ... }:

{

  imports = [
    ./modules/backup-mysql.nix
    ./modules/backup.nix
    ./modules/ssh-keys.nix
  ];

}
