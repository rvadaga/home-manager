{ ... }:
{
  imports = [ ./common.nix ];

  system.primaryUser = "rvadaga";

  users.users.rvadaga = {
    name = "rvadaga";
    home = "/Users/rvadaga";
  };

  personal.macosPolicy = {
    enable = true;

    firewall = {
      enable = true;
      blockAllIncoming = false;
      allowSignedBuiltIn = true;
      allowSignedDownloaded = true;
      stealthMode = true;
    };

    sharing.airPlayReceiver = true;

    privacy.applications = {
      onePassword = {
        identifier = "com.1password.1password";
        teamId = "2BUA8C4S2C";
        codeRequirement = ''anchor apple generic and identifier "com.1password.1password" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "2BUA8C4S2C")'';
        permissions = {
          accessibility = true;
          screenRecording = true;
        };
      };

      betterMouse = {
        identifier = "com.naotanhaocan.BetterMouse";
        teamId = "85C2C89SJH";
        codeRequirement = ''anchor apple generic and identifier "com.naotanhaocan.BetterMouse" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "85C2C89SJH")'';
        permissions.accessibility = true;
      };

      betterTouchTool = {
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

      codex = {
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

      codexComputerUse = {
        identifier = "com.openai.sky.CUAService";
        teamId = "2DC432GLL2";
        codeRequirement = ''identifier "com.openai.sky.CUAService" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "2DC432GLL2"'';
        permissions = {
          accessibility = true;
          screenRecording = true;
        };
      };

      claude = {
        identifier = "com.anthropic.claudefordesktop";
        teamId = "Q6L2SF6YDW";
        codeRequirement = ''identifier "com.anthropic.claudefordesktop" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = Q6L2SF6YDW'';
        permissions = {
          accessibility = true;
          screenRecording = true;
          microphone = true;
        };
      };

      claudeCode = {
        identifier = "com.anthropic.claude-code";
        teamId = "Q6L2SF6YDW";
        codeRequirement = ''identifier "com.anthropic.claude-code" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = Q6L2SF6YDW'';
        permissions = {
          accessibility = true;
          fullDiskAccess = true;
        };
      };

      chrome = {
        identifier = "com.google.Chrome";
        teamId = "EQHXZ8M8AV";
        codeRequirement = ''(identifier "com.google.Chrome" or identifier "com.google.Chrome.beta" or identifier "com.google.Chrome.dev" or identifier "com.google.Chrome.canary") and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = EQHXZ8M8AV'';
        permissions = {
          bluetooth = true;
          camera = true;
          microphone = true;
        };
      };

      discord = {
        identifier = "com.hnc.Discord";
        teamId = "53Q6R32WPB";
        codeRequirement = ''identifier "com.hnc.Discord" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "53Q6R32WPB"'';
        permissions.microphone = true;
      };

      flameshot = {
        identifier = "org.flameshot.Flameshot";
        permissions.screenRecording = true;
      };

      ghostty = {
        identifier = "com.mitchellh.ghostty";
        teamId = "24VZTF6M5V";
        codeRequirement = ''identifier "com.mitchellh.ghostty" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "24VZTF6M5V"'';
        permissions = {
          accessibility = true;
          fullDiskAccess = true;
        };
      };

      googleDrive = {
        identifier = "com.google.drivefs";
        teamId = "EQHXZ8M8AV";
        codeRequirement = ''identifier "com.google.drivefs" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = EQHXZ8M8AV'';
        permissions.fullDiskAccess = true;
      };

      ice = {
        identifier = "com.jordanbaird.Ice";
        teamId = "K2ATHQPJDP";
        codeRequirement = ''anchor apple generic and identifier "com.jordanbaird.Ice" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = K2ATHQPJDP)'';
        permissions = {
          accessibility = true;
          screenRecording = true;
        };
      };

      logiOptions = {
        identifier = "com.logi.cp-dev-mgr";
        teamId = "QED4VVPZWA";
        codeRequirement = ''identifier "com.logi.cp-dev-mgr" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = QED4VVPZWA'';
        permissions = {
          accessibility = true;
          inputMonitoring = true;
          bluetooth = true;
        };
      };

      mideaAir = {
        identifier = "com.midea.obm";
        codeRequirement = ''anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.3] /* exists */ and identifier "com.midea.obm"'';
        permissions.bluetooth = true;
      };

      monosnap = {
        identifier = "com.monosnap.monosnap";
        teamId = "39SV9K4FZU";
        codeRequirement = ''(anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "39SV9K4FZU") and identifier "com.monosnap.monosnap"'';
        permissions.screenRecording = true;
      };

      paneherd = {
        identifier = "com.paneherd.app";
        codeRequirement = ''identifier "com.paneherd.app"'';
        permissions = {
          accessibility = true;
          screenRecording = true;
        };
      };

      whatsapp = {
        identifier = "net.whatsapp.WhatsApp";
        teamId = "57T9237FN3";
        codeRequirement = ''identifier "net.whatsapp.WhatsApp" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "57T9237FN3"'';
        permissions = {
          camera = true;
          microphone = true;
        };
      };

      zoom = {
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
  };

  power.sleep = {
    computer = 1;
    display = 10;
    harddisk = 10;
    allowSleepByPowerButton = true;
  };

  system.startup.chime = true;

  # laptop-specific dock — hard override of the shared list in system-defaults.nix.
  # includes creative and jvm-ide apps that the workstation doesn't need.
  system.defaults.dock.persistent-apps = [
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
    "/Applications/Adobe Lightroom CC/Adobe Lightroom.app"
    "/Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app"
    "/Applications/Ghostty.app"
    "/Applications/IntelliJ IDEA CE.app"
    "/Applications/Visual Studio Code.app"
    "/System/Applications/FaceTime.app"
    "/System/Applications/Messages.app"
    "/System/Applications/FindMy.app"
    "/System/Applications/iPhone Mirroring.app"
    "/System/Applications/Utilities/Screen Sharing.app"
    "/System/Applications/System Settings.app"
  ];
}
