{ ... }: {
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

  launchd.user.agents.backup-app-configs = {
    command = toString ../scripts/backup-app-configs.sh;
    serviceConfig = {
      StartCalendarInterval = [{ Hour = 12; Minute = 0; }];
      StandardOutPath = "/tmp/backup-app-configs.log";
      StandardErrorPath = "/tmp/backup-app-configs.log";
    };
  };
}
