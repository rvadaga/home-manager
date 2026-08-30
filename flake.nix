{
  description = "home-manager configuration";

  inputs = {
    # stable channels (platform-specific)
    darwin-stable.url = "github:nixos/nixpkgs/nixpkgs-26.05-darwin";
    nixos-stable.url = "github:nixos/nixpkgs/nixos-26.05";

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
    googleworkspace-cli.url = "github:googleworkspace/cli";
    nix-index-database.url = "github:nix-community/nix-index-database";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "darwin-stable";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "darwin-stable";
    };
  };

  outputs = { darwin-stable, nixos-stable, darwin-unstable, nixos-unstable, staging, staging-next, home-manager, nix-darwin, cloudflare-speed-cli, ghostty, googleworkspace-cli, nix-index-database, ... }@inputs:
    let
      lib = darwin-stable.lib;
      hostSpecs = import ./machines/hosts.nix;

      unfreeConfig = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };

      mkOverlays = system:
        let
          isLinux = builtins.match ".*-linux" system != null;
          unstableInput = if isLinux then nixos-unstable else darwin-unstable;
        in [
          (final: prev: {
            unstable = import unstableInput {
              inherit (prev.stdenv.hostPlatform) system;
              config = unfreeConfig;
            };
          })
          (final: prev: {
            staging = import staging {
              inherit (prev.stdenv.hostPlatform) system;
              config = unfreeConfig;
            };
          })
          (final: prev: {
            staging-next = import staging-next {
              inherit (prev.stdenv.hostPlatform) system;
              config = unfreeConfig;
            };
          })
          cloudflare-speed-cli.overlays.default
          (final: prev: {
            ghostty-tip = ghostty.packages.${system}.default;
          })
          (final: prev: {
            gws = googleworkspace-cli.packages.${system}.gws;
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
          config = unfreeConfig;
          overlays = mkOverlays system;
        };

      hmModules = [
        nix-index-database.homeModules.nix-index
        { programs.nix-index.enable = true; programs.nix-index-database.comma.enable = true; }
      ];

      mkHomeManagerConfiguration = { configurationName, host }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs {
            inherit (host) system;
            pkgsInput = host.pkgsInput or null;
          };
          modules = [ host.homeManagerModule ] ++ hmModules;
          extraSpecialArgs = {
            inherit configurationName inputs;
            machine = host;
          };
        };

      mkDarwinConfiguration = { configurationName, host, extraModules ? [ ] }:
        nix-darwin.lib.darwinSystem {
          inherit (host) system;
          # `inputs` (and thus `inputs.self`) must be in scope for
          # darwin/provenance.nix to stamp the active system with the flake rev.
          specialArgs = {
            inherit configurationName inputs;
            machine = host;
          };
          modules = [
            host.darwinModule
            home-manager.darwinModules.home-manager
            {
              system.primaryUser = host.user;
              personal.apps.profile = configurationName;
              users.users.${host.user} = {
                name = host.user;
                home = host.home;
              };
              nixpkgs.overlays = mkOverlays host.system;
              nixpkgs.config = unfreeConfig;
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${host.user} = import host.homeManagerModule;
              home-manager.sharedModules = hmModules;
              home-manager.extraSpecialArgs = {
                inherit configurationName inputs;
                machine = host;
              };
            }
          ] ++ extraModules;
        };

      appRemovalConfiguration = mkDarwinConfiguration {
        configurationName = "mac-workstation";
        host = hostSpecs.mac-workstation;
        extraModules = [{
          personal.apps.registry = {
            "1password".enable = false;
            itsycal.enable = false;
            bettertouchtool.enable = false;
            google-chrome.enable = false;
          };
        }];
      };

      appRemovalCheck =
        let
          checkConfig = appRemovalConfiguration.config;
          manifest = checkConfig.personal.apps.manifest;
          removedApps = [ "1password" "itsycal" "bettertouchtool" "google-chrome" ];
          manifestReferences = map (entry: entry.app) (
            manifest.casks
            ++ manifest.dock
            ++ manifest.preferences
            ++ manifest.backups
            ++ manifest.licenses
            ++ manifest.shellAliases
            ++ manifest.setup
            ++ manifest.signIn
            ++ manifest.privacy
            ++ manifest.loginItems
            ++ manifest.restore
          );
          caskNames = map (cask: cask.name) checkConfig.homebrew.casks;
          dockPaths = map (entry:
            entry."tile-data"."file-data"."_CFURLString"
          ) checkConfig.system.defaults.dock.persistent-apps;
          preferenceDomains = builtins.attrNames checkConfig.system.defaults.CustomUserPreferences;
          shellAliasNames = builtins.attrNames checkConfig.home-manager.users.rahul.programs.zsh.shellAliases;
          noRemoved = values: lib.all (removed: !(lib.elem removed values)) removedApps;
          referencesAreClean =
            noRemoved manifest.apps
            && noRemoved manifestReferences
            && !(lib.elem "1password" caskNames)
            && !(lib.elem "itsycal" caskNames)
            && !(lib.elem "bettertouchtool" caskNames)
            && !(lib.elem "google-chrome" caskNames)
            && !(lib.elem "/Applications/1Password.app" dockPaths)
            && !(lib.elem "/Applications/Google Chrome.app" dockPaths)
            && !(lib.elem "com.mowglii.ItsycalApp" preferenceDomains)
            && !(lib.elem "chrome" shellAliasNames);
          checkPkgs = mkPkgs { system = "aarch64-darwin"; };
          backupCommand = checkConfig.launchd.user.agents.backup-app-configs.command;
          licensePackage = lib.findFirst
            (package: lib.getName package == "setup-app-licenses")
            (throw "generated app license package is missing")
            checkConfig.environment.systemPackages;
          licenseCommand = "${licensePackage}/bin/setup-app-licenses";
        in
        assert lib.assertMsg referencesAreClean
          "disabled apps still have generated app references";
        checkPkgs.runCommand "app-removal-check" {
          nativeBuildInputs = [ checkPkgs.gnugrep ];
        } ''
          if grep -qi bettertouchtool ${backupCommand}; then
            echo "disabled app still appears in the generated backup command"
            exit 1
          fi
          if grep -qi bettertouchtool ${licenseCommand}; then
            echo "disabled app still appears in the generated license command"
            exit 1
          fi
          touch "$out"
        '';
    in {
      homeConfigurations = builtins.mapAttrs (configurationName: host:
        mkHomeManagerConfiguration { inherit configurationName host; }
      ) hostSpecs;

      darwinConfigurations = builtins.mapAttrs (configurationName: host:
        mkDarwinConfiguration { inherit configurationName host; }
      ) (lib.filterAttrs (_: host: host ? darwinModule) hostSpecs);

      checks.aarch64-darwin.app-removal = appRemovalCheck;

      # exported overlays that other flakes can use
      overlays = {
        ghostty-tip = final: prev: {
          ghostty-tip = ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
        };
        gws = final: prev: {
          gws = googleworkspace-cli.packages.${prev.stdenv.hostPlatform.system}.gws;
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
        common = ./darwin/common.nix;
        # compatibility name retained for downstream configurations.
        base = ./darwin/nix.nix;
        apps = ./darwin/apps.nix;
        desktop = ./darwin/system-defaults.nix;
        # compatibility alias: app installation now belongs to the app registry.
        homebrew = ./darwin/apps.nix;
        # downstream consumers must also set `specialArgs = { inherit inputs; }`
        # on their darwinSystem so provenance.nix can read inputs.self.
        provenance = ./darwin/provenance.nix;
      };
    };
}
