_: {
  systemd.enableEmergencyMode = false;

  nix.settings.extra-experimental-features = ["nix-command" "flakes"];

  time.timeZone = "UTC";

  users.mutableUsers = false;

  boot.loader.grub.configurationLimit = 10;
  boot.extraModprobeConfig = ''
    install algif_aead /bin/false
  '';
}
