{
  inputs = {
    checkmk.url = "github:BenediktSeidl/nixos-check_mk_agent-overlay";
  };

  outputs = {
    self,
    checkmk,
  }: {
    nixosModule = {
      imports = [
        {nixpkgs.overlays = [checkmk.overlays.default];}
        ./modules/checkmk.nix
        ./modules/restic.nix
      ];
    };
  };
}
