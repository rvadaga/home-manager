{ lib, ... }: {
  nix.settings = lib.mkMerge [
    (lib.mkDefault (import ../shared/nix-settings.nix))
    # trusted-users lets admin-group users set restricted nix settings
    # (e.g. download-buffer-size from shared/nix-settings.nix) without the
    # "not a trusted user" warning on `sudo darwin-rebuild` invocations.
    { trusted-users = [ "root" "@admin" ]; }
  ];
}
