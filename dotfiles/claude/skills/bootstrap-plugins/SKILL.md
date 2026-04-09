# /bootstrap-plugins

install and enable plugins declared in `desired-plugins.json`. run this on a fresh machine or whenever you want to sync installed plugins to the desired state.

## steps

1. read `~/.config/home-manager/dotfiles/claude/desired-plugins.json` (source of truth for which plugins should be installed)
2. read `~/.claude/plugins/installed_plugins.json` (may not exist on a fresh machine — treat as empty)
3. read `~/.claude/settings.json` and extract `enabledPlugins` (may not exist — treat as empty `{}`)
4. compare desired vs installed:
   - **missing:** plugins in desired-plugins.json but not in installed_plugins.json → need install
   - **extra:** plugins in installed_plugins.json but not in desired-plugins.json → report but do NOT uninstall (use `/clean-plugins` for that)
   - **installed but wrong enabled state:** plugins that are installed but whose enabled/disabled state in `enabledPlugins` doesn't match desired-plugins.json → need enable/disable
5. present a summary:
   - **to install:** list of plugins that will be installed
   - **to enable:** list of plugins that will be enabled
   - **to disable:** list of plugins that will be disabled
   - **extra (not in desired):** informational only
6. ask the user for confirmation before proceeding
7. for each missing plugin, run: `CLAUDECODE= claude plugin install "<name>@<marketplace>" --scope user`
8. for each plugin needing enable: `CLAUDECODE= claude plugin enable "<name>@<marketplace>"`
9. for each plugin needing disable: `CLAUDECODE= claude plugin disable "<name>@<marketplace>"`
10. after all operations, re-read `installed_plugins.json` and `settings.json` to verify and report final state

## important notes

- this is safe to run repeatedly — it only installs/enables/disables what's needed
- the `CLAUDECODE=` prefix is required to avoid nested-session errors when calling the claude CLI
- plugins are always installed with `--scope user` (not project or local)
- the desired-plugins.json value (`true`/`false`) maps to the enabled state, not whether to install — all listed plugins get installed regardless of their enabled value
- if `installed_plugins.json` doesn't exist, assume nothing is installed
- if `desired-plugins.json` doesn't exist, error and tell the user to check their home-manager config
