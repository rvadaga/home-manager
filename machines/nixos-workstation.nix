{ config, pkgs, lib, ... }: {
  imports = [
    ../os-configs/base.nix
    ../os-configs/linux.nix
    ../os-configs/nixos.nix
  ];

  home = {
    username = "rahulv";
    homeDirectory = "/home/rahulv";
    stateVersion = "24.11";
  };
}
