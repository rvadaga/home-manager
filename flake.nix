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

    # external tools
    cloudflare-speed-cli.url = "github:kavehtehrani/cloudflare-speed-cli";
    ghostty.url = "github:ghostty-org/ghostty";
    nix-index-database.url = "github:nix-community/nix-index-database";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "darwin-stable";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "darwin-stable";
    };
  };

  outputs = { darwin-stable, nixos-stable, darwin-unstable, nixos-unstable, staging, staging-next, home-manager, nix-darwin, cloudflare-speed-cli, ghostty, nix-index-database, ... }:
    let
      mkOverlays = system:
        let
          isLinux = builtins.match ".*-linux" system != null;
          unstableInput = if isLinux then nixos-unstable else darwin-unstable;
        in [
          (final: prev: {
            unstable = import unstableInput {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          })
          (final: prev: {
            staging = import staging {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          })
          (final: prev: {
            staging-next = import staging-next {
              inherit (prev.stdenv.hostPlatform) system;
              config.allowUnfree = true;
              config.allowUnfreePredicate = _: true;
            };
          })
          cloudflare-speed-cli.overlays.default
          (final: prev: {
            ghostty-tip = ghostty.packages.${system}.default;
          })
        ];

      mkPkgs = { system, pkgsInput ? null }:
        let
          isLinux = builtins.match ".*-linux" system != null;
          selectedInput = if pkgsInput != null then pkgsInput
                          else if isLinux then nixos-stable
                          else darwin-stable;
        in import selectedInput {
          inherit system;
          config.allowUnfree = true;
          config.allowUnfreePredicate = _: true;
          overlays = mkOverlays system;
        };

      hmModules = [
        nix-index-database.homeModules.nix-index
        { programs.nix-index.enable = true; programs.nix-index-database.comma.enable = true; }
      ];

      mkHomeManagerConfiguration = { homeManagerModule, system, pkgsInput ? null }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs { inherit system pkgsInput; };
          modules = [ homeManagerModule ] ++ hmModules;
        };
    in {
      homeConfigurations = {
        personal-laptop = mkHomeManagerConfiguration {
          system = "aarch64-darwin";
          homeManagerModule = ./machines/personal-laptop.nix;
        };
        mac-workstation = mkHomeManagerConfiguration {
          system = "aarch64-darwin";
          homeManagerModule = ./machines/mac-workstation.nix;
        };
        nixos-workstation = mkHomeManagerConfiguration {
          system = "x86_64-linux";
          homeManagerModule = ./machines/nixos-workstation.nix;
        };
      };

      darwinConfigurations.mac-workstation = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin/default.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.overlays = mkOverlays "aarch64-darwin";
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.allowUnfreePredicate = _: true;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.rahul = import ./machines/mac-workstation.nix;
            home-manager.sharedModules = hmModules;
          }
        ];
      };

      # exported overlays that other flakes can use
      overlays = {
        ghostty-tip = final: prev: {
          ghostty-tip = ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
        };
      };

      # exported modules that other flakes can import
      # example: inputs.personal-config.homeManagerModules.base
      homeManagerModules = {
        base = ./os-configs/base.nix;
        mac = ./os-configs/mac.nix;
        linux = ./os-configs/linux.nix;
        nixos = ./os-configs/nixos.nix;
        nix-index = {
          imports = [ nix-index-database.homeModules.nix-index ];
          programs.nix-index.enable = true;
          programs.nix-index-database.comma.enable = true;
        };
      };

      # exported darwin modules for downstream nix-darwin configs
      # example: inputs.personal-config.darwinModules.base
      darwinModules = {
        base = ./darwin/nix.nix;
        desktop = ./darwin/system-defaults.nix;
        homebrew = ./darwin/homebrew.nix;
      };
    };
}
