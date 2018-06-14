{ config, lib, ... }:

{

  imports = [
    ./modules/backup-mysql.nix
    ./modules/backup.nix
    ./modules/checkmk-agent.nix
    ./modules/ssh-keys.nix
    ./modules/tools.nix
    ./modules/zsh.nix
  ];

}
