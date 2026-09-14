#!/usr/bin/env bash
set -euo pipefail

extension=$1
patched_bin=$2
direnv=$3
eval "$("$direnv" stdlib)"

use_flake() {
  observed=("$@")
  PATH="/project/bin:$PATH"
  return 0
}
use_nix() {
  observed=("$@")
  return 23
}

source "$extension"
source "$extension"

PATH=/usr/bin:/bin
use_flake 'path with spaces' --impure
[[ ${observed[0]} == 'path with spaces' && ${observed[1]} == --impure ]]
[[ $PATH == "$patched_bin:/project/bin:/usr/bin:/bin" ]]

before=$PATH
if use_nix --keep 'value with spaces'; then
  exit 1
else
  [[ $? == 23 ]]
fi
[[ $PATH == "$before" ]]
[[ ${observed[0]} == --keep && ${observed[1]} == 'value with spaces' ]]

_patched_bash_use_nix() {
  PATH="/another/bin:$PATH"
}
use_nix
[[ $PATH == "$patched_bin:/another/bin:/project/bin:/usr/bin:/bin" ]]

_patched_bash_use_flake() {
  return 19
}
if use_flake; then
  exit 1
else
  [[ $? == 19 ]]
fi
[[ $PATH == "$patched_bin:/another/bin:/project/bin:/usr/bin:/bin" ]]

for loader in use_flake use_nix; do
  for mode in original wrapped; do
    set +e
    output=$("$BASH" -eu -c '
      use_flake() { false; printf "must not run\n"; }
      use_nix() { false; printf "must not run\n"; }
      if [[ $3 == wrapped ]]; then source "$1"; fi
      "$2"
      printf "must not continue\n"
    ' test "$extension" "$loader" "$mode")
    result=$?
    set -e
    [[ $result == 1 && -z $output ]]
  done
done

printf 'loader arguments, failure status, errexit, path order, duplicate removal, and repeated sourcing passed\n'
