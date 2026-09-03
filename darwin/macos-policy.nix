{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.personal.macosPolicy;

  policyTypes = import ./macos-policy-types.nix { inherit lib; };

  applications = cfg.privacy.applications;
  applicationsFor =
    permission: lib.attrValues (lib.filterAttrs (_: app: app.permissions.${permission}) applications);
  profileApplicationsFor =
    permission: lib.filter (app: app.codeRequirement != null) (applicationsFor permission);

  mkPppcIdentity = authorization: app: {
    Identifier = app.identifier;
    IdentifierType = app.identifierType;
    CodeRequirement = app.codeRequirement;
    Authorization = authorization;
    StaticCode = app.staticCode;
  };

  pppcServices = lib.filterAttrs (_: entries: entries != [ ]) {
    Accessibility = map (mkPppcIdentity "Allow") (profileApplicationsFor "accessibility");
    SystemPolicyAllFiles = map (mkPppcIdentity "Allow") (profileApplicationsFor "fullDiskAccess");
    BluetoothAlways = map (mkPppcIdentity "Allow") (profileApplicationsFor "bluetooth");
    ScreenCapture = map (mkPppcIdentity "AllowStandardUserToSetSystemService") (
      profileApplicationsFor "screenRecording"
    );
    ListenEvent = map (mkPppcIdentity "AllowStandardUserToSetSystemService") (
      profileApplicationsFor "inputMonitoring"
    );
  };

  ddmPermissions =
    app:
    lib.filterAttrs (_: value: value != null) {
      Accessibility = if app.permissions.accessibility then "Allow" else null;
      Bluetooth = if app.permissions.bluetooth then "Allow" else null;
      Camera = if app.permissions.camera then "Allow" else null;
      Microphone = if app.permissions.microphone then "Allow" else null;
      LocalNetwork = if app.permissions.localNetwork then "Allow" else null;
    };

  hasDdmPermissions = app: app.identifierType == "bundleID" && ddmPermissions app != { };

  ddmApplications = lib.mapAttrs' (
    _: app:
    lib.nameValuePair (
      if app.teamId == null then app.identifier else "${app.identifier} (${app.teamId})"
    ) ({ OrganizationJustification = app.organizationJustification; } // ddmPermissions app)
  ) (lib.filterAttrs (_: hasDdmPermissions) applications);

  jsonFormat = pkgs.formats.json { };
  plistFormat = pkgs.formats.plist { };

  policyFile = jsonFormat.generate "macos-policy.json" {
    firewall = {
      inherit (cfg.firewall)
        enable
        blockAllIncoming
        allowSignedBuiltIn
        allowSignedDownloaded
        stealthMode
        ;
    };
    inherit (cfg) sharing;
    privacy.applications = applications;
  };

  pppcProfile = plistFormat.generate "privacy-preferences.mobileconfig" {
    PayloadContent = [
      {
        Services = pppcServices;
        PayloadDisplayName = "personal mac privacy preferences";
        PayloadIdentifier = "com.personal.nix-darwin.privacy.preferences";
        PayloadType = "com.apple.TCC.configuration-profile-policy";
        PayloadUUID = "6065C4D0-065A-41FD-9C2D-37F426B6A9E6";
        PayloadVersion = 1;
      }
    ];
    PayloadDescription = "applies the privacy grants declared by nix-darwin";
    PayloadDisplayName = "personal mac privacy policy";
    PayloadIdentifier = "com.personal.nix-darwin.privacy";
    PayloadOrganization = "personal";
    PayloadRemovalDisallowed = false;
    PayloadScope = "System";
    PayloadType = "Configuration";
    PayloadUUID = "D191B839-BA29-4F29-8AF1-5487BA151A28";
    PayloadVersion = 1;
  };

  ddmPrivacy = jsonFormat.generate "app-settings-privacy.json" {
    Type = "com.apple.configuration.app.settings";
    Identifier = "134291DB-06D1-4116-BBEA-6B75CF8DAF1E";
    ServerToken = "4294AFCE-F95C-4C0B-9DEF-6D20AC6BD411";
    Payload.Privacy.PermissionDefaults = ddmApplications;
  };

  policyAudit = pkgs.writeShellApplication {
    name = "macos-policy-audit";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.lsof
      pkgs.sqlite
    ];
    text = builtins.readFile ../scripts/macos-policy-audit.sh;
  };
