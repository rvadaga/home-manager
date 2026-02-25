{ config, pkgs, lib, ... }: {
  # import the os-configs that apply to this machine.
  # base.nix is always required; add mac.nix, linux.nix, and/or nixos.nix as appropriate.
  imports = [
    ../os-configs/base.nix
    ../os-configs/mac.nix   # or linux.nix / nixos.nix
  ];

  home = {
    username = "your-username";
    homeDirectory = "/Users/your-username";  # or /home/your-username on linux

    # must match the home-manager release used in flake.nix
    stateVersion = "24.11";

    sessionVariables = {
      HM_CONFIG_NAME = "your-machine-name";  # used by hm alias and scripts

      # machine-specific overrides, e.g.:
      # WORK_DIR = "/Users/your-username/work";
    };

    # machine-specific packages beyond what base.nix provides
    packages = [
      # pkgs.somepackage
    ];
  };

  # override git email for this machine if different from base.nix default
  # programs.git.settings.user.email = lib.mkForce "you@work.com";
}
