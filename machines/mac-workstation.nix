{ config, pkgs, lib, ... }: {
  imports = [
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  home = {
    username = "rahul";
    homeDirectory = "/Users/rahul";
    stateVersion = "24.11";

    sessionVariables = {
      HM_CONFIG_NAME = "mac-workstation";
    };
  };
}
