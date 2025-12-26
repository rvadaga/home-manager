{
  description = "home-manager configuration";

  inputs = {
    # stable channels (platform-specific)
    darwin-stable.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";
    nixos-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # unstable channels (platform-specific)
    # darwin-unstable (nixpkgs-unstable) has autopatchelf issues on linux
    darwin-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # staging channels (unified - no platform-specific branches exist)
    staging.url = "github:nixos/nixpkgs/staging";
    staging-next.url = "github:nixos/nixpkgs/staging-next";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "darwin-stable";
    };
  };

  outputs = { darwin-stable, nixos-stable, darwin-unstable, nixos-unstable, staging, staging-next, home-manager, ... }:
    let
      mkHomeManagerConfiguration = { homeManagerModule, system, pkgsInput ? null }:
        let
          isLinux = builtins.match ".*-linux" system != null;

          # select appropriate stable channel based on platform (can be overridden via pkgsInput)
          defaultPkgsInput = if isLinux then nixos-stable else darwin-stable;
          selectedPkgsInput = if pkgsInput != null then pkgsInput else defaultPkgsInput;

          # select appropriate unstable channel based on platform
          unstableInput = if isLinux then nixos-unstable else darwin-unstable;

          # staging channels are unified (no platform-specific branches)
          stagingInput = staging;
          stagingNextInput = staging-next;

          unstable-overlay = final: prev: {
            unstable = import unstableInput {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          };

          staging-overlay = final: prev: {
            staging = import stagingInput {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          };

          staging-next-overlay = final: prev: {
            staging-next = import stagingNextInput {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          };
        in
          home-manager.lib.homeManagerConfiguration {
            pkgs = import selectedPkgsInput {
              inherit system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
              overlays = [ unstable-overlay staging-overlay staging-next-overlay ];
            };
            modules = [ homeManagerModule ];
          };
    in {
      homeConfigurations = {
        personal-laptop = mkHomeManagerConfiguration {
          system = "aarch64-darwin";
          homeManagerModule = ./machines/personal-laptop.nix;
        };
        nixos-workstation = mkHomeManagerConfiguration {
          system = "x86_64-linux";
          homeManagerModule = ./machines/nixos-workstation.nix;
        };
      };

      # exported modules that other flakes can import
      # example: inputs.personal-config.homeManagerModules.base
      homeManagerModules = {
        base = ./os-configs/base.nix;
        mac = ./os-configs/mac.nix;
        linux = ./os-configs/linux.nix;
        nixos = ./os-configs/nixos.nix;
      };
    };
}
