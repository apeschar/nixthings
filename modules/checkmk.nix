{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.kibo.checkmk;
in {
  options.kibo.checkmk = {
    enable = mkEnableOption "Check_MK agent";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      check_mk_agent
      smartmontools
    ];

    users.users.root.openssh.authorizedKeys.keys = [
      ''restrict,command="check_mk_agent || true" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEJN9YVPInBiZh9TBnGPR053R/RWNI+gBGCikwBtB/pS''
    ];
  };
}
