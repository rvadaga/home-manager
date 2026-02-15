# oh-my-zsh git plugin aliases

complete reference of all aliases from the oh-my-zsh git plugin, organized by category.
each entry shows: `alias` = `full git command`

## basics

| alias | full command |
|-------|-------------|
| `g` | `git` |
| `ghh` | `git help` |

## status & info

| alias | full command |
|-------|-------------|
| `gst` | `git status` |
| `gss` | `git status --short` |
| `gsb` | `git status --short --branch` |
| `gcount` | `git shortlog --summary --numbered` |

## add & stage

| alias | full command |
|-------|-------------|
| `ga` | `git add` |
| `gaa` | `git add --all` |
| `gapa` | `git add --patch` |
| `gau` | `git add --update` |
| `gav` | `git add --verbose` |

## commit

| alias | full command |
|-------|-------------|
| `gc` | `git commit --verbose` |
| `gc!` | `git commit --verbose --amend` |
| `gcmsg` | `git commit --message` |
| `gca` | `git commit --verbose --all` |
| `gca!` | `git commit --verbose --all --amend` |
| `gcam` | `git commit --all --message` |
| `gcan!` | `git commit --verbose --all --no-edit --amend` |
| `gcann!` | `git commit --verbose --all --date=now --no-edit --amend` |
| `gcans!` | `git commit --verbose --all --signoff --no-edit --amend` |
| `gcas` | `git commit --all --signoff` |
| `gcasm` | `git commit --all --signoff --message` |
| `gcn` | `git commit --verbose --no-edit` |
| `gcn!` | `git commit --verbose --no-edit --amend` |
| `gcfu` | `git commit --fixup` |
| `gcs` | `git commit --gpg-sign` |
| `gcsm` | `git commit --signoff --message` |
| `gcss` | `git commit --gpg-sign --signoff` |
| `gcssm` | `git commit --gpg-sign --signoff --message` |

## diff

| alias | full command |
|-------|-------------|
| `gd` | `git diff` |
| `gds` | `git diff --staged` |
| `gdca` | `git diff --cached` |
| `gdcw` | `git diff --cached --word-diff` |
| `gdw` | `git diff --word-diff` |
| `gdup` | `git diff @{upstream}` |
| `gdt` | `git diff-tree --no-commit-id --name-only -r` |
| `gdct` | `git describe --tags $(git rev-list --tags --max-count=1)` |

## log

| alias | full command |
|-------|-------------|
| `glog` | `git log --oneline --decorate --graph` |
| `gloga` | `git log --oneline --decorate --graph --all` |
| `glo` | `git log --oneline --decorate` |
| `glol` | `git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset'` |
| `glola` | `git log --graph --pretty='...' --all` |
| `glols` | `git log --graph --pretty='...' --stat` |
| `glod` | `git log --graph --pretty='...' (absolute date)` |
| `glods` | `git log --graph --pretty='...' --date=short` |
| `glg` | `git log --stat` |
| `glgg` | `git log --graph` |
| `glgga` | `git log --graph --decorate --all` |
| `glgm` | `git log --graph --max-count=10` |
| `glgp` | `git log --stat --patch` |
| `gwch` | `git log --patch --abbrev-commit --pretty=medium --raw` |

## branch

| alias | full command |
|-------|-------------|
| `gb` | `git branch` |
| `gba` | `git branch --all` |
| `gbd` | `git branch --delete` |
| `gbD` | `git branch --delete --force` |
| `gbm` | `git branch --move` |
| `gbnm` | `git branch --no-merged` |
| `gbr` | `git branch --remote` |
| `ggsup` | `git branch --set-upstream-to=origin/$(git_current_branch)` |

## checkout & switch

