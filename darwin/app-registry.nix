{
  app-store = {
    dock = {
      path = "/System/Applications/Apps.app";
      position = 10;
    };
  };

  google-chrome = {
    name = "google chrome";
    cask = "google-chrome";
    dock = {
      path = "/Applications/Google Chrome.app";
      position = 20;
    };
    bootstrap.signIn = [
      "sign in with the google account that syncs bookmarks, extensions, and passwords"
    ];
    shellAliases.chrome = "open -a 'Google Chrome' --args --remote-debugging-port=9222";
  };

  spotify = {
    cask = "spotify";
    dock = {
      path = "/Applications/Spotify.app";
      position = 30;
    };
    bootstrap.signIn = [ "sign in" ];
  };

  music = {
    dock = {
      path = "/System/Applications/Music.app";
      position = 40;
    };
  };

  claude = {
    cask = "claude";
    dock = {
      path = "/Applications/Claude.app";
      position = 50;
    };
    bootstrap.signIn = [ "sign in" ];
  };

  chatgpt = {
    cask = "chatgpt";
    dock = {
      path = "/Applications/ChatGPT.app";
      position = 60;
    };
    bootstrap.signIn = [ "sign in" ];
  };

  mail = {
    dock = {
      path = "/System/Applications/Mail.app";
      position = 70;
    };
  };

  calendar = {
    dock = {
      path = "/System/Applications/Calendar.app";
      position = 80;
    };
  };

  reminders = {
    dock = {
      path = "/System/Applications/Reminders.app";
      position = 90;
    };
  };

  notion = {
    cask = "notion";
    dock = {
      path = "/Applications/Notion.app";
      position = 100;
    };
    bootstrap.signIn = [ "sign in" ];
  };

  obsidian = {
    cask = "obsidian";
    dock = {
      path = "/Applications/Obsidian.app";
      position = 110;
    };
    bootstrap.signIn = [ "sign in if sync is enabled" ];
  };

  "1password" = {
    cask = "1password";
    dock = {
      path = "/Applications/1Password.app";
      position = 120;
    };
    bootstrap.setup = [
      "open the app and sign in before the setup scripts run"
    ];
  };

  adobe-lightroom = {
    name = "adobe lightroom";
    profiles = [ "personal-laptop" ];
    dock = {
      path = "/Applications/Adobe Lightroom CC/Adobe Lightroom.app";
      position = 130;
    };
  };

  adobe-photoshop = {
    name = "adobe photoshop";
    profiles = [ "personal-laptop" ];
    dock = {
      path = "/Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app";
      position = 140;
    };
  };

  ghostty = {
    cask = "ghostty";
    dock = {
      path = "/Applications/Ghostty.app";
      position = 150;
    };
  };

  intellij-idea = {
    name = "intellij idea";
    profiles = [ "personal-laptop" ];
    dock = {
      path = "/Applications/IntelliJ IDEA CE.app";
      position = 160;
    };
  };

  visual-studio-code = {
    name = "visual studio code";
    cask = "visual-studio-code";
    dock = {
      path = "/Applications/Visual Studio Code.app";
      position = 170;
    };
    bootstrap.signIn = [ "sign in with github to enable settings sync" ];
  };

  facetime = {
    dock = {
      path = "/System/Applications/FaceTime.app";
      position = 180;
    };
  };

  messages = {
    dock = {
      path = "/System/Applications/Messages.app";
      position = 190;
    };
  };

  find-my = {
    name = "find my";
    dock = {
      path = "/System/Applications/FindMy.app";
      position = 200;
    };
  };

  iphone-mirroring = {
    name = "iphone mirroring";
    dock = {
      path = "/System/Applications/iPhone Mirroring.app";
      position = 210;
    };
  };

  screen-sharing = {
    name = "screen sharing";
    dock = {
      path = "/System/Applications/Utilities/Screen Sharing.app";
      position = 220;
    };
  };

  system-settings = {
    name = "system settings";
    dock = {
      path = "/System/Applications/System Settings.app";
      position = 230;
    };
  };

  bettermouse = {
    cask = "bettermouse";
    bootstrap = {
      privacy = [ "accessibility access" ];
      loginItems = [ "enable launch at login in the app" ];
      restore = [
        ''quit the app, restore "$GDRIVE/bettermouse/" to "$HOME/Library/Application Support/BetterMouse/", and copy its plist to "$HOME/Library/Preferences/"''
      ];
    };
    backup = {
      source = "Library/Application Support/BetterMouse";
      destination = "bettermouse";
      preferences = [
        "Library/Preferences/com.naotanhaocan.BetterMouse.plist"
      ];
    };
    license = {
      secret = "op://Private/BetterMouse License/license-key";
      domain = "com.naotanhaocan.BetterMouse";
      key = "licenseKey";
    };
  };

  bettertouchtool = {
    cask = "bettertouchtool";
    bootstrap = {
      privacy = [ "accessibility access" ];
      loginItems = [ "enable launch at login in the app" ];
      restore = [
        ''quit the app, restore "$GDRIVE/bettertouchtool/" to "$HOME/Library/Application Support/BetterTouchTool/", and copy its plist to "$HOME/Library/Preferences/"''
      ];
    };
    backup = {
      source = "Library/Application Support/BetterTouchTool";
      destination = "bettertouchtool";
      includes = [
        "btt_data_store.*"
        "bettertouchtool.bttlicense"
        "btt_user_variables.plist"
        "*.bttpreset"
        "PresetBundles/***"
      ];
      preferences = [
        "Library/Preferences/com.hegenberg.BetterTouchTool.plist"
      ];
    };
    license = {
      secret = "op://Private/BetterTouchTool License/license-key";
      domain = "com.hegenberg.BetterTouchTool";
      key = "BHTLicenseKey";
    };
  };

  betterdisplay = {
    # the headless workstation uses a virtual display for higher remote resolutions.
    cask = "betterdisplay";
    profiles = [ "mac-workstation" ];
  };

  codex.cask = "codex";

  docker-desktop = {
    name = "docker desktop";
    cask = "docker-desktop";
    bootstrap.signIn = [ "sign in if a docker hub account is needed" ];
  };

  google-drive = {
    name = "google drive";
    cask = "google-drive";
    bootstrap.signIn = [
      "sign in with the google account that stores app configuration backups"
    ];
  };

  itsycal = {
    cask = "itsycal";
    bootstrap = {
      privacy = [ "calendar access" ];
      loginItems = [ "enable launch at login in the app" ];
    };
    preferences."com.mowglii.ItsycalApp" = {
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
  };

  ice = {
    cask = "jordanbaird-ice";
    bootstrap = {
      privacy = [ "accessibility access" ];
      loginItems = [ "enable launch at login in the app" ];
    };
    preferences."com.jordanbaird.Ice" = {
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
  };

  meetingbar = {
    cask = "meetingbar";
    bootstrap = {
      privacy = [ "calendar access" ];
      loginItems = [ "enable launch at login in the app" ];
    };
    preferences."leits.MeetingBar" = {
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

  whatsapp = {
    cask = "whatsapp";
    bootstrap.signIn = [ "scan the qr code from the phone" ];
  };

  zoom.cask = "zoom";
}
