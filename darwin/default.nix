{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  imports = [
    ./nix.nix
    ./homebrew.nix
    ./system-defaults.nix
  ];

  system.stateVersion = 6;
  system.primaryUser = "rahul";

  users.users.rahul = {
    name = "rahul";
    home = "/Users/rahul";
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  # mac-workstation has screen real estate to spare — keep dock always visible
  system.defaults.dock.autohide = false;

  # betterdisplay lets the headless mac mini offer higher resolutions over screen sharing
  # by emulating a virtual display (no physical monitor attached, so EDID is missing)
  homebrew.casks = lib.mkDefault [ "betterdisplay" ];

  environment.etc."sudoers.d/darwin-rebuild" = {
    text = ''
      ${user.name} ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
      ${user.name} ALL=(root) NOPASSWD: /usr/sbin/installer *
    '';
  };

  launchd.user.agents.backup-app-configs = {
    command = toString ../scripts/backup-app-configs.sh;
    serviceConfig = {
      StartCalendarInterval = [{ Hour = 12; Minute = 0; }];
      StandardOutPath = "/tmp/backup-app-configs.log";
      StandardErrorPath = "/tmp/backup-app-configs.log";
    };
  };
}
