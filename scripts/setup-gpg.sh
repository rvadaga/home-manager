#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 GPG key, upload to github, store in 1password
# usage: setup-gpg.sh <name> <email>
# example: setup-gpg.sh "personal macbook" "rahul.vadaga@gmail.com"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "usage: setup-gpg.sh <name> <email>"
  echo "example: setup-gpg.sh \"personal macbook\" \"rahul.vadaga@gmail.com\""
  exit 1
fi

NAME="Rahul Vadaga"
LABEL="$1"
EMAIL="$2"
DATE=$(date +%Y-%m-%d)
TITLE="${LABEL} - ${DATE}"

echo "==> generating ed25519 GPG key..."
GPG_OUTPUT=$(gpg --batch --gen-key 2>&1 <<GPGEOF
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Name-Real: ${NAME}
Name-Email: ${EMAIL}
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

echo "==> uploading public key to github..."
if gpg --armor --export "$KEYID" | gh gpg-key add -; then
  GITHUB_OK=true
else
  echo "  failed — fix the issue and re-run:"
  echo "    gpg --armor --export $KEYID | gh gpg-key add -"
fi

echo "==> storing private key in 1password..."
if op item create \
  --category="Secure Note" \
  --title="GPG key - ${TITLE}" \
  --vault="Private" \
  "notesPlain=$(gpg --armor --export-secret-keys "$KEYID")"; then
  OP_OK=true
else
  echo "  failed — fix the issue and re-run the op command manually"
fi

echo ""
echo "GPG key generated:"
echo "  key ID:    ${KEYID}"
$GITHUB_OK && echo "  github:  uploaded" || echo "  github:  NOT uploaded (see error above)"
$OP_OK && echo "  1password: stored as 'GPG key - ${TITLE}'" || echo "  1password: NOT stored (see error above)"
echo ""
echo "next: set this in your machine config's git signing:"
echo "  signing.key = \"${KEYID}\";"
