{ lib, ... }: {
  imports = [ ./common.nix ];

  system.primaryUser = "rahul";

  users.users.rahul = {
    name = "rahul";
    home = "/Users/rahul";
  };

  # mac-workstation has SIP disabled for paneherd menu bar investigation —
  # allow dtrace + signal-sending without password to streamline runtime
  # tracing of Dock.app during space switches.
  environment.etc."sudoers.d/dtrace-nopasswd" = {
    text = ''
      rahul ALL=(ALL) NOPASSWD: /usr/sbin/dtrace, /usr/bin/pkill, /bin/kill
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
