# nixos-specific instructions

* prefer declarative nix configuration over imperative system modifications
* when suggesting package installations, use nix expressions
* the nixos system config flake is at `~/.config/nixos`, which imports this home-manager repo as a flake input called `home-config`
* if only the nixos config changed (no home-manager changes), rebuild normally using the locked git input:
    ```bash
    sudo nixos-rebuild switch --flake ~/.config/nixos
    ```
* if home-manager config also changed and needs testing, use `--override-input` to point at the local path:
    ```bash
    sudo nixos-rebuild switch --flake ~/.config/nixos --override-input home-config path:$HOME/.config/home-manager
    ```
  once confirmed, commit and push the home-manager changes, then update the lock in the nixos config:
    ```bash
    cd ~/.config/nixos && nix flake update home-config
    ```
* no need to run `home-manager switch` separately - nixos-rebuild handles it
