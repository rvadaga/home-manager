# nixos-specific instructions

* prefer declarative nix configuration over imperative system modifications
* when suggesting package installations, use nix expressions
* the nixos system config flake is at `~/.config/nixos`, which imports this home-manager repo as a flake input called `home-config`
* to apply home-manager changes, use nixos-rebuild with `--override-input` to pick up local changes:
    ```bash
    sudo nixos-rebuild switch --flake ~/.config/nixos --override-input home-config path:$HOME/.config/home-manager
    ```
* no need to run `home-manager switch` separately - nixos-rebuild handles it
