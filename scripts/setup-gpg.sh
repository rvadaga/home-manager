#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 GPG key, upload to github, store in 1password
# reads machine name, user name, and email from machine.json

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/functions.sh"
load_machine_config

DATE=$(date +%Y-%m-%d)
TITLE="${MACHINE_NAME} - ${DATE}"

# check if a signing key already exists for this email
EXISTING_KEY=$(gpg --list-secret-keys --keyid-format long "$USER_EMAIL" 2>/dev/null | grep -oE '[A-F0-9]{40}' | head -1 || true)
if [ -n "$EXISTING_KEY" ]; then
  echo "GPG signing key already exists for ${USER_EMAIL}: ${EXISTING_KEY}"
  echo "delete it first if you want to regenerate: gpg --delete-secret-and-public-key ${EXISTING_KEY}"
  exit 1
fi

echo "==> generating ed25519 GPG key..."
GPG_OUTPUT=$(gpg --batch --gen-key 2>&1 <<GPGEOF
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Name-Real: ${USER_NAME}
Name-Email: ${USER_EMAIL}
Expire-Date: 2y
%no-protection
%commit
GPGEOF
)

KEYID=$(echo "$GPG_OUTPUT" | grep -oE '[A-F0-9]{40}' | head -1)

if [ -z "$KEYID" ]; then
  echo "failed to extract key ID from gpg output:"
  echo "$GPG_OUTPUT"
  exit 1
fi

echo "==> generated key: $KEYID"

GITHUB_OK=false
OP_OK=false

upload_to_github \
  "gpg --armor --export '$KEYID' | gh gpg-key add -" \
  "gpg --armor --export $KEYID | gh gpg-key add -" \
  && GITHUB_OK=true

store_in_1password "GPG key - ${TITLE}" "$(gpg --armor --export-secret-keys "$KEYID")" \
  && OP_OK=true

echo ""
echo "GPG key generated:"
echo "  key ID:    ${KEYID}"
$GITHUB_OK && echo "  github:  uploaded" || echo "  github:  NOT uploaded (see error above)"
$OP_OK && echo "  1password: stored as 'GPG key - ${TITLE}'" || echo "  1password: NOT stored (see error above)"
echo ""
echo "next: set this in your machine config's git signing:"
echo "  signing.key = \"${KEYID}\";"

mark_step_done "gpg-setup-done"
