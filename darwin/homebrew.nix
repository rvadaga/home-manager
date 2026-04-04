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
    ];

    masApps = {
      Monosnap = 540348655;
    };
  };
}
