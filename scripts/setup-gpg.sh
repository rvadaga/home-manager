#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 GPG key, upload to github, store in 1password
# run once per machine after first darwin-rebuild switch

NAME="Rahul Vadaga"
EMAIL="rahul.vadaga@gmail.com"
HOSTNAME=$(hostname -s)
DATE=$(date +%Y-%m-%d)
TITLE="${HOSTNAME} - ${DATE}"

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

echo "==> uploading public key to github..."
gpg --armor --export "$KEYID" | gh gpg-key add -

echo "==> storing private key in 1password..."
op item create \
  --category="Secure Note" \
  --title="GPG key - ${TITLE}" \
  --vault="Private" \
  "notesPlain=$(gpg --armor --export-secret-keys "$KEYID")"

echo ""
echo "done. GPG key configured:"
echo "  key ID:    ${KEYID}"
echo "  github:    uploaded"
echo "  1password: stored as 'GPG key - ${TITLE}'"
echo ""
echo "next: set this in your machine config's git signing:"
echo "  signing.key = \"${KEYID}\";"
