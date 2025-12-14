{ config, pkgs, lib, ... }: {
  imports = [
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  home = {
    username = "rvadaga";
    homeDirectory = "/Users/rvadaga";
    stateVersion = "24.11";
  };
}
