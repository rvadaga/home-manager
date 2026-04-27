{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  imports = [ ./common.nix ];

  system.primaryUser = "rahul";

  users.users.rahul = {
    name = "rahul";
    home = "/Users/rahul";
  };

  # mac-workstation has SIP disabled for paneherd runtime investigation —
  # allow dtrace, lldb, and signal-sending without password to streamline
  # tracing + debugger attach against running processes (e.g. Dock.app
  # during space switches, BetterTouchTool during cross-space window moves).
  environment.etc."sudoers.d/dtrace-nopasswd" = {
    text = ''
      ${user.name} ALL=(ALL) NOPASSWD: /usr/sbin/dtrace, /usr/bin/lldb, /usr/bin/pkill, /bin/kill, /run/current-system/sw/bin/darwin-rebuild
    '';
  };

  # mac-workstation has screen real estate to spare — keep dock always visible
  system.defaults.dock.autohide = false;

  # betterdisplay lets the headless mac mini offer higher resolutions over screen sharing
  # by emulating a virtual display (no physical monitor attached, so EDID is missing)
  homebrew.casks = lib.mkDefault [ "betterdisplay" ];

  launchd.user.agents.backup-app-configs = {
    command = toString ../scripts/backup-app-configs.sh;
    serviceConfig = {
      StartCalendarInterval = [{ Hour = 12; Minute = 0; }];
      StandardOutPath = "/tmp/backup-app-configs.log";
      StandardErrorPath = "/tmp/backup-app-configs.log";
    };
  };
}
