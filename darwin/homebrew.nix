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

    masApps = {
      Monosnap = 540348655;
    };
  };
}
