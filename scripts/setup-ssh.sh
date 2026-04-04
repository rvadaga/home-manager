#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 SSH key, upload to github, store in 1password
# reads machine name and email from machine.json

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"
load_machine_config

KEYFILE="$HOME/.ssh/id_ed25519"
DATE=$(date +%Y-%m-%d)
TITLE="${MACHINE_NAME} - ${DATE}"

if [ -f "$KEYFILE" ]; then
  echo "SSH key already exists at $KEYFILE"
  echo "delete it first if you want to regenerate"
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "==> generating ed25519 SSH key..."
ssh-keygen -t ed25519 -C "$USER_EMAIL" -f "$KEYFILE" -N ""

GITHUB_OK=false
OP_OK=false

upload_to_github \
  "gh ssh-key add '${KEYFILE}.pub' --title '${TITLE}'" \
  "gh ssh-key add ${KEYFILE}.pub --title \"${TITLE}\"" \
  && GITHUB_OK=true

store_in_1password "SSH key - ${TITLE}" "$(cat "$KEYFILE")" \
  && OP_OK=true

echo ""
echo "SSH key generated:"
echo "  public:  ${KEYFILE}.pub"
echo "  private: ${KEYFILE}"
$GITHUB_OK && echo "  github:  uploaded as '${TITLE}'" || echo "  github:  NOT uploaded (see error above)"
$OP_OK && echo "  1password: stored as 'SSH key - ${TITLE}'" || echo "  1password: NOT stored (see error above)"

mark_step_done "ssh-setup-done"
