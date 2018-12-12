{ stdenv, fetchurl }:

let

  version = "4.7.0";

in stdenv.mkDerivation {

  name = "adminer-${version}";

  src = fetchurl {
    name = "adminer.php";
    url = "https://github.com/vrana/adminer/releases/download/v${version}/adminer-${version}.php";
    sha256 = "1qq2g7rbfh2vrqfm3g0bz0qs057b049n0mhabnsbd1sgnpvnc5z7";
  };

  builder = builtins.toFile "builder.sh" ''
    source $stdenv/setup
    mkdir $out
    cat ${builtins.toFile "adminer.php.head" ''
      <?php
      function adminer_object() {
        return new class extends Adminer {
          public function login($login, $password) {
            return true;
          }
        };
      }
      ?>
    ''} $src > $out/adminer.php
  '';

}
