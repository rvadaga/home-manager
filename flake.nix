{
  description = "home-manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.05-darwin";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixpkgs-staging-next.url = "github:nixos/nixpkgs/staging-next";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, nixpkgs-staging-next, home-manager, ... }:
    let
      mkHomeManagerConfiguration = { homeManagerModule, system }:
        let
          unstable-overlay = final: prev: {
            unstable = import nixpkgs-unstable {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          };
          staging-next-overlay = final: prev: {
            staging-next = import nixpkgs-staging-next {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          };
        in
          home-manager.lib.homeManagerConfiguration {
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
              overlays = [ unstable-overlay staging-next-overlay ];
            };
            modules = [ homeManagerModule ];
          };
    in {
      homeConfigurations = {
        personal-laptop = mkHomeManagerConfiguration {
          system = "aarch64-darwin";
          homeManagerModule = ./machines/personal-laptop.nix;
        };
      };

      # exported modules that other flakes can import
      # example: inputs.personal-config.homeManagerModules.base
      homeManagerModules = {
        base = ./os-configs/base.nix;
        mac = ./os-configs/mac.nix;
        linux = ./os-configs/linux.nix;
      };
    };
}
