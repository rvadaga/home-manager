# macos bootstrap — todo

## completed

- [x] add nix-darwin flake input (nix-darwin/nix-darwin, 25.11 branch)
- [x] extract overlays into shared `mkOverlays` / `mkPkgs` helpers
- [x] add `darwinConfigurations.mac-workstation` output
- [x] add `homeConfigurations.mac-workstation` output
- [x] add `darwinModules` export (base, desktop, homebrew) for downstream configs
- [x] create `darwin/default.nix` — umbrella: stateVersion, primaryUser, touch ID sudo
- [x] create `darwin/nix.nix` — system-level nix settings
- [x] create `darwin/homebrew.nix` — casks (spotify, chrome, ghostty, bettermouse, bettertouchtool, 1password), masApps (monosnap), brew off PATH
- [x] create `darwin/system-defaults.nix` — dock, finder, NSGlobalDomain, trackpad, keyboard
- [x] guard `nix` block and `programs.home-manager.enable` in base.nix with `osConfig ? null`
- [x] add gpg-agent.conf and programs.ssh to mac.nix
- [x] create `machines/mac-workstation.nix`
- [x] create `bootstrap.sh` — xcode CLT, determinate nix, homebrew, clone, first darwin-rebuild
- [x] create `scripts/setup-ssh.sh` — generate key, upload to github, store in 1password
- [x] create `scripts/setup-gpg.sh` — generate key, upload to github, store in 1password
- [x] create `scripts/setup-licenses.sh` — fetch licenses from 1password
- [x] verify all three configs build (`personal-laptop`, `mac-workstation` HM, `mac-workstation` darwin)
- [x] nix garbage collect (freed 4.3 GB)

## pending

- [ ] `gh auth login` — needed to push (HTTPS remote, no SSH keys)
- [ ] push branch `rahul/macos-bootstrap` to remote
- [ ] apply config: `darwin-rebuild switch --flake .#mac-workstation` (separate plan)
- [ ] verify homebrew casks install correctly
- [ ] verify system.defaults apply (dock, finder, trackpad, etc.)
- [ ] verify gpg-agent.conf and ssh config land in the right places
- [ ] run `setup-ssh.sh` and `setup-gpg.sh` on first machine
- [ ] set GPG signing key in `machines/mac-workstation.nix` after key generation
- [ ] run `setup-licenses.sh` after 1password sign-in
- [ ] verify monosnap app store ID (540348655) is correct
- [ ] update notion pages with final implementation details
- [ ] tune system.defaults to personal preferences (current values are sensible defaults)
- [ ] decide whether to remove `homeConfigurations.personal-laptop` once fully on nix-darwin
