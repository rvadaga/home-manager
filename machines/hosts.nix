{
  personal-laptop = {
    system = "aarch64-darwin";
    user = "rvadaga";
    home = "/Users/rvadaga";
    stateVersion = "24.11";
    homeManagerModule = ./personal-laptop.nix;
    darwinModule = ../darwin/personal-laptop.nix;
  };

  mac-workstation = {
    system = "aarch64-darwin";
    user = "rahul";
    home = "/Users/rahul";
    stateVersion = "24.11";
    gitSigningKey = "0CA84231BC45DEC79B5D3045281566EDEF2E7A00";
    homeManagerModule = ./mac-workstation.nix;
    darwinModule = ../darwin/mac-workstation.nix;
  };

  nixos-workstation = {
    system = "x86_64-linux";
    user = "rahulv";
    home = "/home/rahulv";
    stateVersion = "24.11";
    homeManagerModule = ./nixos-workstation.nix;
  };
}
