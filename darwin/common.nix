{ pkgs, ... }: {
  imports = [
    ./nix.nix
    ./homebrew.nix
    ./system-defaults.nix
    ./provenance.nix
  ];

  # fonts must be installed at the system level on macos — home-manager's
  # fontconfig path is linux-only. coretext only scans /Library/Fonts and
  # ~/Library/Fonts, not ~/.nix-profile/share/fonts. nix-darwin's fonts.packages
  # symlinks these into /Library/Fonts/Nix Fonts/ during activation.
  fonts.packages = with pkgs; [
    fira                  # fira sans + fira mono (mozilla)
    nerd-fonts.fira-code
  ];

  system.stateVersion = 6;

  security.pam.services.sudo_local.touchIdAuth = true;

  launchd.daemons.stay-awake.serviceConfig = {
    ProgramArguments = [
      "/bin/zsh"
      (toString ../scripts/stay-awake.zsh)
    ];
    RunAtLoad = true;
    ProcessType = "Background";
  };
}
