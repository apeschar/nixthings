{
  inputs = {};

  outputs = {self}: {
    nixosModule = import ./default.nix;
  };
}
