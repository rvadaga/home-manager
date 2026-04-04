# avoids drift between darwin/nix.nix (system-level) and os-configs/base.nix (standalone home-manager)
{
  experimental-features = [ "nix-command" "flakes" ];
  download-buffer-size = 128 * 1024 * 1024;
}