| alias | full command |
|-------|-------------|
| `gco` | `git checkout` |
| `gcb` | `git checkout -b` |
| `gcB` | `git checkout -B` |
| `gcm` | `git checkout $(git_main_branch)` |
| `gcd` | `git checkout $(git_develop_branch)` |
| `gcor` | `git checkout --recurse-submodules` |
| `gsw` | `git switch` |
| `gswc` | `git switch --create` |
| `gswm` | `git switch $(git_main_branch)` |
| `gswd` | `git switch $(git_develop_branch)` |

## fetch

| alias | full command |
|-------|-------------|
| `gf` | `git fetch` |
| `gfo` | `git fetch origin` |
| `gfa` | `git fetch --all --tags --prune --jobs=10` |

## pull

| alias | full command |
|-------|-------------|
| `gl` | `git pull` |
| `ggpull` | `git pull origin "$(git_current_branch)"` |
| `gpr` | `git pull --rebase` |
| `gpra` | `git pull --rebase --autostash` |
| `gprav` | `git pull --rebase --autostash -v` |
| `gprv` | `git pull --rebase -v` |
| `gprom` | `git pull --rebase origin $(git_main_branch)` |
| `gpromi` | `git pull --rebase=interactive origin $(git_main_branch)` |
| `gprum` | `git pull --rebase upstream $(git_main_branch)` |
| `gprumi` | `git pull --rebase=interactive upstream $(git_main_branch)` |
| `gluc` | `git pull upstream $(git_current_branch)` |
| `glum` | `git pull upstream $(git_main_branch)` |

## push

| alias | full command |
|-------|-------------|
| `gp` | `git push` |
| `ggpush` | `git push origin "$(git_current_branch)"` |
| `gpsup` | `git push --set-upstream origin $(git_current_branch)` |
| `gpsupf` | `git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes` |
| `gpf` | `git push --force-with-lease --force-if-includes` |
| `gpf!` | `git push --force` |
| `gpd` | `git push --dry-run` |
| `gpv` | `git push --verbose` |
| `gpu` | `git push upstream` |
| `gpoat` | `git push origin --all && git push origin --tags` |
| `gpod` | `git push origin --delete` |

## rebase

| alias | full command |
|-------|-------------|
| `grb` | `git rebase` |
| `grbm` | `git rebase $(git_main_branch)` |
| `grbd` | `git rebase $(git_develop_branch)` |
| `grbom` | `git rebase origin/$(git_main_branch)` |
| `grbum` | `git rebase upstream/$(git_main_branch)` |
| `grbi` | `git rebase --interactive` |
| `grbo` | `git rebase --onto` |
| `grba` | `git rebase --abort` |
| `grbc` | `git rebase --continue` |
| `grbs` | `git rebase --skip` |

## merge

| alias | full command |
|-------|-------------|
| `gm` | `git merge` |
| `gmff` | `git merge --ff-only` |
| `gms` | `git merge --squash` |
| `gmom` | `git merge origin/$(git_main_branch)` |
| `gmum` | `git merge upstream/$(git_main_branch)` |
| `gma` | `git merge --abort` |
| `gmc` | `git merge --continue` |
| `gmtl` | `git mergetool --no-prompt` |
| `gmtlvim` | `git mergetool --no-prompt --tool=vimdiff` |

## stash

| alias | full command |
|-------|-------------|
| `gsta` | `git stash push` |
| `gstu` | `git stash push --include-untracked` |
| `gstall` | `git stash --all` |
| `gstp` | `git stash pop` |
| `gstaa` | `git stash apply` |
| `gstd` | `git stash drop` |
| `gstl` | `git stash list` |
| `gsts` | `git stash show --patch` |
| `gstc` | `git stash clear` |

## reset & restore

| alias | full command |
|-------|-------------|
| `grh` | `git reset` |
| `grhh` | `git reset --hard` |
| `grhs` | `git reset --soft` |
| `grhk` | `git reset --keep` |
| `groh` | `git reset origin/$(git_current_branch) --hard` |
| `gru` | `git reset --` |
| `grs` | `git restore` |
| `grst` | `git restore --staged` |
| `grss` | `git restore --source` |
| `gpristine` | `git reset --hard && git clean --force -dfx` |

