{ ... }: {
  imports = [
    ./host.nix
    ../os-configs/base.nix
    ../os-configs/linux.nix
    ../os-configs/nixos.nix
  ];
}
