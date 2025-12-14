{ config, pkgs, lib, ... }: {
  imports = [
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home = {
    username = "rvadaga";
    homeDirectory = "/Users/rvadaga";

    # This value determines the Home Manager release that your configuration is
    # compatible with. This helps avoid breakage when a new Home Manager release
    # introduces backwards incompatible changes.
    stateVersion = "24.11";

    packages = [
      # Adds the 'hello' command to your environment. It prints a friendly
      # "Hello, world!" when run.
      # pkgs.hello

      # It is sometimes useful to fine-tune packages, for example, by applying
      # overrides. You can do that directly here, just don't forget the
      # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

      # You can also create simple shell scripts directly inside your
      # configuration. For example, this adds a command 'my-hello' to your
      # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
    ];

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    file = {
      # Building this configuration will create a copy of 'dotfiles/screenrc' in
      # the Nix store. Activating the configuration will then make '~/.screenrc' a
      # symlink to the Nix store copy.
      # ".screenrc".source = dotfiles/screenrc;

      # You can also set the file content immediately.
      # ".gradle/gradle.properties".text = ''
      #   org.gradle.console=verbose
      #   org.gradle.daemon.idletimeout=3600000
      # '';
    };

    # Home Manager can also manage your environment variables through
    # 'home.sessionVariables'. These will be explicitly sourced when using a
    # shell provided by Home Manager. If you don't want to manage your shell
    # through Home Manager then you have to manually source 'hm-session-vars.sh'
    # located at either
    #
    #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
    #
    # or
    #
    #  /etc/profiles/per-user/rvadaga/etc/profile.d/hm-session-vars.sh
    #
    sessionVariables = {
      # EDITOR = "emacs";
    };

    sessionPath = [
      # useful for appending to PATH
      # "$HOME/development/sciences/tools"
    ];
  };


  # required to autoload fonts from packages installed via Home Manager
  fonts = {
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Fira Code Nerd Font" ];
      };
    };
  };

  # Let Home Manager install and manage itself.
  programs = {
    emacs = {
      enable = true;
      extraPackages = epkgs: [
        epkgs.nix-mode
        epkgs.magit
      ];
    };

    git = {
      enable = true;

      userName = "Rahul Vadaga";
      userEmail = "rahul.vadaga@gmail.com";

      signing = {
        key = null;
        signByDefault = true;
      };


      # extraConfig = {
      #   commit.gpgsign = true;
      #   gpg.format = "ssh";
      # };
    };

    gpg = {
      enable = true;
      homedir = "${config.home.homeDirectory}/.gnupg";
    };

    home-manager = {
      enable = true;
    };
  };

  services = {
  #   gpg-agent = {
  #     enable = true;
  #     extraConfig = ''
  #       pinentry-program ${pkgs.pinentry.gnome3}/bin/pinentry-gnome3
  #     '';
  #   };
  };
}
