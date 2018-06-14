{ config, lib, pkgs, ... }:

with lib;

{

  options.kibo.zsh = {

    enable = mkOption {
      type = types.bool;
      default = true;
    };

  };

  config = mkIf config.kibo.zsh.enable {
    programs.zsh.enable = true;
    users.defaultUserShell = "${pkgs.zsh}/bin/zsh";
  };

}
