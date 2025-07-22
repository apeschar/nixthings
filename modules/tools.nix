{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
    efibootmgr
    htop
    iftop
    libarchive
    lm_sensors
    lsof
    ncdu
    nvme-cli
    psmisc
    pv
    ripgrep
    screen
    smartmontools
    socat
    tcpdump
    tig
    tmux
    unixtools.xxd
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

  environment.etc."htoprc".source = ../htoprc;
}
