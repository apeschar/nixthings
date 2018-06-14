{ config, lib, pkgs, ... }:

with lib;

{

  options.kibo.tools = {

    enable = mkOption {
      type = types.bool;
      default = true;
    };

  };

  config = mkIf config.kibo.zsh.enable {

    environment.systemPackages = with pkgs; [
      vim
    ];

  };

}
