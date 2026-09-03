{ ... }:
{
  imports = [
    ./nix.nix
    ./apps.nix
    ./fonts.nix
    ./system-defaults.nix
    ./provenance.nix
  ];

  system.stateVersion = 6;

  security.pam.services.sudo_local.touchIdAuth = true;

  launchd.daemons.stay-awake.serviceConfig = {
    ProgramArguments = [
      "/bin/zsh"
      (toString ../scripts/stay-awake.zsh)
    ];
    RunAtLoad = true;
    ProcessType = "Background";
  };
}
