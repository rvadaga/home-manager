{ config, pkgs, lib, ... }: {
  imports = [
    ../programs/kitty.nix
  ];

  home = {
    packages = [
      pkgs.unstable.coreutils-full
      pkgs.unstable.coreutils-prefixed
      pkgs.pinentry_mac
    ];
  };
}
