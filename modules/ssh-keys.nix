{ config, lib, pkgs, ... }:

let

  inherit (lib) mkIf mkOption types;

  cfg = config.kibo.ssh-keys;

in

{

  options.kibo.ssh-keys = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''Whether to generate a SSH key for root'';
    };

  };

  config = {

    systemd.services.ssh-keygen-root = {
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.coreutils config.programs.ssh.package ];
      script = ''
        cd /root

        if [[ ! -d .ssh ]]; then
          mkdir .ssh
        fi

        chmod 700 .ssh

        if [[ ! -f .ssh/id_rsa ]]; then
          ssh-keygen -t rsa -b 4096 -N "" -f .ssh/id_rsa
        fi

        chmod 600 .ssh/id_rsa
      '';
    };

  };

}
