{
  lib,
  config,
  pkgs,
  ...
}: let
  kernelPath = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
  initrdPath = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
  commandLine = "init=${placeholder "out"}/init ${toString config.boot.kernelParams}";
  script = ''
    #!${pkgs.runtimeShell}
    set -xeuo pipefail
    ${pkgs.kexec-tools}/bin/kexec \
      --load ${lib.escapeShellArg kernelPath} \
      --initrd ${lib.escapeShellArg initrdPath} \
      --command-line ${lib.escapeShellArg commandLine}
    ${pkgs.kexec-tools}/bin/kexec -e
  '';
  cond = lib.mkIf (!config.boot.isContainer);
  hintScript = ''
    echo "To kexec into the new system configuration, run:" >&2
    echo "sudo $1/kexec" >&2
  '';
in {
  system.systemBuilderCommands = cond ''
    if [[ -f $out/kexec ]]; then
      echo "nixthings: kexec script exists; rename it?"
      exit 1
    fi
    echo ${lib.escapeShellArg script} > $out/kexec
    chmod +x $out/kexec
  '';

  boot.loader.grub.extraInstallCommands = cond hintScript;

  system.activationScripts = cond {
    kexec-hint = {
      text = hintScript;
      supportsDryActivation = true;
    };
  };
}
