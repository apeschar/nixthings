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
  }: {
    nixosModule = {
      imports = [
        {nixpkgs.overlays = [checkmk.overlays.default];}
        ./modules/checkmk.nix
        ./modules/restic.nix
        ./modules/tools.nix
      ];
    };

    lib = {
      inherit ((import ./lib/net.nix {inherit (nixpkgs) lib;}).lib) net;
      math = import ./lib/math.nix;
      ipgen = import ./lib/ipgen.nix {
        inherit (self) lib;
        inherit nixpkgs;
      };
    };

    tests = import ./tests.nix {
      inherit (self.lib) math ipgen;
      inherit (nixpkgs.lib) runTests;
    };
  };
}
