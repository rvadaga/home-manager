# bash on small macos pipes

the package backports the [bash maintainer's darwin fix](https://www.mail-archive.com/bug-bash@gnu.org/msg36171.html). bash writes a here-document or here-string before starting its reader. it must use a nonblocking pipe write because macos can reduce a fresh pipe's capacity to 512 bytes. a short write or `EAGAIN` closes both pipe ends and writes the complete document to a temporary file.

the package retains the pinned nixpkgs patches and both upstream configure changes. `HEREDOC_PIPESIZE=16384` fixes the optimization threshold independently of pressure on the build machine. runtime nonblocking writes determine whether a document actually fits. `BASH_COMPAT=5.0` is confined to the build environment so the old build shell can run configure; the installed shell and regression tests use normal compatibility behavior.

`os-configs/mac.nix` selects the package for home-manager's bash, direnv's embedded bash path, and the home profile. its direnv extension keeps the patched bash first after `use flake` or `use nix`, preserving the relative order of other tools. `darwin/bash.nix` gives the same package priority in the system profile. the shared darwin configuration imports that module, and downstream configurations can import `darwinModules.bash`. both profiles need activation before all those entry points change. linux packages are unchanged.

this does not rewrite existing nix store paths, package shebangs, independent project flakes, apple's system shells, or unmanaged shells. direct `nix develop`, an explicit store path, or later custom path edits can still select another bash. `direnv status` identifies the shell evaluating `.envrc`; `command -v bash` inside the loaded environment identifies the shell that a later command will use. inspect both. failures caused by unavailable descriptors or unwritable temporary files remain possible.

## regression test

on a macos host, build the package and compile the child-local syscall fixture:

```sh
nix build .#homeConfigurations.personal-laptop.config.programs.bash.package --out-link /tmp/patched-bash
clang -Wall -Wextra -Werror -dynamiclib scripts/tests/bash-pipe-fixture.c -o /tmp/bash-pipe-fixture.dylib
python3 scripts/test-bash-darwin-pipe-fallback.py \
  --patched /tmp/patched-bash/bin/bash \
  --unpatched "$(nix eval --raw .#homeConfigurations.personal-laptop.pkgs.bash)/bin/bash" \
  --fixture /tmp/bash-pipe-fixture.dylib \
  --evidence /tmp/bash-pipe-test-results
```

the fixture affects only injected test children. it models a 512-byte pipe by accepting at most 512 bytes, returning `EAGAIN`, or holding an oversized blocking write until the test deadline. it neither changes the kernel's pipe limits nor creates global pressure. event records must prove that bash made the intended write; exact output and reader type must then prove that the complete document survived the fallback. oversized blocking controls must time out and are terminated and reaped before the next case; small unpatched writes must still pass. native tests also run without injection.

the byte comparisons include the final newline, embedded newlines and shell punctuation, empty documents, both sides of the 512-byte capacity and 16 kib optimization boundaries, and large temporary-file cases. fault injection also invalidates the owned write descriptor before `F_GETFL`, and persistent shells verify stable descriptor counts through 3,000 redirections per mode. run the built direnv and both configuration builds separately to verify their selected artifacts; passing the shell fixture alone does not prove profile or repository startup behavior.
