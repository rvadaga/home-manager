# home-manager workflow

this is the personal config repository that contains shared modules used by multiple configurations.

## repository structure

- `profiles/base.nix` - base profile with core packages and settings
- `profiles/mac.nix` - macos-specific configuration
- `profiles/linux.nix` - linux-specific configuration
- `modules/` - individual feature modules (neovim, zsh, fzf, etc.)

## exported modules

this flake exports modules that can be imported by other flakes:

```nix
homeManagerModules = {
  base = ./profiles/base.nix;
  mac = ./profiles/mac.nix;
  linux = ./profiles/linux.nix;
};
```

## workflow for updating shared config

when you make changes to shared modules (base.nix, modules/*, etc.):

1. make changes in this repo
2. commit and push to main
3. other flakes that import this config can update their lock file:
   ```bash
   nix flake update personal-config
   home-manager switch --flake ".#<config-name>"
   ```
