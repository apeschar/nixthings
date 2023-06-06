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

    tests = nixpkgs.lib.runTests {
      testPow = {
        expr = self.lib.math.pow 2 8;
        expected = 256;
      };
      testIpgen64 = let
        subnet = "2a01:4f9:3051:429c::/64";
      in {
        expr = self.lib.ipgen.ip6 subnet "hello";
        expected = "2a01:4f9:3051:429c:26e8:3b2a:c5b9:e29e";
      };
      testIpgen32 = let
        subnet = "2a01:4f9:3051:429c::/32";
      in {
        expr = self.lib.ipgen.ip6 subnet "hello";
        expected = "2a01:4f9:5fb0:a30e:26e8:3b2a:c5b9:e29e";
      };
    };
  };
}
