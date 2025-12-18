{ config, pkgs, lib, ... }: {
  imports = [
    ../programs/kitty.nix
  ];

  home = {
    packages = [
      pkgs.unstable.coreutils-full
      # g-prefixed symlinks for gnu coreutils (avoids collision with coreutils-prefixed)
      (pkgs.runCommand "coreutils-gprefixed" {} ''
        mkdir -p $out/bin
        for cmd in ${pkgs.unstable.coreutils-full}/bin/*; do
          name=$(basename "$cmd")
          ln -s "$cmd" "$out/bin/g$name"
        done
      '')
      pkgs.pinentry_mac
    ];
  };
}
