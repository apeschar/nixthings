{lib, ...}:
with lib; {
  networking.firewall.logRefusedConnections = mkDefault false;
}
