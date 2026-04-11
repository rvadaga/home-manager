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

  # SETENV tag on /usr/sbin/installer is required because homebrew cask's pkg
  # installer invokes `sudo -u root -E ...` to preserve HOMEBREW_* env vars;
  # without it, sudo refuses with "not allowed to preserve the environment".
  environment.etc."sudoers.d/darwin-rebuild" = {
    text = ''
      ${user.name} ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
      ${user.name} ALL=(root) NOPASSWD:SETENV: /usr/sbin/installer *
    '';
  };
}
