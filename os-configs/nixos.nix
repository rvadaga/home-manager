{ config, pkgs, lib, ... }: {
  llmInstructions.platforms = lib.mkAfter [ "nixos" ];

  home = {
    packages = [
      pkgs.unstable.claude-code
    ];
  };

  programs = {
    zsh = {
      shellAliases = {
        nosc = "cd $HOME/.config/nixos";
      };
    };
  };

  # auto-start krfb (kde vnc server) at login so remote screen sharing is always ready.
  # --nodialog skips the invitation window; unattended access with a pre-set password
  # lives in ~/.config/krfbrc (kwallet-backed, configured once via the gui).
  # reach it from the mac with: ssh -L 5900:localhost:5900 rahulv@<host>
  # then connect macos screen sharing to vnc://localhost
  xdg.configFile."autostart/org.kde.krfb.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Krfb (VNC Server)
    Comment=Auto-start krfb for ssh-tunneled remote access
    Exec=krfb --nodialog
    Icon=krfb
    Terminal=false
    X-KDE-autostart-after=panel
    X-GNOME-Autostart-enabled=true
  '';
}
