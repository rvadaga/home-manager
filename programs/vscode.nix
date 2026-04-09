{ config, pkgs, ... }: {
  programs.vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    profiles.default.userSettings = {
      "editor.fontFamily" = "FiraMono Nerd Font Mono, FiraCode Nerd Font Mono";
    };
    profiles.default.keybindings = [
      # terminal control sequences (physical ctrl → super after keyd)
      { key = "meta+c"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0003"; }; when = "terminalFocus"; }
      { key = "meta+d"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0004"; }; when = "terminalFocus"; }
      { key = "meta+u"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0015"; }; when = "terminalFocus"; }
      { key = "meta+w"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0017"; }; when = "terminalFocus"; }
      { key = "meta+a"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0001"; }; when = "terminalFocus"; }
      { key = "meta+e"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0005"; }; when = "terminalFocus"; }
      { key = "meta+k"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u000b"; }; when = "terminalFocus"; }
      { key = "meta+r"; command = "workbench.action.terminal.sendSequence"; args = { text = "\\u0012"; }; when = "terminalFocus"; }
    ];
  };
}
