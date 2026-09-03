{ ... }:
{
  imports = [
    ./host.nix
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  # let unattended macos updates restart when ghostty has running processes.
  programs.ghostty.settings.confirm-close-surface = false;
}
