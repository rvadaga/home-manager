{ config, pkgs, lib, ... }: {
  # claude configuration
  claude.settingsPieces = lib.mkAfter [ (builtins.fromJSON (builtins.readFile ../dotfiles/claude/settings-nixos.json)) ];
  home = {
    file.".codex/AGENTS.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/codex/AGENTS-nixos.md
    );

    file.".claude/CLAUDE.md".text = lib.mkAfter (
      "\n\n" + builtins.readFile ../dotfiles/claude/CLAUDE-nixos.md
    );

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

  # ensure remote keyboard/mouse control is enabled in krfbrc.
  # the file is otherwise imperative (kwallet-backed password, gui-managed),
  # so we patch only the [Security] keys we care about and leave the rest alone.
  # idempotent: re-running adds nothing if the key already has the right value.
  home.activation.krfbDesktopControl = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KRFBRC="$HOME/.config/krfbrc"
    if [ -f "$KRFBRC" ]; then
      if ! ${pkgs.gnugrep}/bin/grep -q '^allowDesktopControl=true$' "$KRFBRC"; then
        # remove any existing allowDesktopControl line, then append a true one
        # under [Security]. uses awk for an in-place section-aware insert.
        ${pkgs.gawk}/bin/awk '
          BEGIN { added = 0; in_security = 0 }
          /^\[Security\]/ { in_security = 1; print; next }
          /^\[/ && in_security {
            if (!added) { print "allowDesktopControl=true"; added = 1 }
            in_security = 0; print; next
          }
          /^allowDesktopControl=/ { next }
          { print }
          END { if (in_security && !added) print "allowDesktopControl=true" }
        ' "$KRFBRC" > "$KRFBRC.tmp" && mv "$KRFBRC.tmp" "$KRFBRC"
        echo "krfbrc: enabled allowDesktopControl"
      fi
    fi
  '';
}
