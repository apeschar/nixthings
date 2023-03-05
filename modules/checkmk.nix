{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.kibo.checkmk;
  check_mk_agent = pkgs.check_mk_agent.override (_: {
    enablePluginSmart = true;
  });
in {
  options.kibo.checkmk = {
    enable = mkEnableOption "Check_MK agent";
  };

  config = mkIf cfg.enable {
    users.users.root.openssh.authorizedKeys.keys = [
      ''restrict,command="${check_mk_agent}/bin/check_mk_agent || true" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEJN9YVPInBiZh9TBnGPR053R/RWNI+gBGCikwBtB/pS''
    ];
  };
}
