{ config, pkgs, lib, ... }: {
  home.packages = [
    pkgs.unstable.claude-code
  ];
}
