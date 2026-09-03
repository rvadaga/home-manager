{ lib }:
let
  inherit (lib) mkEnableOption mkOption types;

  permission = types.submodule {
    options = {
      accessibility = mkEnableOption "accessibility access";
      fullDiskAccess = mkEnableOption "full disk access";
      screenRecording = mkEnableOption "screen and system audio recording";
      inputMonitoring = mkEnableOption "input monitoring";
      bluetooth = mkEnableOption "bluetooth access";
      camera = mkEnableOption "camera access";
      microphone = mkEnableOption "microphone access";
      localNetwork = mkEnableOption "local network access";
    };
  };

  application = types.submodule {
    options = {
      identifier = mkOption {
        type = types.str;
        description = "the tcc client identifier or executable path";
      };

      identifierType = mkOption {
        type = types.enum [
          "bundleID"
          "path"
        ];
        default = "bundleID";
        description = "the apple privacy payload identifier type";
      };

      codeRequirement = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "the designated requirement from codesign -dr -";
      };

      teamId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "the signing team used by macos 27 app settings";
      };

      staticCode = mkOption {
        type = types.bool;
        default = false;
        description = "whether the privacy payload validates static code";
      };

      organizationJustification = mkOption {
        type = types.str;
        default = "this app needs the selected permissions for its configured features.";
        description = "the explanation shown by the macos 27 consent prompt";
      };

      permissions = mkOption {
        type = permission;
        default = { };
        description = "the desired privacy permissions for this application";
      };
    };
  };
in
{
  inherit application permission;
}
