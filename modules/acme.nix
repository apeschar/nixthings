{lib, ...}: {
  security.acme = {
    acceptTerms = lib.mkDefault true;
    defaults.email = lib.mkDefault "albert@peschar.net";
  };
}
