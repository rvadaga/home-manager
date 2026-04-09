{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  system.defaults = {
    dock = {
      autohide = lib.mkDefault true;
      mineffect = lib.mkDefault "scale";
      minimize-to-application = lib.mkDefault false;
      launchanim = lib.mkDefault true;
      show-process-indicators = lib.mkDefault true;
      show-recents = lib.mkDefault true;
      mru-spaces = lib.mkDefault false;
      expose-group-apps = lib.mkDefault false;

      # keep in sync with casks in homebrew.nix — only list apps that are
      # either brew-managed or built-in system apps
      persistent-apps = lib.mkDefault [
        "/System/Applications/Apps.app"
        "/System/Applications/Mail.app"
        "/Applications/Google Chrome.app"
        "/System/Applications/Calendar.app"
        "/System/Applications/Reminders.app"
        "/Applications/Claude.app"
        "/Applications/ChatGPT.app"
        "/Applications/Notion.app"
        "/Applications/Obsidian.app"
        "/Applications/1Password.app"
        "/Applications/Spotify.app"
        "/System/Applications/Music.app"
        "/Applications/Ghostty.app"
        "/Applications/Visual Studio Code.app"
        "/System/Applications/Messages.app"
        "/System/Applications/FindMy.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/iPhone Mirroring.app"
        "/System/Applications/System Settings.app"
      ];

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
      # keyboard
      AppleShowAllExtensions = lib.mkDefault true;
      InitialKeyRepeat = lib.mkDefault 15;
      KeyRepeat = lib.mkDefault 2;

      # text input
      NSAutomaticCapitalizationEnabled = lib.mkDefault false;
      NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
      NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;

      # scrolling
      "com.apple.swipescrolldirection" = lib.mkDefault true;

      # windows
      AppleWindowTabbingMode = lib.mkDefault "fullscreen";
      AppleSpacesSwitchOnActivate = lib.mkDefault true;
    };

    trackpad = {
      Clicking = lib.mkDefault true;
      TrackpadRightClick = lib.mkDefault true;
      TrackpadThreeFingerDrag = lib.mkDefault true;
    };

    WindowManager = {
      GloballyEnabled = lib.mkDefault false;
      EnableStandardClickToShowDesktop = lib.mkDefault true;
      EnableTilingByEdgeDrag = lib.mkDefault true;
      EnableTiledWindowMargins = lib.mkDefault true;
    };

    spaces.spans-displays = lib.mkDefault false; # displays have separate spaces

    screensaver = {
      askForPassword = lib.mkDefault true;
      askForPasswordDelay = lib.mkDefault 5;
    };

    loginwindow = {
      SHOWFULLNAME = lib.mkDefault true; # login window shows name and password
    };

    CustomUserPreferences = lib.mkDefault {
      NSGlobalDomain = {
        AppleActionOnDoubleClick = "Maximize"; # window title bar double-click: zoom
        NSCloseAlwaysConfirmsChanges = false;   # ask to keep changes: off
        NSQuitAlwaysKeepsWindows = true;         # close windows when quitting: off
        "com.apple.trackpad.scaling" = 1.0;
        "com.apple.mouse.scaling" = 1.0;
      };

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

}
