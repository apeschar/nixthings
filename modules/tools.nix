{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    git
    htop
    lsof
    socat
  ];
}
