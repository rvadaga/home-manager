{ lib, ... }: {
  nix.settings = lib.mkDefault (import ../shared/nix-settings.nix);
}
