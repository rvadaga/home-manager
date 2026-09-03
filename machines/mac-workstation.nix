{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  home = {
    username = "rahul";
    homeDirectory = "/Users/rahul";
    stateVersion = "24.11";

    sessionVariables = {
      HM_CONFIG_NAME = "mac-workstation";
    };
  };

  claude.settingsPieces = lib.mkAfter [
    {
      permissions = {
        defaultMode = "bypassPermissions";
      };
    }
  ];

  # let unattended macos updates restart when ghostty has running processes.
  programs.ghostty.settings.confirm-close-surface = false;

  programs.git.signing.key = "0CA84231BC45DEC79B5D3045281566EDEF2E7A00";
}
