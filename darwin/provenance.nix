# writes flake provenance to /etc/nix-config-provenance at activation time so
# the active system can be traced back to a specific source state (rev +
# content hash). parallel worktrees of this repo all activate into the same
# /run/current-system; without this stamp, "did i rebuild from this worktree?"
# is unanswerable.
#
# inspired by paneherd's Makefile, which embeds ProjectRoot + BuildCommit into
# Info.plist for the same reason. read with the `nix-provenance` zsh helper
# (defined in programs/zsh.nix) or `cat /etc/nix-config-provenance` directly.
#
# requires `specialArgs = { inherit inputs; }` to be set on the darwinSystem
# call. for downstream flakes that import this module, they must do the same.
{ inputs, ... }:
let
  self = inputs.self;
  rev = self.rev or self.dirtyRev or "unknown";
  narHash = self.narHash or "unknown";
  lastModified = self.lastModifiedDate or "unknown";
  storePath = self.outPath;
in {
  environment.etc."nix-config-provenance".text = ''
    rev=${rev}
    narHash=${narHash}
    lastModified=${lastModified}
    storePath=${storePath}
  '';
}
