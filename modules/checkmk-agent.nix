{ config, lib, pkgs, ... }:

let

  inherit (lib) mkIf mkOption types;
  inherit (pkgs) stdenv fetchurl;
  inherit (pkgs.stdenv) mkDerivation;

  cfg = config.kibo.checkmkAgent;

  agent = mkDerivation {
    name = "checkmk-agent";
    version = "1.4.0p2";

    src = fetchurl {
      url = "https://mon.kibo.li/kibo/check_mk/agents/check_mk_agent.linux";
      sha256 = "01zv7xdzpffjjy1aakhikpbvvqdy8lsy10jk7jjd6v6fjqla5v9l";
    };

    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      mkdir -p $out/bin
      cp $src $out/bin/check_mk_agent
      chmod +x $out/bin/check_mk_agent
      patchShebangs $out/bin/check_mk_agent
    '';
  };

  mysqlPlugin = mkDerivation {
    name = "checkmk-agent-mysql";
    version = "1.4.0p2";

    src = fetchurl {
      url = "https://mon.kibo.li/kibo/check_mk/agents/plugins/mk_mysql";
      sha256 = "00w0x8pylwwidbs5s0nl4knxx6rgds67k3w1h3q314x8hwxzx9m5";
    };

    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      mkdir -p $out/bin
      cp $src $out/bin/mk_mysql
      sed -i 's#--defaults-extra-file=\$MK_CONFDIR/mysql.cfg##g' $out/bin/mk_mysql
      chmod +x $out/bin/mk_mysql
      patchShebangs $out/bin/mk_mysql
    '';
  };

  agentWithPlugins = mkDerivation {
    name = "checkmk-agent-full";

    inherit agent mysqlPlugin;

    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup

      mkdir -p $out/bin $out/lib/check_mk/plugins

      ln -s $mysqlPlugin/bin/mk_mysql $out/lib/check_mk/plugins/mk_mysql

      cat > $out/bin/check_mk_agent <<EOF
      #! $shell
      export MK_LIBDIR="$out/lib/check_mk"
      exec $agent/bin/check_mk_agent "$@"
      EOF

      chmod +x $out/bin/check_mk_agent
    '';
  };

  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcOPSnFqxA0krADDHhuNyNEcmO4GE2Jf/mYqKucKu4KRCeEAeFxcpQWs+EE0TvVdBB8kbNN17vxOSPWEUBlrF/zoRov7ySEwmzz4+BY62L8Hv4PK1a4UfC6EC1I7AmExCeYD1aCToMckm8DIIibUAGV7OPX/VwkgGjjpHVGxZB0ZIcs6LoewlRi9y/BqtY97ImIEO1Jo4Y0Gc+gAy1CUdOL6L91dkAhU68W/cnVYYCnWzfmxmpjR90mKcgmgaux3I84uOb8/xd/gue9SUUq7x1X43WKPI5TD+oVRdXxaNXs8e9OT4H0iC1dpvxtDRIijrdcim2i0ILa1II1yb96sHX3BxcWsytwIZNSud8cBsaYUb9ZbHCwnw+SHxK0ErZ2lESGrM4XclgJ0Ph9Rkg/B8L+doyEEmWOHrGYknVsl7rAo53O2NhzvByIoy6CSnoQ4e/eMqox3XJLkImthf0yvC80K8w5+aTdhCDFO+DLxcl1xGPUG/2o6eymlzTnaVoHes0UC7RzZAQWTVR0geBA89lGoAp1bQ4bL+EUJITB6x40DHhjM3IZjqn3yXjNbgkJTVcWF09CZwDpGTfMfb2pif/SsNjTRYCzkVYdaIKV4+onb9rjpmzkfgscfcOIQA4kFQmVG8+V9rKDXLFv9Lcf8S7RGNyDfdk3d+ZV8//KXSjnw== kibo@mon.kibo.li";

in

{

  options.kibo.checkmkAgent = {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    agent = mkOption {
      type = types.package;
      default = agentWithPlugins;
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ cfg.agent ];

    users.users.root.openssh.authorizedKeys.keys = [
      ''command="${agent}/bin/check_mk_agent",no-port-forwarding,no-x11-forwarding,no-agent-forwarding ${sshKey}''
    ];

  };

}
