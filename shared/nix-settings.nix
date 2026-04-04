# shared nix settings used by both darwin/nix.nix (system-level) and
# os-configs/base.nix (standalone home-manager)
{
  experimental-features = [ "nix-command" "flakes" ];
  download-buffer-size = 134217728;  # 128 MB
}
