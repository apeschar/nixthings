_: {
  systemd.enableEmergencyMode = false;

  nix.settings.extra-experimental-features = ["nix-command" "flakes"];

  time.timeZone = "UTC";

  users.mutableUsers = false;
}
