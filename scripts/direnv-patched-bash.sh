# nix environments can prepend a bash from an independent package pin.
if ! declare -F _patched_bash_use_flake >/dev/null; then
  for _patched_bash_loader in use_flake use_nix; do
    _patched_bash_definition=$(declare -f "$_patched_bash_loader") || return
    eval "${_patched_bash_definition/#$_patched_bash_loader /_patched_bash_$_patched_bash_loader }"
  done
  unset _patched_bash_loader _patched_bash_definition

  use_flake() {
    _patched_bash_use_flake "$@"
    local result=$?
    if (( result != 0 )); then
      return "$result"
    fi
    PATH_rm '@patched_bash_bin@'
    PATH_add '@patched_bash_bin@'
  }

  use_nix() {
    _patched_bash_use_nix "$@"
    local result=$?
    if (( result != 0 )); then
      return "$result"
    fi
    PATH_rm '@patched_bash_bin@'
    PATH_add '@patched_bash_bin@'
  }
fi
