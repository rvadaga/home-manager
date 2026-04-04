{ ... }: {
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      minimize-to-application = true;
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
