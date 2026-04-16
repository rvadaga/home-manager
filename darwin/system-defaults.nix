{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  system.defaults = {
    dock = {
      autohide = lib.mkDefault true;
      mineffect = lib.mkDefault "scale";
      mru-spaces = lib.mkDefault false;

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
    };

    trackpad = {
      Clicking = lib.mkDefault true;
      TrackpadThreeFingerDrag = lib.mkDefault true;
    };

    screensaver.askForPasswordDelay = lib.mkDefault 5;

    loginwindow.SHOWFULLNAME = lib.mkDefault true;

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

}
