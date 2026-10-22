#!/bin/bash
set -euo pipefail

if [[ -z "${SUDO_ASKPASS_SESSION:-}" || $# -eq 0 ]]; then
    printf '%s\n' 'usage: SUDO_ASKPASS_SESSION="current session name" sudo-ask [sudo options] command [args...]' >&2
    exit 2
fi

export SUDO_ASKPASS="${SUDO_ASKPASS:-$HOME/.local/libexec/sudo-askpass}"
if [[ ! -x "$SUDO_ASKPASS" ]]; then
    printf '%s\n' 'sudo askpass helper is missing or not executable' >&2
    exit 2
fi

# render and execute the same argv; never reconstruct the command with eval.
sudo_argv=(/usr/bin/sudo -A "$@")
printf -v SUDO_ASKPASS_COMMAND '%q ' "${sudo_argv[@]}"
export SUDO_ASKPASS_COMMAND="${SUDO_ASKPASS_COMMAND% }"
exec "${sudo_argv[@]}"
