#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 SSH key, upload to github, store in 1password
# run once per machine after first darwin-rebuild switch

KEYFILE="$HOME/.ssh/id_ed25519"
EMAIL="rahul.vadaga@gmail.com"
HOSTNAME=$(hostname -s)
DATE=$(date +%Y-%m-%d)
TITLE="${HOSTNAME} - ${DATE}"

if [ -f "$KEYFILE" ]; then
  echo "SSH key already exists at $KEYFILE"
  echo "delete it first if you want to regenerate"
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "==> generating ed25519 SSH key..."
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEYFILE" -N ""

echo "==> uploading public key to github..."
gh ssh-key add "${KEYFILE}.pub" --title "$TITLE"

echo "==> storing private key in 1password..."
op item create \
  --category="Secure Note" \
  --title="SSH key - ${TITLE}" \
  --vault="Private" \
  "notesPlain=$(cat "$KEYFILE")"

echo ""
echo "done. SSH key configured:"
echo "  public:  ${KEYFILE}.pub"
echo "  private: ${KEYFILE}"
echo "  github:  uploaded as '${TITLE}'"
echo "  1password: stored as 'SSH key - ${TITLE}'"
