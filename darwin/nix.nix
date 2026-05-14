{ config, lib, ... }:
let
  user = config.users.users.${config.system.primaryUser};
in {
  nix.settings = lib.mkMerge [
    (import ../shared/nix-settings.nix)
    { trusted-users = [ "root" "@admin" ]; }
  ];

  # Cover both paths because on multi-user macOS nix-darwin, the user-profile
  # nix (installed via home-manager) shadows the system nix in PATH. `which
  # nix-collect-garbage` resolves to the user-profile path, so a rule matching
  # only /run/current-system/sw/bin would still prompt for password.
  environment.etc."sudoers.d/nix-collect-garbage" = {
    text = ''
      ${user.name} ALL=(root) NOPASSWD: /run/current-system/sw/bin/nix-collect-garbage *
      ${user.name} ALL=(root) NOPASSWD: /nix/var/nix/profiles/default/bin/nix-collect-garbage *
    '';
  };
}
