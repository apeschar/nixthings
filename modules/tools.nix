{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    htop
    lsof
    ncdu
    ripgrep
    screen
    socat
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
