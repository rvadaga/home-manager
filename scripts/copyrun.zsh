# Capture text output without changing the command's arguments or exit status.
function copyrun {
  emulate -L zsh
  unsetopt err_exit err_return

  if (( $# == 0 )); then
    print -u2 'usage: copyrun command [args...]'
    return 2
  fi

  local transcript
  local -a results
  transcript=$(mktemp "${TMPDIR:-/tmp}/copyrun.XXXXXXXX") || return 1
  {
    {
      printf '❯'
      printf ' %q' "$@"
      printf '\n'
      "$@" 2>&1
    } | command tee "$transcript"
    results=( "${pipestatus[@]}" )

    if (( results[2] != 0 )); then
      print -u2 'copyrun: could not capture the complete transcript; clipboard unchanged'
    elif ! (( $+functions[clipcopy] || $+commands[clipcopy] )); then
      print -u2 'copyrun: clipcopy is unavailable; transcript was not copied'
    elif ! clipcopy < "$transcript"; then
      print -u2 'copyrun: clipboard copy failed'
    fi
  } always {
    command rm -f -- "$transcript"
  }
  return "${results[1]}"
}

# A trailing space expands the following command alias before calling copyrun.
alias copyrun='copyrun '
