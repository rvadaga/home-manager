{ ... }: {
  imports = [ ./common.nix ];

  system.primaryUser = "rvadaga";

  users.users.rvadaga = {
    name = "rvadaga";
    home = "/Users/rvadaga";
  };

  # laptop-specific dock — hard override of the shared list in system-defaults.nix.
  # includes creative and jvm-ide apps that the workstation doesn't need.
  system.defaults.dock.persistent-apps = [
    "/System/Applications/Apps.app"
    "/Applications/Google Chrome.app"
    "/Applications/Spotify.app"
    "/System/Applications/Music.app"
    "/Applications/Claude.app"
    "/Applications/ChatGPT.app"
    "/System/Applications/Mail.app"
    "/System/Applications/Calendar.app"
    "/System/Applications/Reminders.app"
    "/Applications/Notion.app"
    "/Applications/Obsidian.app"
    "/Applications/1Password.app"
    "/Applications/Adobe Lightroom CC/Adobe Lightroom.app"
    "/Applications/Adobe Photoshop 2026/Adobe Photoshop 2026.app"
    "/Applications/Ghostty.app"
    "/Applications/IntelliJ IDEA CE.app"
    "/Applications/Visual Studio Code.app"
    "/System/Applications/FaceTime.app"
    "/System/Applications/Messages.app"
    "/System/Applications/FindMy.app"
    "/System/Applications/iPhone Mirroring.app"
    "/System/Applications/Utilities/Screen Sharing.app"
    "/System/Applications/System Settings.app"
  ];
}
