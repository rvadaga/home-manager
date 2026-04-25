{ lib, ... }: {
  nix.settings = lib.mkMerge [
    (import ../shared/nix-settings.nix)
    { trusted-users = [ "root" "@admin" ]; }
  ];
}
