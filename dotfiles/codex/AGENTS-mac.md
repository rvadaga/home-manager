# macos-specific instructions

* when using coreutils commands, prefer g-prefixed gnu versions (e.g. `gls`, `gstat`)
* use macos-native tools where appropriate (e.g. `pbcopy`, `pbpaste`)

## nix-darwin rebuild

macos machines use nix-darwin, not home-manager. the rebuild command is:

```bash
darwin-rebuild switch --flake <flake-path>#$HM_CONFIG_NAME
```

* for personal mac: `darwin-rebuild switch --flake ~/.config/home-manager#$HM_CONFIG_NAME`
* for work mac: use the work flake path (see work-specific instructions)
