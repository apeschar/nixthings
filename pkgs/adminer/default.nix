{ stdenv, fetchurl }:

let

  version = "4.7.0";

in stdenv.mkDerivation {

  name = "adminer-${version}";

  src = fetchurl {
    name = "adminer.php";
    url = "https://github.com/vrana/adminer/releases/download/v${version}/adminer-${version}-mysql-en.php";
    sha256 = "06jcx9q0zdi6i84d0kh4w4gdy4ba11by97hl1xiqxli8yczgjyd4";
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
