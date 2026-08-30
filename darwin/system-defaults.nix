{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  system.defaults = {
    dock = {
      autohide = lib.mkDefault true;
      mineffect = lib.mkDefault "scale";
      mru-spaces = lib.mkDefault false;

      showAppExposeGestureEnabled = lib.mkDefault true;
      wvous-tl-corner = lib.mkDefault 2;  # mission control
      wvous-tr-corner = lib.mkDefault 12; # notification center

      persistent-others = lib.mkDefault [
        "${user.home}/Downloads"
      ];
    };

    finder = {
      FXPreferredViewStyle = lib.mkDefault "clmv";
      ShowPathbar = lib.mkDefault true;
      ShowStatusBar = lib.mkDefault true;
      FXDefaultSearchScope = lib.mkDefault "SCcf";
    };

    NSGlobalDomain = {
      InitialKeyRepeat = lib.mkDefault 15;
      KeyRepeat = lib.mkDefault 2;
      NSAutomaticCapitalizationEnabled = lib.mkDefault false;
      NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
      NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;
      # full keyboard access — tab cycles focus through all controls in dialogs
      AppleKeyboardUIMode = lib.mkDefault 3;
      # tap-to-click; the System Settings toggle reads this, not trackpad.Clicking
      "com.apple.mouse.tapBehavior" = lib.mkDefault 1;
    };

    trackpad = {
      Clicking = lib.mkDefault true;
      TrackpadThreeFingerDrag = lib.mkDefault true;
      # 3-finger tap → look up & data detectors (0 = off, 2 = on)
      TrackpadThreeFingerTapGesture = lib.mkDefault 2;
    };

    screensaver.askForPasswordDelay = lib.mkDefault 5;

    loginwindow.SHOWFULLNAME = lib.mkDefault true;
  };

  # the System Settings "Look up & data detectors" dropdown reads the ByHost
  # key, not the per-app trackpad domain that nix-darwin's structured options
  # write to. activation runs as root, so drop to the user for the per-user
  # ByHost write.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/sudo -u ${user.name} /usr/bin/defaults -currentHost write -g com.apple.trackpad.threeFingerTapGesture -int 2
  '';
}
