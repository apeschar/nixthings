image :
	nix-build '<nixpkgs/nixos>' -A config.system.build.myImage --arg configuration '{ imports = [ ./image.nix ]; }' -j9
