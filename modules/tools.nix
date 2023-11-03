{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    efibootmgr
    htop
    lsof
    ncdu
    psmisc
    ripgrep
    screen
    socat
    tcpdump
    tig
    tmux
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    configure = {
      customRC = ''
        colorscheme desert
        set showcmd
        set mouse=
      '';
    };
  };

  programs.git = {
    enable = true;
    config.commit.verbose = true;
  };
}
