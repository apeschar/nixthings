{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    git
    htop
    lsof
    socat
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    configure = {
      customRC = ''
        colorscheme desert
        set showcmd
      '';
    };
  };
}
