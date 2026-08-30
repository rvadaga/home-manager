{ config, lib, pkgs, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  imports = [
    ./nix.nix
    ./apps.nix
    ./system-defaults.nix
    ./provenance.nix
  ];

  # fonts must be installed at the system level on macos — home-manager's
  # fontconfig path is linux-only. coretext only scans /Library/Fonts and
  # ~/Library/Fonts, not ~/.nix-profile/share/fonts. nix-darwin's fonts.packages
  # symlinks these into /Library/Fonts/Nix Fonts/ during activation.
  fonts.packages = with pkgs; [
    fira                  # fira sans + fira mono (mozilla)
    nerd-fonts.fira-code
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
