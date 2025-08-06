{
  lib,
  pkgs,
  options,
  ...
}: let
  githubKnownHosts = pkgs.fetchurl {
    url = "https://api.github.com/meta";
    name = "github-known-hosts";
    hash = "sha256-xzrF0EXNKjWdIgK3m1UfsipjhGPV3b5e1ZsbOZiGnIg=";
    downloadToTemp = true;
    postFetch = ''
      ${pkgs.jq}/bin/jq -r '.ssh_keys[] | "github.com " + .' $downloadedFile > $out
    '';
  };
in {
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

  programs.ssh.knownHostsFiles = [githubKnownHosts];
}
