{
  lib,
  nixpkgs,
}: let
  sha256 = builtins.hashString "sha256";

  hextet = hex: i: builtins.substring (4 * i) 4 hex;

  addressOfHex = hex: nixpkgs.lib.concatMapStringsSep ":" (hextet hex) (nixpkgs.lib.range 0 7);

  addressOfValue = value: addressOfHex (sha256 value);

  hashUntil = p: f: v: let
    go = suffix: let
      h = sha256 (v + suffix);
      v' = f h;
    in
      if p v'
      then v'
      else go h;
  in
    go "";

  move = dest: addr: lib.net.ip.add (lib.net.cidr.host 0 dest) (lib.net.ip.subtract (lib.net.cidr.host 0 (lib.net.cidr.make (lib.net.cidr.length dest) addr)) addr);

  ipgen = {
    ip6 = subnet: value: move subnet (addressOfValue value);

    ip4ll =
      hashUntil
      (addr: !(builtins.any (lib.net.cidr.contains addr) ["169.254.0.0/24" "169.254.255.0/24"]))
      (hash: lib.net.ip.add "::${builtins.substring 4 4 hash}" "169.254.0.0");

    privateIp4 = i: value:
      assert i >= 0;
      assert i <= 1; let
        hash = sha256 value;
        addr = lib.net.cidr.host 0 (
          lib.net.cidr.make 31 (
            lib.net.ip.add
            "::${builtins.substring 0 4 hash}:${builtins.substring 4 4 hash}"
            "0.0.0.0"
          )
        );
      in
        lib.net.ip.add i (move "10.0.0.0/8" addr);
  };
in
  ipgen
