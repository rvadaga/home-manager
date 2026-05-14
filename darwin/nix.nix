{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  nix.settings = lib.mkMerge [
    (import ../shared/nix-settings.nix)
    { trusted-users = [ "root" "@admin" ]; }
  ];

  environment.etc."sudoers.d/nix-collect-garbage" = {
    text = ''
      ${user.name} ALL=(root) NOPASSWD: /run/current-system/sw/bin/nix-collect-garbage *
    '';
  };
}
