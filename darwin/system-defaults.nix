{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
  trackpadDefaults = {
    Clicking = true;
    Dragging = false;
    TrackpadRightClick = true;
    TrackpadThreeFingerDrag = true;
    ActuationStrength = 0;
    FirstClickThreshold = 0;
    SecondClickThreshold = 0;
    TrackpadThreeFingerTapGesture = 2;
    ActuateDetents = true;
    DragLock = false;
    ForceSuppressed = false;
    TrackpadCornerSecondaryClick = 0;
    TrackpadFourFingerHorizSwipeGesture = 2;
    TrackpadFourFingerPinchGesture = 2;
    TrackpadFourFingerVertSwipeGesture = 2;
    TrackpadMomentumScroll = true;
    TrackpadPinch = true;
    TrackpadRotate = true;
    TrackpadThreeFingerHorizSwipeGesture = 0;
    TrackpadThreeFingerVertSwipeGesture = 0;
    TrackpadTwoFingerDoubleTapGesture = true;
    TrackpadTwoFingerFromRightEdgeSwipeGesture = 0;
  };
  trackpadByHostDefaults = {
    "com.apple.mouse.tapBehavior" = 1;
    "com.apple.trackpad.enableSecondaryClick" = 1;
    "com.apple.trackpad.fourFingerHorizSwipeGesture" = 2;
    "com.apple.trackpad.fourFingerPinchSwipeGesture" = 2;
    "com.apple.trackpad.fourFingerVertSwipeGesture" = 2;
    "com.apple.trackpad.momentumScroll" = 1;
    "com.apple.trackpad.pinchGesture" = 1;
    "com.apple.trackpad.rotateGesture" = 1;
    "com.apple.trackpad.scrollBehavior" = 2;
    "com.apple.trackpad.threeFingerDragGesture" = 1;
    "com.apple.trackpad.threeFingerHorizSwipeGesture" = 0;
    "com.apple.trackpad.threeFingerTapGesture" = 2;
    "com.apple.trackpad.threeFingerVertSwipeGesture" = 0;
    "com.apple.trackpad.trackpadCornerClickBehavior" = 0;
    "com.apple.trackpad.twoFingerDoubleTapGesture" = 1;
    "com.apple.trackpad.twoFingerFromRightEdgeSwipeGesture" = 0;
  };
in
{
  system.defaults = {
    dock = {
      autohide = lib.mkDefault true;
      expose-group-apps = lib.mkDefault true;
      launchanim = lib.mkDefault true;
      magnification = lib.mkDefault false;
      mineffect = lib.mkDefault "scale";
      minimize-to-application = lib.mkDefault true;
      mru-spaces = lib.mkDefault false;
      orientation = lib.mkDefault "bottom";

      # keep in sync with casks in homebrew.nix — only list apps that are
      # either brew-managed or built-in system apps
      persistent-apps = lib.mkDefault [
        "/System/Applications/Apps.app"
        "/Applications/Google Chrome.app"
        "/Applications/Spotify.app"
        "/System/Applications/Music.app"
        "/Applications/Claude.app"
        "/Applications/ChatGPT.app"
        "/System/Applications/Mail.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Reminders.app"
        "/Applications/Notion.app"
        "/Applications/Obsidian.app"
        "/Applications/1Password.app"
        "/Applications/Ghostty.app"
        "/Applications/Visual Studio Code.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/Messages.app"
        "/System/Applications/FindMy.app"
        "/System/Applications/iPhone Mirroring.app"
        "/System/Applications/Utilities/Screen Sharing.app"
        "/System/Applications/System Settings.app"
      ];

      showAppExposeGestureEnabled = lib.mkDefault true;
      showDesktopGestureEnabled = lib.mkDefault true;
      showLaunchpadGestureEnabled = lib.mkDefault true;
      showMissionControlGestureEnabled = lib.mkDefault true;
      show-process-indicators = lib.mkDefault true;
      show-recents = lib.mkDefault true;
      wvous-tl-corner = lib.mkDefault 2; # mission control
      wvous-tr-corner = lib.mkDefault 12; # notification center
      wvous-bl-corner = lib.mkDefault 3; # application windows
      wvous-br-corner = lib.mkDefault 1; # no action

      persistent-others = lib.mkDefault [
        "${user.home}/Downloads"
      ];
    };

    finder = {
      CreateDesktop = lib.mkDefault true;
      FXPreferredViewStyle = lib.mkDefault "clmv";
      ShowPathbar = lib.mkDefault true;
      ShowStatusBar = lib.mkDefault true;
      FXDefaultSearchScope = lib.mkDefault "SCcf";
      NewWindowTarget = lib.mkDefault "Home";
      ShowExternalHardDrivesOnDesktop = lib.mkDefault true;
      ShowHardDrivesOnDesktop = lib.mkDefault false;
      ShowRemovableMediaOnDesktop = lib.mkDefault true;
    };

    NSGlobalDomain = {
      AppleEnableSwipeNavigateWithScrolls = lib.mkDefault false;
      AppleICUForce24HourTime = lib.mkDefault false;
      AppleInterfaceStyleSwitchesAutomatically = lib.mkDefault true;
      InitialKeyRepeat = lib.mkDefault 15;
      KeyRepeat = lib.mkDefault 2;
      NSAutomaticCapitalizationEnabled = lib.mkDefault false;
      NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
      NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;
      AppleScrollerPagingBehavior = lib.mkDefault false;
      AppleShowScrollBars = lib.mkDefault "Automatic";
      AppleSpacesSwitchOnActivate = lib.mkDefault true;
      AppleWindowTabbingMode = lib.mkDefault "fullscreen";
      NSTableViewDefaultSizeMode = lib.mkDefault 2;
      # full keyboard access — tab cycles focus through all controls in dialogs
      AppleKeyboardUIMode = lib.mkDefault 3;
      # tap-to-click; the System Settings toggle reads this, not trackpad.Clicking
      "com.apple.mouse.tapBehavior" = lib.mkDefault 1;
      "com.apple.sound.beep.feedback" = lib.mkDefault 0;
      "com.apple.sound.beep.volume" = lib.mkDefault 0.435501;
      "com.apple.springing.delay" = lib.mkDefault 0.5075295865535736;
      "com.apple.springing.enabled" = lib.mkDefault true;
      "com.apple.swipescrolldirection" = lib.mkDefault true;
      "com.apple.trackpad.scaling" = lib.mkDefault 1.0;
    };

    trackpad = lib.mapAttrs (_: value: lib.mkDefault value) trackpadDefaults;

    ".GlobalPreferences"."com.apple.mouse.scaling" = lib.mkDefault 2.0;

    WindowManager = {
      GloballyEnabled = lib.mkDefault false;
      EnableStandardClickToShowDesktop = lib.mkDefault false;
      AutoHide = lib.mkDefault true;
      AppWindowGroupingBehavior = lib.mkDefault true;
      StandardHideDesktopIcons = lib.mkDefault false;
      HideDesktop = lib.mkDefault true;
      EnableTilingByEdgeDrag = lib.mkDefault true;
      EnableTopTilingByEdgeDrag = lib.mkDefault true;
      EnableTilingOptionAccelerator = lib.mkDefault true;
      EnableTiledWindowMargins = lib.mkDefault false;
      StandardHideWidgets = lib.mkDefault false;
      StageManagerHideWidgets = lib.mkDefault false;
    };

    controlcenter = {
      BatteryShowPercentage = lib.mkDefault true;
      Sound = lib.mkDefault true;
      Bluetooth = lib.mkDefault false;
      AirDrop = lib.mkDefault false;
      Display = lib.mkDefault false;
      FocusModes = lib.mkDefault true;
    };

    menuExtraClock = {
      FlashDateSeparators = lib.mkDefault false;
      IsAnalog = lib.mkDefault false;
      Show24Hour = lib.mkDefault false;
      ShowAMPM = lib.mkDefault true;
      ShowDayOfMonth = lib.mkDefault false;
      ShowDayOfWeek = lib.mkDefault false;
      ShowDate = lib.mkDefault 2;
      ShowSeconds = lib.mkDefault true;
    };

    spaces.spans-displays = lib.mkDefault false;

    hitoolbox.AppleFnUsageType = lib.mkDefault "Show Emoji & Symbols";

    LaunchServices.LSQuarantine = lib.mkDefault true;

    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = lib.mkDefault true;

    universalaccess = {
      mouseDriverCursorSize = lib.mkDefault 1.0;
      reduceMotion = lib.mkDefault false;
      reduceTransparency = lib.mkDefault false;
      closeViewScrollWheelToggle = lib.mkDefault false;
    };

    screensaver = {
      askForPassword = lib.mkDefault true;
      askForPasswordDelay = lib.mkDefault 5;
    };

    loginwindow = {
      SHOWFULLNAME = lib.mkDefault true;
      GuestEnabled = lib.mkDefault false;
      ShutDownDisabled = lib.mkDefault false;
      SleepDisabled = lib.mkDefault false;
      RestartDisabled = lib.mkDefault false;
    };

    CustomSystemPreferences."/Library/Preferences/com.apple.SoftwareUpdate" = {
      AutomaticDownload = lib.mkDefault true;
      ConfigDataInstall = lib.mkDefault true;
      CriticalUpdateInstall = lib.mkDefault true;
    };

    CustomUserPreferences = lib.mkDefault {
      "com.mowglii.ItsycalApp" = {
        HideIcon = 0;
        HighlightedDOWs = 65;
        MenuBarIconType = 0;
        ShowDayOfWeekInIcon = 1;
        ShowDaysWithNoEventsInAgenda = 1;
        ShowEventDays = 3;
        ShowEventPopoverOnHover = 1;
        ShowLocation = 1;
        ShowMonthInIcon = 1;
        ShowWeeks = 1;
        SizePreference = 0;
      };

      "com.jordanbaird.Ice" = {
        AutoRehide = 1;
        RehideInterval = 15;
        RehideStrategy = 2;
        HideApplicationMenus = 1;
        EnableAlwaysHiddenSection = 0;
        CanToggleAlwaysHiddenSection = 1;
        EnableSecondaryContextMenu = 1;
        ShowAllSectionsOnUserDrag = 1;
        SectionDividerStyle = 0;
        IceBarLocation = 2;
        ItemSpacingOffset = 0;
        CustomIceIconIsTemplate = 0;
      };

      "leits.MeetingBar" = {
        allDayEvents = "\"show\"";
        nonAllDayEvents = "\"show\"";
        declinedEventsAppereance = "\"strikethrough\"";
        pastEventsAppereance = "\"show_inactive\"";
        ongoingEventVisibility = "\"showTenMinBeforeNext\"";
        showPendingEvents = "\"show\"";
        showTentativeEvents = "\"show\"";
        eventTimeFormat = "\"show\"";
        eventTitleFormat = "\"none\"";
        eventTitleIconFormat = "\"AppIcon\"";
        hideMeetingTitle = 0;
        menuEventTitleLength = 20;
        statusbarEventTitleLength = 10;
        showEventDetails = 1;
        showEventMaxTimeUntilEventEnabled = 1;
        showEventsForPeriod = "\"today\"";
        showTimelineInMenu = 0;
        timeFormat = "\"12-hour\"";
        eventStoreProvider = "\"MacOS Calendar App\"";
      };
    };
  };

  # system settings reads gesture state from by-host preferences while the
  # driver reads the trackpad domains written by nix-darwin. keep both layers
  # aligned so the controls and the actual gestures agree.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        key: value:
        "/usr/bin/sudo -u ${lib.escapeShellArg user.name} /usr/bin/defaults -currentHost write -g ${lib.escapeShellArg key} -int ${toString value}"
      ) trackpadByHostDefaults
    )}
  '';
}
