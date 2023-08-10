{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    dnsutils
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

  programs.git = {
    enable = true;
    config.commit.verbose = true;
  };
}
