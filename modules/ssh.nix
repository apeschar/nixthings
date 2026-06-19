{
  lib,
  options,
  ...
}: let
  acceptEnv = [
    "GIT_AUTHOR_NAME"
    "GIT_AUTHOR_EMAIL"
    "GIT_COMMITTER_NAME"
    "GIT_COMMITTER_EMAIL"
  ];

  settingsValueType = options.services.openssh.settings.type.nestedTypes.freeformType.nestedTypes.elemType or null;
  settingsTypeDescription = options.services.openssh.settings.type.description or "";
  # NixOS 26.05 is expected to accept lists for settings such as AcceptEnv.
  settingsAcceptsLists =
    if settingsValueType != null
    then settingsValueType.check acceptEnv
    else lib.hasInfix "list" settingsTypeDescription;
  acceptEnvValue =
    if settingsAcceptsLists
    then acceptEnv
    else lib.concatStringsSep " " acceptEnv;
in {
  services.openssh =
    {
      enable = true;
    }
    // lib.optionalAttrs (builtins.hasAttr "settings" options.services.openssh) {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AcceptEnv = acceptEnvValue;
      };
    };

  programs.ssh.knownHostsFiles = [../etc/github-known-hosts];
}
