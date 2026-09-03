{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
  policyTypes = import ./macos-policy-types.nix { inherit lib; };

  privacyPermissionNames = [
    "accessibility"
    "fullDiskAccess"
    "screenRecording"
    "inputMonitoring"
    "bluetooth"
    "camera"
    "microphone"
    "localNetwork"
  ];
  privacyPermissionLabels = {
    accessibility = "accessibility access";
    fullDiskAccess = "full disk access";
    screenRecording = "screen and system audio recording";
    inputMonitoring = "input monitoring";
    bluetooth = "bluetooth access";
    camera = "camera access";
    microphone = "microphone access";
    localNetwork = "local network access";
  };

  backupType = types.submodule {
    options = {
      source = mkOption {
        type = types.str;
        description = "path below the user home directory to back up";
      };

      destination = mkOption {
        type = types.str;
        description = "directory below the configured backup root";
      };

      includes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "rsync include patterns; an empty list copies the full source";
      };

      preferences = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "preference files below the user home directory to copy beside the backup";
      };
    };
  };

  licenseType = types.submodule {
    options = {
      secret = mkOption {
        type = types.str;
        description = "1password secret reference containing the license value";
      };

      domain = mkOption {
        type = types.str;
        description = "defaults domain that receives the license value";
      };

      key = mkOption {
        type = types.str;
        description = "defaults key that receives the license value";
      };
    };
  };

  appType = types.submodule (
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = builtins.replaceStrings [ "-" ] [ " " ] name;
          description = "lower-case name used in generated setup instructions";
        };

        enable = mkOption {
          type = types.bool;
          default = true;
          description = "whether this app and every derived reference to it are enabled";
        };

        profiles = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "configuration names that enable this app; an empty list enables it everywhere";
        };

        cask = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "homebrew cask that installs the app";
        };

        dock = {
          path = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "application path to place in the dock";
          };

          position = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "stable sort position for the dock entry";
          };
        };

        preferences = mkOption {
          type = types.attrsOf types.attrs;
          default = { };
          description = "custom user preference domains owned by the app";
        };

        privacy = mkOption {
          type = types.attrsOf policyTypes.application;
          default = { };
          description = "privacy policy clients owned by the app";
        };

        bootstrap = {
          setup = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "steps that must happen before bootstrap setup scripts run";
          };

          signIn = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "sign-in steps shown after bootstrap";
          };

          privacy = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "privacy permissions shown after bootstrap";
          };

          loginItems = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "login item steps shown after bootstrap";
          };

          restore = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "configuration restore steps shown after bootstrap";
          };
        };

        backup = mkOption {
          type = types.nullOr backupType;
          default = null;
          description = "backup data owned by the app";
        };

        license = mkOption {
          type = types.nullOr licenseType;
          default = null;
          description = "license setup data owned by the app";
        };

        shellAliases = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "shell aliases owned by the app";
        };

        dependsOn = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "other registry entries that must be enabled with this app";
        };
      };
    }
  );

  extraFileType = types.submodule {
    options = {
      source = mkOption {
        type = types.str;
        description = "file below the user home directory to back up";
      };

      destination = mkOption {
        type = types.str;
        description = "directory below the configured backup root";
      };
    };
  };

  cfg = config.personal.apps;
  duplicateAdditionalApps = lib.intersectLists (builtins.attrNames cfg.registry) (
    builtins.attrNames cfg.additional
  );
  catalog = cfg.registry // cfg.additional;
  registryEntries = lib.mapAttrsToList (id: app: { inherit app id; }) catalog;
  unknownDisabledApps = lib.filter (id: !(builtins.hasAttr id catalog)) cfg.disabled;
  isEnabled =
    id: app:
    app.enable
    && !(lib.elem id cfg.disabled)
    && (app.profiles == [ ] || lib.elem cfg.profile app.profiles);
  enabledApps = lib.filterAttrs isEnabled catalog;
  appEntries = lib.mapAttrsToList (id: app: { inherit app id; }) enabledApps;

  caskEntries = lib.filter (entry: entry.app.cask != null) appEntries;
  casks = map (entry: entry.app.cask) caskEntries;

  dockEntries = lib.sort (left: right: left.app.dock.position < right.app.dock.position) (
    lib.filter (entry: entry.app.dock.path != null) appEntries
  );
  dockPaths = map (entry: entry.app.dock.path) dockEntries;
  dockPositions = map (entry: entry.app.dock.position) dockEntries;

  preferenceEntries = lib.concatMap (
    entry:
    lib.mapAttrsToList (domain: values: {
      app = entry.id;
      inherit domain values;
    }) entry.app.preferences
  ) appEntries;
  preferenceDomains = map (entry: entry.domain) preferenceEntries;
  appPreferences = lib.listToAttrs (
    map (entry: lib.nameValuePair entry.domain entry.values) preferenceEntries
  );

  backupEntries = lib.filter (entry: entry.app.backup != null) appEntries;
  backupDestinations = map (entry: entry.app.backup.destination) backupEntries;
  licenseEntries = lib.filter (entry: entry.app.license != null) appEntries;
  licenseTargets = map (entry: "${entry.app.license.domain}:${entry.app.license.key}") licenseEntries;
  privacyEntries = lib.concatMap (
    entry:
    lib.mapAttrsToList (client: application: {
      app = entry.id;
      displayName = entry.app.name;
      inherit application client;
      name = "${entry.id}-${client}";
    }) entry.app.privacy
  ) appEntries;
  privacyApplications = lib.listToAttrs (
    map (entry: lib.nameValuePair entry.name entry.application) privacyEntries
  );
  privacyIdentifiers = map (entry: entry.application.identifier) privacyEntries;
  privacyInstructions = lib.concatMap (
    entry:
    map (permission: {
      app = entry.app;
      name = entry.displayName;
      text =
        lib.optionalString (entry.client != "main") "${entry.client}: "
        + privacyPermissionLabels.${permission};
    }) (lib.filter (permission: entry.application.permissions.${permission}) privacyPermissionNames)
  ) privacyEntries;
  shellAliasEntries = lib.concatMap (
    entry:
    lib.mapAttrsToList (name: command: {
      app = entry.id;
      inherit command name;
    }) entry.app.shellAliases
  ) appEntries;
  shellAliasNames = map (entry: entry.name) shellAliasEntries;

  manifestSteps =
    field:
    lib.concatMap (
      entry:
      map (text: {
        app = entry.id;
        name = entry.app.name;
        inherit text;
      }) entry.app.bootstrap.${field}
    ) appEntries;

  manifest = {
    apps = map (entry: entry.id) appEntries;
    casks = map (entry: {
      app = entry.id;
      name = entry.app.cask;
    }) caskEntries;
    dock = map (entry: {
      app = entry.id;
      path = entry.app.dock.path;
      position = entry.app.dock.position;
    }) dockEntries;
    preferences = map (entry: {
      app = entry.app;
      domain = entry.domain;
    }) preferenceEntries;
    backups = map (entry: {
      app = entry.id;
      destination = entry.app.backup.destination;
      provider = cfg.backups.provider;
    }) backupEntries;
    licenses = map (entry: {
      app = entry.id;
      domain = entry.app.license.domain;
      key = entry.app.license.key;
    }) licenseEntries;
    privacyPolicies = map (entry: {
      app = entry.app;
      name = entry.name;
      identifier = entry.application.identifier;
    }) privacyEntries;
    shellAliases = map (entry: {
      app = entry.app;
      name = entry.name;
    }) shellAliasEntries;
    setup = manifestSteps "setup";
    signIn = manifestSteps "signIn";
    privacy = manifestSteps "privacy" ++ privacyInstructions;
    loginItems = manifestSteps "loginItems";
    restore = manifestSteps "restore";
  };

  malformedDockEntries = lib.filter (
    entry: (entry.app.dock.path == null) != (entry.app.dock.position == null)
  ) registryEntries;
  missingDependencies = lib.concatMap (
    entry:
    map (dependency: "${entry.id}:${dependency}") (
      lib.filter (dependency: !(builtins.hasAttr dependency enabledApps)) entry.app.dependsOn
    )
  ) appEntries;

  backupBlock =
    entry:
    let
      backup = entry.app.backup;
      includeFlags = lib.concatMapStringsSep " " (
        pattern: "--include ${lib.escapeShellArg pattern}"
      ) backup.includes;
      filterFlags = lib.optionalString (backup.includes != [ ]) "${includeFlags} --exclude '*'";
      preferenceBlocks = lib.concatMapStringsSep "\n" (preference: ''
        preference_path="$HOME"/${lib.escapeShellArg preference}
        if [[ -f "$preference_path" ]]; then
          rsync -au "$preference_path" "$destination_path/"
        fi
      '') backup.preferences;
    in
    ''
      source_path="$HOME"/${lib.escapeShellArg backup.source}
      destination_path="$backup_root"/${lib.escapeShellArg backup.destination}
      mkdir -p "$destination_path"

      if [[ -d "$source_path" ]]; then
        rsync -au --delete ${filterFlags} "$source_path/" "$destination_path/"
      else
        echo ${lib.escapeShellArg "skipping ${entry.app.name}: source directory is missing"}
      fi

      ${preferenceBlocks}
    '';

  extraFileBlock = file: ''
    source_path="$HOME"/${lib.escapeShellArg file.source}
    destination_path="$backup_root"/${lib.escapeShellArg file.destination}
    if [[ -f "$source_path" ]]; then
      mkdir -p "$destination_path"
      rsync -au "$source_path" "$destination_path/"
    fi
  '';

  licenseBlock = entry: ''
    license_value="$(op read ${lib.escapeShellArg entry.app.license.secret} 2>/dev/null || true)"
    if [[ -n "$license_value" ]]; then
      /usr/bin/defaults write ${lib.escapeShellArg entry.app.license.domain} ${lib.escapeShellArg entry.app.license.key} "$license_value"
      echo ${lib.escapeShellArg "${entry.app.name}: applied"}
    else
      echo ${lib.escapeShellArg "${entry.app.name}: license was not found in 1password"}
    fi
  '';

  backupScript = pkgs.writeShellApplication {
    name = "backup-app-configs";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.rsync
    ];
    text = ''
      backup_root="$HOME"/${lib.escapeShellArg cfg.backups.root}
      if [[ ! -d "$backup_root" ]]; then
        echo "app backup root is not available: $backup_root"
        exit 0
      fi

      ${lib.concatMapStringsSep "\n" backupBlock backupEntries}
      ${lib.concatMapStringsSep "\n" extraFileBlock cfg.backups.extraFiles}
    '';
  };

  licenseSetupScript = pkgs.writeShellApplication {
    name = "setup-app-licenses";
    runtimeInputs = [ pkgs._1password-cli ];
    text = ''
      if [[ "''${1:-}" == "--help" ]]; then
        echo "usage: setup-app-licenses"
        echo "read app license values from 1password and apply them with defaults"
        exit 0
      fi
      if (( $# != 0 )); then
        echo "setup-app-licenses does not accept arguments" >&2
        exit 2
      fi

      echo "applying app licenses from 1password"
      ${lib.concatMapStringsSep "\n" licenseBlock licenseEntries}
    '';
  };
in
{
  imports = [
    ./homebrew.nix
    ./macos-policy.nix
  ];

  options.personal.apps = {
    profile = mkOption {
      type = types.str;
      default = "default";
      description = "configuration name used to select profile-specific apps";
    };

    registry = mkOption {
      type = types.attrsOf appType;
      default = import ./app-registry.nix;
      readOnly = true;
      description = "central owner of app installation, dock, preferences, privacy, setup, license, alias, and backup data";
    };

    additional = mkOption {
      type = types.attrsOf appType;
      default = { };
      description = "extra app records added by a consuming configuration";
    };

    disabled = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "registry app ids whose generated references are disabled";
    };

    manifest = mkOption {
      type = types.attrs;
      readOnly = true;
      description = "generated app references consumed by bootstrap and validation";
    };

    backups = {
      enable = mkEnableOption "daily app configuration backups";

      root = mkOption {
        type = types.str;
        default = "";
        description = "backup root below the user home directory";
      };

      provider = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "enabled app that provides the backup destination";
      };

      extraFiles = mkOption {
        type = types.listOf extraFileType;
        default = [ ];
        description = "non-app files included in the app backup job";
      };
    };
  };

  config = {
    home-manager.extraSpecialArgs.personalAppRegistry = enabledApps;
    personal.macosPolicy.privacy.applications = privacyApplications;

    assertions = [
      {
        assertion = malformedDockEntries == [ ];
        message = "every app dock entry must define both path and position";
      }
      {
        assertion = unknownDisabledApps == [ ];
        message = "disabled app ids are missing from the registry: ${lib.concatStringsSep ", " unknownDisabledApps}";
      }
      {
        assertion = duplicateAdditionalApps == [ ];
        message = "additional app ids already exist in the registry: ${lib.concatStringsSep ", " duplicateAdditionalApps}";
      }
      {
        assertion = lib.length casks == lib.length (lib.unique casks);
        message = "enabled apps must not declare duplicate homebrew casks";
      }
      {
        assertion = lib.length dockPaths == lib.length (lib.unique dockPaths);
        message = "enabled apps must not declare duplicate dock paths";
      }
      {
        assertion = lib.length dockPositions == lib.length (lib.unique dockPositions);
        message = "enabled apps must not declare duplicate dock positions";
      }
      {
        assertion = lib.length preferenceDomains == lib.length (lib.unique preferenceDomains);
        message = "enabled apps must not declare the same preference domain more than once";
      }
      {
        assertion = lib.length backupDestinations == lib.length (lib.unique backupDestinations);
        message = "enabled app backups must use unique destinations";
      }
      {
        assertion = lib.length licenseTargets == lib.length (lib.unique licenseTargets);
        message = "enabled app licenses must use unique defaults targets";
      }
      {
        assertion = lib.length privacyIdentifiers == lib.length (lib.unique privacyIdentifiers);
        message = "enabled app privacy clients must use unique identifiers";
      }
      {
        assertion = lib.length shellAliasNames == lib.length (lib.unique shellAliasNames);
        message = "enabled apps must not declare duplicate shell aliases";
      }
      {
        assertion = missingDependencies == [ ];
        message = "enabled apps have missing dependencies: ${lib.concatStringsSep ", " missingDependencies}";
      }
      {
        assertion = !cfg.backups.enable || cfg.backups.root != "";
        message = "personal.apps.backups.root must be set when backups are enabled";
      }
      {
        assertion =
          !cfg.backups.enable
          || cfg.backups.provider == null
          || builtins.hasAttr cfg.backups.provider enabledApps;
        message = "the configured app backup provider must be enabled";
      }
    ];

    personal.apps.manifest = manifest;

    homebrew.casks = lib.mkDefault casks;
    environment.systemPackages = [ licenseSetupScript ];
    system.defaults.dock.persistent-apps = lib.mkDefault dockPaths;
    system.defaults.CustomUserPreferences = lib.mkDefault appPreferences;

    launchd.user.agents.backup-app-configs = lib.mkIf cfg.backups.enable {
      command = "${backupScript}/bin/backup-app-configs";
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 12;
            Minute = 0;
          }
        ];
        StandardOutPath = "/tmp/backup-app-configs.log";
        StandardErrorPath = "/tmp/backup-app-configs.log";
      };
    };
  };
}
