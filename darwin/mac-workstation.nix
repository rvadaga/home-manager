{ config, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  imports = [ ./common.nix ];

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

  personal.apps.backups = {
    enable = true;
    provider = "google-drive";
    root = "Library/CloudStorage/GoogleDrive-rahul.vadaga@gmail.com/My Drive/gdrive documents/software";
    extraFiles = [{
      source = "Library/Preferences/com.apple.controlcenter.plist";
      destination = "macos-system";
    }];
  };
}
