{ ... }:
{
  # add the machine identity and module paths to hosts.nix, then keep only
  # machine-specific home-manager overrides here.
  imports = [
    ./host.nix
    ../os-configs/base.nix
    ../os-configs/mac.nix
  ];
}
