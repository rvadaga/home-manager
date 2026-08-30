# macos bootstrap — todo

## completed

- [x] add nix-darwin flake input (nix-darwin/nix-darwin, 25.11 branch)
- [x] extract overlays into shared `mkOverlays` / `mkPkgs` helpers
- [x] add `darwinConfigurations.mac-workstation` output
- [x] add `homeConfigurations.mac-workstation` output
- [x] add reusable `darwinModules` exports for downstream configs
- [x] create `darwin/common.nix` — umbrella for the complete personal macos system
- [x] create `darwin/nix.nix` — system-level nix settings
- [x] create `darwin/apps.nix` and `darwin/app-registry.nix` — declarative app lifecycle
- [x] create `darwin/homebrew.nix` — homebrew activation policy
- [x] create `darwin/system-defaults.nix` — dock, finder, NSGlobalDomain, trackpad, keyboard
- [x] guard `nix` block and `programs.home-manager.enable` in base.nix with `osConfig ? null`
- [x] add gpg-agent.conf and programs.ssh to mac.nix
- [x] create `machines/mac-workstation.nix`
- [x] create `bootstrap.sh` — xcode CLT, determinate nix, homebrew, gh auth, clone, first darwin-rebuild
- [x] create `scripts/setup-ssh.sh` — generate key, upload to github, store in 1password
- [x] create `scripts/setup-gpg.sh` — generate key, upload to github, store in 1password
- [x] generate app-license setup from `darwin/app-registry.nix`
- [x] verify all three configs build (`personal-laptop`, `mac-workstation` HM, `mac-workstation` darwin)
- [x] apply config: `darwin-rebuild switch --flake .#mac-workstation`
- [x] verify homebrew casks install correctly
- [x] run `setup-ssh.sh` and `setup-gpg.sh` on first machine
- [x] set the gpg signing key in `machines/hosts.nix`
- [x] apply generated app licenses after 1password sign-in
- [x] add `machine.json` for per-machine identity (replaces script args)
- [x] dedupe shell scripts — shared helpers in `functions.sh`
- [x] add `.state/` sentinel files for idempotent bootstrap
- [x] nix garbage collect (freed 4.3 GB)

## pending

- [ ] fix masApps — `brew bundle` calls `mas get` which doesn't exist in mas 2.x; blocked on homebrew-bundle upstream fix. monosnap (540348655) must be installed manually for now
- [ ] consider adding apple account sign-in to bootstrap prerequisites — needed for app store installs (mas) and possibly xcode CLT
- [ ] verify system.defaults apply (dock, finder, trackpad, etc.) — need to check in a new terminal session
- [ ] verify gpg-agent.conf and ssh config land in the right places
- [ ] tune system.defaults to personal preferences (current values are sensible defaults)
- [ ] gitignore `machine.json` once downstream configs are set up
- [ ] decide whether to remove `homeConfigurations.personal-laptop` once fully on nix-darwin
- [ ] update notion pages with final implementation details
