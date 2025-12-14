{ config, pkgs, lib, ... }: {
  imports = [
    ../programs/kitty.nix
  ];

  home = {
    packages = [
      pkgs.unstable.coreutils-full
      pkgs.pinentry_mac
    ];
  };
}
