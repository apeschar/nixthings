{
  lib,
  nixpkgs,
}: let
  hextet = hex: i: builtins.substring (4 * i) 4 hex;
  addressOfHex = hex: nixpkgs.lib.concatMapStringsSep ":" (hextet hex) (nixpkgs.lib.range 0 7);
  addressOfValue = value: addressOfHex (builtins.hashString "sha256" value);
  ipgen = {
    ip6 = subnet: value: let
      prefixLength = lib.net.cidr.length subnet;
      addr = addressOfValue value;
      host = lib.net.ip.subtract (lib.net.cidr.host 0 (lib.net.cidr.make prefixLength addr)) addr;
    in
      lib.net.cidr.host host subnet;

    ip6ll = ipgen.ip6 "fe80::/16";
  };
in
  ipgen
