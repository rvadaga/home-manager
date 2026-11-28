{ ... }:
{
  imports = [
    ./host.nix
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];

  xdg.configFile."rex/init.lua".source = ../dotfiles/rex/init.lua;
}
