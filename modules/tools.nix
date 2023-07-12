{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    htop
    lsof
  ];
}
