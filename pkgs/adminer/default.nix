{ stdenv, fetchurl }:

let

  version = "4.6.2";

in stdenv.mkDerivation {

  name = "adminer-${version}";

  src = fetchurl {
    name = "adminer.php";
    url = "https://github.com/vrana/adminer/releases/download/v${version}/adminer-${version}.php";
    sha256 = "1fbmamgl7ggah6jy6i442bqw4zj9l0djq9zwg21jh50jxn3mwgib";
  };

  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    mkdir $out
    cp $src $out/adminer.php
  '';

}
