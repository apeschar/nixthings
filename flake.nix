{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    checkmk = {
      url = "github:BenediktSeidl/nixos-check_mk_agent-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.checkmk.follows = "checkmk-source";
    };
    checkmk-source = {
      url = "github:Checkmk/checkmk/v2.5.0p15";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    checkmk,
    ...
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs (builtins.attrNames nixpkgs.legacyPackages);
  in {
    nixosModules = {
      nixthings = {
        imports = [
          {nixpkgs.overlays = [self.overlays.default];}
          ./modules/defaults.nix
          ./modules/checkmk.nix
          ./modules/mosh.nix
          ./modules/restic.nix
          ./modules/ssh.nix
          ./modules/tools.nix
          ./modules/nix.nix
          ./modules/mdadm.nix
          ./modules/kexec.nix
          ./modules/firewall.nix
          ./modules/postgresql.nix
          ./modules/acme.nix
          {users.users.root.openssh.authorizedKeys.keys = self.lib.sshKeys.albert;}
        ];
      };
      default = self.nixosModules.nixthings;
    };

    overlays.default = lib.composeExtensions checkmk.overlays.default (_: prev: {
      check_mk_agent = prev.check_mk_agent.override {
        cmkaVersion = "2.5.0p15";
      };
    });

    checks = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;
      agent = pkgs.check_mk_agent.override {
        enablePluginSmart = true;
        localChecks = [
          {
            name = "nixthings-smoke";
            deps = [pkgs.coreutils];
            script = ''printf '%s\n' '0 "Nixthings smoke" - Local check works' '';
          }
        ];
      };
    in {
      lib-tests =
        if self.tests == []
        then pkgs.runCommand "lib-tests" {} "touch $out"
        else throw "lib tests failed: ${builtins.toJSON self.tests}";
      checkmk-agent = pkgs.runCommand "checkmk-agent-smoke" {} ''
        ${pkgs.bash}/bin/bash -n ${agent}/bin/.check_mk_agent-wrapped
        ${pkgs.gnugrep}/bin/grep -F 'echo "Version: 2.5.0p15"' ${agent}/bin/.check_mk_agent-wrapped
        test -x ${agent}/bin/mk-job
        test -x ${agent}/usr/lib/check_mk_agent/plugins/smart
        ${agent}/usr/lib/check_mk_agent/local/nixthings-smoke > local-output
        ${pkgs.gnugrep}/bin/grep -Fx '0 "Nixthings smoke" - Local check works' local-output
        touch "$out"
      '';
    });

    lib = {
      inherit ((import ./lib/net.nix {inherit (nixpkgs) lib;}).lib) net;
      math = import ./lib/math.nix;
      ipgen = import ./lib/ipgen.nix {inherit (self) lib;};
      sshKeys = import ./lib/sshKeys.nix;
    };

    tests = import ./tests.nix {
      inherit (self.lib) math ipgen;
      inherit (nixpkgs.lib) runTests;
    };

    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      check_mk_agent = (pkgs.extend self.overlays.default).check_mk_agent.override {
        enablePluginSmart = true;
      };
      update-authorized-keys = pkgs.writeScriptBin "update-authorized-keys" ''
        #!${pkgs.python3}/bin/python

        import sys
        from argparse import ArgumentParser
        from pathlib import Path

        parser = ArgumentParser()
        parser.add_argument('file')
        parser.add_argument('--dry-run', '-n', action='store_true')

        KEYS = ${builtins.toJSON self.lib.sshKeys.albert}

        def main():
          args = parser.parse_args()
          file = Path(args.file)

          try:
            contents = file.read_text().rstrip()
          except FileNotFoundError:
            log("Creating %s", file)
            contents = ""

          lines = [] if contents == "" else contents.split('\n')

          lines = [normalize_line(l) for l in lines]

          add_lines = ['%s update-authorized-keys' % k for k in KEYS]

          lines = [l for l in lines if not l.endswith(' update-authorized-keys') or l in add_lines]

          for line in add_lines:
            if line not in lines:
              lines.append(line)

          contents = '\n'.join(lines) + '\n'

          if args.dry_run:
            print(contents, end="")
          else:
            file.write_text(contents)

          return 0

        def log(fmt, *args):
          print(fmt % args, file=sys.stderr)

        def normalize_line(line):
          l = ' '.join(line.strip().split()[0:2])
          if l not in KEYS:
            return line
          return '%s update-authorized-keys' % l

        if __name__ == '__main__':
          sys.exit(main())
      '';
    });
  };
}