in
{
  options.personal.macosPolicy = {
    enable = lib.mkEnableOption "the declarative macos security and sharing policy";

    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "whether to enable the macos application firewall";
      };
      blockAllIncoming = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "whether to block every incoming connection";
      };
      allowSignedBuiltIn = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "whether built-in signed software may accept connections";
      };
      allowSignedDownloaded = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "whether downloaded signed software may accept connections";
      };
      stealthMode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "whether the firewall ignores unsolicited probes";
      };
    };

    sharing = {
      remoteLogin = lib.mkEnableOption "remote login over ssh";
      screenSharing = lib.mkEnableOption "screen sharing";
      remoteManagement = lib.mkEnableOption "apple remote desktop management";
      remoteAppleEvents = lib.mkEnableOption "remote application scripting";
      fileSharing = lib.mkEnableOption "file sharing";
      mediaSharing = lib.mkEnableOption "media sharing";
      contentCaching = lib.mkEnableOption "content caching";
      bluetoothSharing = lib.mkEnableOption "bluetooth sharing";
      printerSharing = lib.mkEnableOption "printer sharing";
      internetSharing = lib.mkEnableOption "internet sharing";
      airPlayReceiver = lib.mkEnableOption "airplay receiver";
    };

    privacy.applications = lib.mkOption {
      type = lib.types.attrsOf policyTypes.application;
      default = { };
      description = "one application registry used by every generated privacy artifact";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.sharing.screenSharing && cfg.sharing.remoteManagement);
        message = "screen sharing and remote management cannot both be enabled";
      }
    ];

    warnings =
      lib.optional cfg.sharing.screenSharing "screen sharing must be enabled in system settings or by device management"
      ++ lib.optional cfg.sharing.remoteManagement "remote management must be enabled by the device-management EnableRemoteDesktop command";

    networking.applicationFirewall = {
      enable = lib.mkDefault cfg.firewall.enable;
      blockAllIncoming = lib.mkDefault cfg.firewall.blockAllIncoming;
      allowSigned = lib.mkDefault cfg.firewall.allowSignedBuiltIn;
      allowSignedApp = lib.mkDefault cfg.firewall.allowSignedDownloaded;
      enableStealthMode = lib.mkDefault cfg.firewall.stealthMode;
    };

    services.openssh.enable = lib.mkDefault cfg.sharing.remoteLogin;

    system.activationScripts.postActivation.text = lib.mkAfter ''
      echo "configuring content caching..." >&2
      if ! /usr/bin/AssetCacheManagerUtil ${
        if cfg.sharing.contentCaching then "activate" else "deactivate"
      } >/dev/null 2>&1; then
        echo "warning: content caching could not be changed" >&2
      fi

      ${lib.optionalString (!cfg.sharing.remoteManagement) ''
        remote_management_tool=/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart
        if [[ -x "$remote_management_tool" ]]; then
          if ! "$remote_management_tool" -deactivate >/dev/null 2>&1; then
            echo "warning: remote management could not be disabled" >&2
          fi
        fi
      ''}
    '';

    environment.systemPackages = [ policyAudit ];

    environment.etc = {
      "nix-darwin/policies/macos-policy.json".source = policyFile;
      "nix-darwin/privacy/privacy-preferences.mobileconfig".source = pppcProfile;
      "nix-darwin/privacy/app-settings-privacy.json".source = ddmPrivacy;
      "nix-darwin/privacy/readme.txt".text = ''
        privacy-preferences.mobileconfig targets macos 26 and requires user-approved device management.
        accessibility grants in that payload are removed in macos 27.

        app-settings-privacy.json is the macos 27 declarative device-management replacement.
        it presents one consent prompt for the declared accessibility, bluetooth, camera,
        microphone, and local-network defaults.

        neither file is installed automatically. upload the applicable artifact to the
        computer's device-management service, then run macos-policy-audit to verify the
        effective grants. screen recording and input monitoring still require user approval.
      '';
    };
  };
}
