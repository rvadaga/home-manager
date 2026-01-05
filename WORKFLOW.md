# home-manager workflow

this is the personal config repository that contains shared modules used by multiple configurations.

## repository structure

- `os-configs/base.nix` - base profile with core packages and settings
- `os-configs/mac.nix` - macos-specific configuration
- `os-configs/linux.nix` - linux-specific configuration
- `os-configs/nixos.nix` - nixos-specific configuration
- `programs/` - individual feature modules (neovim, zsh, fzf, etc.)
- `dotfiles/` - managed dotfiles (claude settings split by environment)

## exported modules

this flake exports modules that can be imported by other flakes:

```nix
homeManagerModules = {
  base = ./os-configs/base.nix;
  mac = ./os-configs/mac.nix;
  linux = ./os-configs/linux.nix;
  nixos = ./os-configs/nixos.nix;
};
```

## multiple package channels

the flake provides platform-aware nixpkgs channels:

- stable channels auto-select based on platform (darwin-stable or nixos-stable)
- unstable channels auto-select based on platform (darwin-unstable or nixos-unstable)
- staging channels are unified across platforms

access via overlays:
```nix
pkgs.foo           # stable
pkgs.unstable.bar  # unstable
pkgs.staging.baz   # staging
pkgs.staging-next.qux  # staging-next
```

## HM_CONFIG_NAME environment variable

each machine config sets `HM_CONFIG_NAME` to identify itself:

```nix
home.sessionVariables = {
  HM_CONFIG_NAME = "personal-laptop";
};
```

this allows scripts to use `home-manager switch --flake ".#$HM_CONFIG_NAME"` without hardcoding config names.

## workflow for updating shared config

when you make changes to shared modules (base.nix, programs/*, etc.):

1. make changes in this repo
2. commit and push to main
3. other flakes that import this config can update their lock file:
   ```bash
   nix flake update personal-config
   home-manager switch --flake ".#$HM_CONFIG_NAME"
   ```

## claude settings infrastructure

claude settings are managed via split configuration files in `dotfiles/claude/`:

- `settings-base.json` - shared settings across all environments
- `settings-{os}.json` - os-specific settings (mac, linux, nixos)
- `settings.local-base.json` - shared local settings (permissions)
- `settings.local-{os}.json` - os-specific local settings
- `CLAUDE-base.md` - shared instructions
- `CLAUDE-{os}.md` - os-specific instructions

files are merged during home-manager build (base → os-specific).

to update settings:
1. edit the appropriate source file in `dotfiles/claude/`
2. run `home-manager switch --flake ".#$HM_CONFIG_NAME"`
3. verify changes in `~/.claude/settings.json`
