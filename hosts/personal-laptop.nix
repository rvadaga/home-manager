{ config, pkgs, lib, ... }: {
  imports = [
    ../profiles/base.nix
    ../profiles/mac.nix
  ];

  home = {
    username = "rvadaga";
    homeDirectory = "/Users/rvadaga";
    stateVersion = "24.11";
  };
}
