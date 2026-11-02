{
  lib,
  options,
  ...
}: {
  services.openssh =
    {
      enable = true;
      # Older NixOS releases only accept scalar values in settings.
      extraConfig = ''
        AcceptEnv GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
      '';
    }
    // lib.optionalAttrs (builtins.hasAttr "settings" options.services.openssh) {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

  programs.ssh.knownHostsFiles = [../etc/github-known-hosts];
}
