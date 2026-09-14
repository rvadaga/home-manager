{ pkgs, lib, ... }:
let
  patchedBash = pkgs.callPackage ../packages/bash-darwin-pipe-fallback.nix { };
in
{
  environment.systemPackages = [ (lib.hiPrio patchedBash) ];
}
