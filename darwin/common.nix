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

  security.pam.services.sudo_local.touchIdAuth = true;

  environment.etc."sudoers.d/darwin-rebuild" = {
    text = ''
      ${user.name} ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
      ${user.name} ALL=(root) NOPASSWD: /usr/sbin/installer *
    '';
  };
}
