{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.modules.php;

  phpOptions = ''
    date.timezone = ${config.time.timeZone}
    short_open_tag = On
    memory_limit = -1
    sendmail_path = /run/wrappers/bin/sendmail -t -i

    ${cfg.extraConfig}
  '';

  phpFpmOptions = ''
    ${phpOptions}

    error_reporting = E_ALL

    upload_max_filesize = 100M
    post_max_size = 100M
    memory_limit = 512M

    ${optionalString cfg.displayErrors ''
      display_errors = On
    ''}
  '';

in

{

  options = {

    modules.php.phpPackage = mkOption {
      type = types.package;
      default = pkgs.php;
    };

    modules.php.displayErrors = mkOption {
      type = types.bool;
      default = false;
    };

    modules.php.extraConfig = mkOption {
      type = types.lines;
      default = "";
    };

  };

  config = {

    environment.systemPackages = [
      cfg.phpPackage
      (pkgs.callPackage ../pkgs/psysh/default.nix { php = cfg.phpPackage; })
    ];

    environment.etc = {
      "php.d/10-php.ini" = {
        source = "${cfg.phpPackage}/etc/php.ini";
      };
      "php.d/20-extra.ini" = {
        text = phpOptions;
      };
    };

    services.phpfpm = {
      phpPackage = cfg.phpPackage;

      phpOptions =
        ''
          zend_extension = ${cfg.phpPackage}/lib/php/extensions/opcache.so
          ${phpFpmOptions}
        '';
    };

  };

}
