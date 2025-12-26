{
  lib,
  options,
  ...
}: {
  services.openssh =
    {
      enable = true;
    }
    // lib.optionalAttrs (builtins.hasAttr "settings" options.services.openssh) {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AcceptEnv = lib.concatStringsSep " " [
          "GIT_AUTHOR_NAME"
          "GIT_AUTHOR_EMAIL"
          "GIT_COMMITTER_NAME"
          "GIT_COMMITTER_EMAIL"
        ];
      };
    };

  programs.ssh.knownHostsFiles = [../etc/github-known-hosts];
}
