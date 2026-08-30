{ ... }:
{
  imports = [ ./common.nix ];

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
  };

  power.sleep = {
    computer = 1;
    display = 10;
    harddisk = 10;
    allowSleepByPowerButton = true;
  };

  system.startup.chime = true;
}
