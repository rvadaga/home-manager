{ config, pkgs, lib, ... }: {
  imports = [
    ../modules/kitty.nix
  ];

  home = {
    packages = [
      pkgs.unstable.coreutils-full
      pkgs.pinentry_mac
    ];
  };
}
