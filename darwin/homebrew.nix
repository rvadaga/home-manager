{ lib, ... }: {
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = lib.mkDefault "zap";
    };

    casks = lib.mkDefault [
      "1password"
      "bettermouse"
      "bettertouchtool"
      "chatgpt"
      "claude"
      "docker-desktop"
      "ghostty"
      "google-chrome"
      "google-drive"
      "itsycal"
      "jordanbaird-ice"
      "meetingbar"
      "notion"
      "obsidian"
      "spotify"
      "visual-studio-code"
      "whatsapp"
    ];

    # masApps disabled — mas 2.x CLI is incompatible with nix-darwin's brew bundle integration
    # install manually: Monosnap (App Store ID 540348655)
  };
}
