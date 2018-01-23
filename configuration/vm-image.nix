{ config, pkgs, ... }:

{

  imports = [
    <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
  };

  boot.kernelParams = [ "console=ttyS0" ];

  boot.growPartition = true;

  boot.loader.grub.device = "/dev/vda";
  boot.loader.timeout = 0;

  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCihJW6LDbo/He4xUPzz7zZs9JcK1zvooBj3lkB5u4CHzbpIntTa3JKKa12XTMII006CkuxdFgizx421q3Aiop+8Zr77j7KS0NFPPJiIb/H+aSpSBz/sRF+mImhXNPJ2SH/NEpY6HB+y6nRzGOD29Pjflsfxp67dput+1z3X9Hc48nGUda1/iIRNjKwqsHyfookk8iqquy491s8ucCIXKu2e1NFUNE9nmi1DpXf3jCLzFFmTkutaD6TwfuIrl1Lj0fQQANqh90M8zSEFpnXFE7+tYCqH00pDaOeuVucWlmECyhsRpMPIvweC8BnjoHGRLGWBk0MvLqx4TarJXsvsd8UKNs0xWKk888weXwydql0S98euhJRdKZMAjvsJMrK7RzD8idVLIzTj18bGhkbfGbVNsLDRzik0x1fkZ01F5btW4V3iRBJpje+v6REGseDtf01aG+n0KzvcBJDIoUBY/LMtGZr0tzq2JObcThN9xDQrkG1aUmrqNwpYG+amdKP1qEjiQOWfpjqqlVIvSbCe6doWrkvEhdXEATkpOwbIc8TJ4kb3LnmDOFXsfwHJITv6q+2ziT85XbSDlUmnkaH2caJ9imLC1Inudt3t4MG/o6ttZBKReh2ileDGAzJifWAWq4m6I6B+rsMWGGiTMP2fm+wgxnOw7zBWn7ndQoHRCs2dw== albert@peschar.net"
  ];

}
