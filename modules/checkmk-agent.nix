{ config, lib, pkgs, ... }:

let

  inherit (lib) mkIf mkOption types concatStrings mapAttrsToList;
  inherit (pkgs) buildEnv makeWrapper stdenv fetchurl;
  inherit (pkgs.stdenv) mkDerivation;

  cfg = config.kibo.checkmkAgent;

  agent = mkDerivation {
    name = "checkmk-agent";
    version = "1.4.0p2";

    src = fetchurl {
      url = "https://mon.kibo.li/kibo/check_mk/agents/check_mk_agent.linux";
      sha256 = "0yg3z3bzq9f5fg54ym6807ik8akkda8wlzx5r183i7g4p1ikqv97";
    };

    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup
      mkdir -p $out/bin
      cp $src $out/bin/check_mk_agent
      chmod +x $out/bin/check_mk_agent
      patchShebangs $out/bin/check_mk_agent
    '';
  };

  buildPlugin = { name, version, src, postBuild ? "", buildInputs ? [] }: mkDerivation {
    inherit name version src buildInputs;

    builder = builtins.toFile "builder.sh" ''
      source $stdenv/setup

      out=$out/lib/check_mk/plugins
      mkdir -p $out

      cp $src $out/$name
      chmod +x $out/$name
      patchShebangs $out/$name

      source ${builtins.toFile "postBuild.sh" postBuild}
    '';
  };

  plugins = {
    mysql = buildPlugin {
      name = "mk_mysql";
      version = "1.4.0p2";

      src = fetchurl {
        url = "https://mon.kibo.li/kibo/check_mk/agents/plugins/mk_mysql";
        sha256 = "00w0x8pylwwidbs5s0nl4knxx6rgds67k3w1h3q314x8hwxzx9m5";
      };

      postBuild = ''
        sed -i 's#--defaults-extra-file=\$MK_CONFDIR/mysql.cfg##g' $out/$name
      '';
    };

    rabbitmq = buildPlugin {
      name = "mk_rabbitmq";
      version = "8123feb";

      src = fetchurl {
        url = "https://raw.githubusercontent.com/disconn3ct/cmk-rabbitmq/8123feb166b2ac72bd7939a34adc6c824c10e4d6/share/check_mk/agents/plugins/rabbitmq.py";
        sha256 = "13gpj2jh2j5yc4kiy290aa0jnxyc21pnl44lpaxfn5c15j2ccjw1";
      };

      buildInputs = [ pkgs.python ];
    };
  };

  buildConfiguration = configFiles: mkDerivation {
    name = "checkmk-agent-config";

    builder = pkgs.writeScript "builder.sh" ''
      source $stdenv/setup

      mkdir -p $out/etc/check_mk

      ${concatStrings (mapAttrsToList (filename: content: ''
        cp ${pkgs.writeText filename content} $out/etc/check_mk/'${filename}'
      '') configFiles)}
    '';
  };

  buildLocalCheck = name: check: mkDerivation {
    inherit name;

    builder = pkgs.writeScript "builder.sh" ''
      source $stdenv/setup

      out=$out/lib/check_mk/local

      mkdir -p $out
      cp ${pkgs.writeScript "check.sh" check.script} $out/$name
      chmod +x $out/$name
    '';
  };

  buildLocalChecks = localChecks: mapAttrsToList buildLocalCheck localChecks;

  buildAgent = agent: plugins: configFiles: localChecks: buildEnv {
    name = "checkmk-agent-full";

    paths =
      [ agent ] ++
      plugins ++
      [ (buildConfiguration configFiles) ] ++
      (buildLocalChecks localChecks);

    pathsToLink = [ "/bin" "/lib" "/etc" ];

    buildInputs = [ makeWrapper ];

    postBuild = ''
      wrapProgram \
        $out/bin/check_mk_agent \
        --set MK_LIBDIR "$out/lib/check_mk" \
        --set MK_CONFDIR "$out/etc/check_mk"
    '';
  };

  configuredAgent = buildAgent cfg.agent cfg.plugins cfg.configFiles cfg.localChecks;

  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDcOPSnFqxA0krADDHhuNyNEcmO4GE2Jf/mYqKucKu4KRCeEAeFxcpQWs+EE0TvVdBB8kbNN17vxOSPWEUBlrF/zoRov7ySEwmzz4+BY62L8Hv4PK1a4UfC6EC1I7AmExCeYD1aCToMckm8DIIibUAGV7OPX/VwkgGjjpHVGxZB0ZIcs6LoewlRi9y/BqtY97ImIEO1Jo4Y0Gc+gAy1CUdOL6L91dkAhU68W/cnVYYCnWzfmxmpjR90mKcgmgaux3I84uOb8/xd/gue9SUUq7x1X43WKPI5TD+oVRdXxaNXs8e9OT4H0iC1dpvxtDRIijrdcim2i0ILa1II1yb96sHX3BxcWsytwIZNSud8cBsaYUb9ZbHCwnw+SHxK0ErZ2lESGrM4XclgJ0Ph9Rkg/B8L+doyEEmWOHrGYknVsl7rAo53O2NhzvByIoy6CSnoQ4e/eMqox3XJLkImthf0yvC80K8w5+aTdhCDFO+DLxcl1xGPUG/2o6eymlzTnaVoHes0UC7RzZAQWTVR0geBA89lGoAp1bQ4bL+EUJITB6x40DHhjM3IZjqn3yXjNbgkJTVcWF09CZwDpGTfMfb2pif/SsNjTRYCzkVYdaIKV4+onb9rjpmzkfgscfcOIQA4kFQmVG8+V9rKDXLFv9Lcf8S7RGNyDfdk3d+ZV8//KXSjnw== kibo@mon.kibo.li";

  localCheckOptions = {
    options = {
      script = mkOption {
        type = types.string;
      };
    };
  };

in

{

  options.kibo.checkmkAgent = {

    enable = mkOption {
      type = types.bool;
      default = false;
    };

    agent = mkOption {
      type = types.package;
      default = agent;
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = with plugins; [ mysql rabbitmq ];
    };

    configFiles = mkOption {
      type = types.attrsOf types.str;
      default = {
        "rabbitmq.cfg" = ''
          servers = [
            {
              'address':  '127.0.0.1',
              'port':     15672,
              'user':     'guest',
              'password': 'guest',
            },
          ]
        '';
      };
    };

    localChecks = mkOption {
      type = types.attrsOf (types.submodule localCheckOptions);
      default = {};
    };

  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ configuredAgent ];

    users.users.root.openssh.authorizedKeys.keys = [
      ''command="${configuredAgent}/bin/check_mk_agent",no-port-forwarding,no-x11-forwarding,no-agent-forwarding ${sshKey}''
    ];

  };

}
