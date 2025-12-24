{ config, pkgs, ... }:
let
  # where `npm i -g ...` will install user-global packages.
  npmPrefix = "${config.home.homeDirectory}/.npm-global";
in
{
  # npm honors this env var (equivalent to `npm config set prefix ...`).
  home.sessionVariables.NPM_CONFIG_PREFIX = npmPrefix;

  # ensure user-global npm binaries are on PATH.
  home.sessionPath = [
    "${npmPrefix}/bin"
  ];

  # optional, but handy: write ~/.npmrc so this works even outside HM-managed shells.
  home.file.".npmrc".text = ''
    prefix=${npmPrefix}
  '';

  # if you don't already install node via Nix/Home Manager, add this somewhere:
  # home.packages = [ pkgs.nodejs ];
}
