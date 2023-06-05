{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    checkmk = {
      url = "github:BenediktSeidl/nixos-check_mk_agent-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    checkmk,
    ...
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
    };
  };
}
