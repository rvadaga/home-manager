{ ... }: {
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
    };

    casks = [
      "1password"
      "bettermouse"
      "bettertouchtool"
      "ghostty"
      "google-chrome"
      "spotify"
      "visual-studio-code"
    ];

    # masApps disabled — mas 2.x CLI is incompatible with nix-darwin's brew bundle integration
    # install manually: Monosnap (App Store ID 540348655)
  };
}
