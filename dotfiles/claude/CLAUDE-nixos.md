# nixos-specific instructions

* prefer declarative nix configuration over imperative system modifications
* when suggesting package installations, use nix expressions
* remember that system configuration or home-manager changes only require nixos-rebuild (system configuration imports home-manager config as a flake)
    * no need to run home-manager switch --flake as such
