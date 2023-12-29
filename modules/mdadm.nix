{lib, ...}:
with lib; {
  config.environment.etc."mdadm.conf".text = ''
    MAILADDR albert@peschar.net
  '';
}
