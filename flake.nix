{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    checkmk = {
      url = "github:BenediktSeidl/nixos-check_mk_agent-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    checkmk,
  }: let
    inherit (nixpkgs) lib;
    eachSystem = lib.genAttrs (builtins.attrNames nixpkgs.legacyPackages);
  in {
    nixosModule = {
      imports = [
        {nixpkgs.overlays = [checkmk.overlays.default];}
        ./modules/defaults.nix
        ./modules/checkmk.nix
        ./modules/mosh.nix
        ./modules/restic.nix
        ./modules/ssh.nix
        ./modules/tools.nix
        {users.users.root.openssh.authorizedKeys.keys = self.lib.sshKeys.albert;}
      ];
    };

    lib = {
      inherit ((import ./lib/net.nix {inherit (nixpkgs) lib;}).lib) net;
      math = import ./lib/math.nix;
      ipgen = import ./lib/ipgen.nix {
        inherit (self) lib;
        inherit nixpkgs;
      };
      sshKeys = import ./lib/sshKeys.nix;
    };

    tests = import ./tests.nix {
      inherit (self.lib) math ipgen;
      inherit (nixpkgs.lib) runTests;
    };

    packages = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
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

        if __name__ == '__main__':
          sys.exit(main())
      '';
    });
  };
}
