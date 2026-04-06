{ config, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      minimize-to-application = true;

      # keep in sync with casks in homebrew.nix — only list apps that are
      # either brew-managed or built-in system apps
      persistent-apps = [
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

      wvous-tl-corner = 2;  # mission control
      wvous-tr-corner = 12; # notification center

      persistent-others = [
        "${user.home}/Downloads"
      ];
    };

    finder = {
      FXPreferredViewStyle = "clmv";
      ShowPathbar = true;
      ShowStatusBar = true;
      FXDefaultSearchScope = "SCcf";
    };

    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      "com.apple.swipescrolldirection" = true;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    CustomUserPreferences = {
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
