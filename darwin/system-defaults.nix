{ ... }: {
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      minimize-to-application = true;

      # keep in sync with casks in homebrew.nix — only list apps that are
      # either brew-managed or built-in system apps
      persistent-apps = [
        "/System/Applications/Mail.app"
        "/Applications/Google Chrome.app"
        "/System/Applications/Calendar.app"
        "/Applications/ChatGPT.app"
        "/Applications/Obsidian.app"
        "/Applications/Claude.app"
        "/Applications/1Password.app"
        "/Applications/Spotify.app"
        "/System/Applications/Music.app"
        "/Applications/Notion.app"
        "/Applications/Ghostty.app"
        "/Applications/Visual Studio Code.app"
        "/System/Applications/Messages.app"
        "/System/Applications/FindMy.app"
        "/System/Applications/FaceTime.app"
        "/System/Applications/iPhone Mirroring.app"
      ];

      persistent-others = [
        "/Users/rvadaga/Downloads"
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

  system.keyboard = {
    enableKeyMapping = true;
  };
}
