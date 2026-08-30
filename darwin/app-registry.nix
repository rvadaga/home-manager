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
    privacy.main = {
      identifier = "com.google.Chrome";
      teamId = "EQHXZ8M8AV";
      codeRequirement = ''(identifier "com.google.Chrome" or identifier "com.google.Chrome.beta" or identifier "com.google.Chrome.dev" or identifier "com.google.Chrome.canary") and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = EQHXZ8M8AV'';
      permissions = {
        bluetooth = true;
        camera = true;
        microphone = true;
      };
    };
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
    privacy = {
      desktop = {
        identifier = "com.anthropic.claudefordesktop";
        teamId = "Q6L2SF6YDW";
        codeRequirement = ''identifier "com.anthropic.claudefordesktop" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = Q6L2SF6YDW'';
        permissions = {
          accessibility = true;
          screenRecording = true;
          microphone = true;
        };
      };

      code = {
        identifier = "com.anthropic.claude-code";
        teamId = "Q6L2SF6YDW";
        codeRequirement = ''identifier "com.anthropic.claude-code" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = Q6L2SF6YDW'';
        permissions = {
          accessibility = true;
          fullDiskAccess = true;
        };
      };
    };
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
    privacy.main = {
      identifier = "com.1password.1password";
      teamId = "2BUA8C4S2C";
      codeRequirement = ''anchor apple generic and identifier "com.1password.1password" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "2BUA8C4S2C")'';
      permissions = {
        accessibility = true;
        screenRecording = true;
      };
    };
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
    privacy.main = {
      identifier = "com.mitchellh.ghostty";
      teamId = "24VZTF6M5V";
      codeRequirement = ''identifier "com.mitchellh.ghostty" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "24VZTF6M5V"'';
      permissions = {
        accessibility = true;
        fullDiskAccess = true;
      };
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
    privacy.main = {
      identifier = "com.naotanhaocan.BetterMouse";
      teamId = "85C2C89SJH";
      codeRequirement = ''anchor apple generic and identifier "com.naotanhaocan.BetterMouse" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "85C2C89SJH")'';
      permissions.accessibility = true;
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
    privacy.main = {
      identifier = "com.hegenberg.BetterTouchTool";
      teamId = "DAFVSXZ82P";
      codeRequirement = ''identifier "com.hegenberg.BetterTouchTool" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = DAFVSXZ82P'';
      permissions = {
        accessibility = true;
        screenRecording = true;
        inputMonitoring = true;
        bluetooth = true;
      };
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

  codex = {
    cask = "codex";
    privacy = {
      main = {
        identifier = "com.openai.codex";
        teamId = "2DC432GLL2";
        codeRequirement = ''identifier "com.openai.codex" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "2DC432GLL2"'';
        permissions = {
          accessibility = true;
          fullDiskAccess = true;
          screenRecording = true;
          microphone = true;
        };
      };

      computer-use = {
        identifier = "com.openai.sky.CUAService";
        teamId = "2DC432GLL2";
        codeRequirement = ''identifier "com.openai.sky.CUAService" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "2DC432GLL2"'';
        permissions = {
          accessibility = true;
          screenRecording = true;
        };
      };
    };
  };

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
    privacy.main = {
      identifier = "com.google.drivefs";
      teamId = "EQHXZ8M8AV";
      codeRequirement = ''identifier "com.google.drivefs" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = EQHXZ8M8AV'';
      permissions.fullDiskAccess = true;
    };
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
      loginItems = [ "enable launch at login in the app" ];
    };
    privacy.main = {
      identifier = "com.jordanbaird.Ice";
      teamId = "K2ATHQPJDP";
      codeRequirement = ''anchor apple generic and identifier "com.jordanbaird.Ice" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = K2ATHQPJDP)'';
      permissions = {
        accessibility = true;
        screenRecording = true;
      };
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

  discord = {
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "com.hnc.Discord";
      teamId = "53Q6R32WPB";
      codeRequirement = ''identifier "com.hnc.Discord" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "53Q6R32WPB"'';
      permissions.microphone = true;
    };
  };

  flameshot = {
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "org.flameshot.Flameshot";
      permissions.screenRecording = true;
    };
  };

  logi-options = {
    name = "logi options";
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "com.logi.cp-dev-mgr";
      teamId = "QED4VVPZWA";
      codeRequirement = ''identifier "com.logi.cp-dev-mgr" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = QED4VVPZWA'';
      permissions = {
        accessibility = true;
        inputMonitoring = true;
        bluetooth = true;
      };
    };
  };

  midea-air = {
    name = "midea air";
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "com.midea.obm";
      codeRequirement = ''anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.3] /* exists */ and identifier "com.midea.obm"'';
      permissions.bluetooth = true;
    };
  };

  monosnap = {
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "com.monosnap.monosnap";
      teamId = "39SV9K4FZU";
      codeRequirement = ''(anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "39SV9K4FZU") and identifier "com.monosnap.monosnap"'';
      permissions.screenRecording = true;
    };
  };

  paneherd = {
    profiles = [ "personal-laptop" ];
    privacy.main = {
      identifier = "com.paneherd.app";
      codeRequirement = ''identifier "com.paneherd.app"'';
      permissions = {
        accessibility = true;
        screenRecording = true;
      };
    };
  };

  whatsapp = {
    cask = "whatsapp";
    bootstrap.signIn = [ "scan the qr code from the phone" ];
    privacy.main = {
      identifier = "net.whatsapp.WhatsApp";
      teamId = "57T9237FN3";
      codeRequirement = ''identifier "net.whatsapp.WhatsApp" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "57T9237FN3"'';
      permissions = {
        camera = true;
        microphone = true;
      };
    };
  };

  zoom = {
    cask = "zoom";
    privacy.main = {
      identifier = "us.zoom.xos";
      teamId = "BJ4HAAB9B3";
      codeRequirement = ''identifier "us.zoom.xos" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = BJ4HAAB9B3'';
      permissions = {
        screenRecording = true;
        camera = true;
        microphone = true;
      };
    };
  };
}
