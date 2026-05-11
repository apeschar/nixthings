{pkgs, ...}: let
  disabledKernelModules = [
    "algif_aead"
    "esp4"
    "esp6"
    "rxrpc"
  ];
in {
  systemd.enableEmergencyMode = false;

  nix.settings.extra-experimental-features = ["nix-command" "flakes"];

  time.timeZone = "UTC";

  users.mutableUsers = false;

  boot.loader.grub.configurationLimit = 10;
  boot.extraModprobeConfig =
    builtins.concatMapStrings
    (module: "install ${module} ${pkgs.coreutils}/bin/false\n")
    disabledKernelModules;
}
