{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    git
    htop
    lsof
    ripgrep
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
