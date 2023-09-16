{
  lib,
  options,
  ...
}: {
  services.openssh = lib.optionalAttrs (builtins.hasAttr "settings" options.services.openssh) {
    settings = {
      AcceptEnv = lib.concatStringsSep " " [
        "GIT_AUTHOR_NAME"
        "GIT_AUTHOR_EMAIL"
        "GIT_COMMITTER_NAME"
        "GIT_COMMITTER_EMAIL"
      ];
    };
  };
}