## cherry-pick

| alias | full command |
|-------|-------------|
| `gcp` | `git cherry-pick` |
| `gcpa` | `git cherry-pick --abort` |
| `gcpc` | `git cherry-pick --continue` |

## revert

| alias | full command |
|-------|-------------|
| `grev` | `git revert` |
| `greva` | `git revert --abort` |
| `grevc` | `git revert --continue` |

## remote

| alias | full command |
|-------|-------------|
| `gr` | `git remote` |
| `grv` | `git remote --verbose` |
| `gra` | `git remote add` |
| `grmv` | `git remote rename` |
| `grrm` | `git remote remove` |
| `grset` | `git remote set-url` |
| `grup` | `git remote update` |

## tag

| alias | full command |
|-------|-------------|
| `gta` | `git tag --annotate` |
| `gts` | `git tag --sign` |
| `gtv` | `git tag \| sort -V` |

## show & blame

| alias | full command |
|-------|-------------|
| `gsh` | `git show` |
| `gsps` | `git show --pretty=short --show-signature` |
| `gbl` | `git blame -w` |

## clone

| alias | full command |
|-------|-------------|
| `gcl` | `git clone --recurse-submodules` |
| `gclf` | `git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules` |

## apply & am (patches)

| alias | full command |
|-------|-------------|
| `gap` | `git apply` |
| `gapt` | `git apply --3way` |
| `gam` | `git am` |
| `gama` | `git am --abort` |
| `gamc` | `git am --continue` |
| `gams` | `git am --skip` |
| `gamscp` | `git am --show-current-patch` |

## bisect

| alias | full command |
|-------|-------------|
| `gbs` | `git bisect` |
| `gbss` | `git bisect start` |
| `gbsb` | `git bisect bad` |
| `gbsg` | `git bisect good` |
| `gbsn` | `git bisect new` |
| `gbso` | `git bisect old` |
| `gbsr` | `git bisect reset` |

## submodule

| alias | full command |
|-------|-------------|
| `gsi` | `git submodule init` |
| `gsu` | `git submodule update` |

## worktree

| alias | full command |
|-------|-------------|
| `gwt` | `git worktree` |
| `gwta` | `git worktree add` |
| `gwtls` | `git worktree list` |
| `gwtmv` | `git worktree move` |
| `gwtrm` | `git worktree remove` |

## clean

| alias | full command |
|-------|-------------|
| `gclean` | `git clean --interactive -d` |
| `gwipe` | `git reset --hard && git clean --force -df` |

## config & misc

| alias | full command |
|-------|-------------|
| `gcf` | `git config --list` |
| `gfg` | `git ls-files \| grep` |
| `grf` | `git reflog` |
| `grm` | `git rm` |
| `grmc` | `git rm --cached` |
| `grt` | `cd "$(git rev-parse --show-toplevel \|\| echo .)"` |
| `gignore` | `git update-index --assume-unchanged` |
| `gunignore` | `git update-index --no-assume-unchanged` |

## wip helpers

| alias | full command |
|-------|-------------|
| `gwip` | `git add -A; git rm $(git ls-files --deleted) 2>/dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"` |
| `gunwip` | undo last wip commit (resets HEAD~1 if last message was --wip--) |

## deprecated (use the replacement)

| alias | replacement |
|-------|------------|
| `gup` | `gpr` (git pull --rebase) |
| `gupa` | `gpra` (git pull --rebase --autostash) |
| `gupav` | `gprav` (git pull --rebase --autostash -v) |
| `gupom` | `gprom` (git pull --rebase origin main) |
| `gupomi` | `gpromi` (git pull --rebase=interactive origin main) |
| `gupv` | `gprv` (git pull --rebase -v) |
