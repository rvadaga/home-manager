{ config, pkgs, lib, ... }: {
  home = {
    packages = [
      pkgs.pinentry-curses
    ];
  };

  programs = {
    zsh = {
      initContent = ''
        source $HOME/.nix-profile/etc/profile.d/hm-session-vars.sh
      '';
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableZshIntegration = true;
      pinentry.package = pkgs.pinentry-curses;
    };
  };
}
