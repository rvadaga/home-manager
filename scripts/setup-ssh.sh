#!/usr/bin/env bash
set -euo pipefail

# generate a fresh ed25519 SSH key, upload to github, store in 1password
# usage: setup-ssh.sh <name> <email>
# example: setup-ssh.sh "personal macbook" "rahul.vadaga@gmail.com"

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "usage: setup-ssh.sh <name> <email>"
  echo "example: setup-ssh.sh \"personal macbook\" \"rahul.vadaga@gmail.com\""
  exit 1
fi

KEYFILE="$HOME/.ssh/id_ed25519"
LABEL="$1"
EMAIL="$2"
DATE=$(date +%Y-%m-%d)
TITLE="${LABEL} - ${DATE}"

if [ -f "$KEYFILE" ]; then
  echo "SSH key already exists at $KEYFILE"
  echo "delete it first if you want to regenerate"
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

echo "==> generating ed25519 SSH key..."
ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEYFILE" -N ""

GITHUB_OK=false
OP_OK=false

echo "==> uploading public key to github..."
if gh ssh-key add "${KEYFILE}.pub" --title "$TITLE"; then
  GITHUB_OK=true
else
  echo "  failed — fix the issue and re-run:"
  echo "    gh ssh-key add ${KEYFILE}.pub --title \"${TITLE}\""
fi

echo "==> storing private key in 1password..."
if op item create \
  --category="Secure Note" \
  --title="SSH key - ${TITLE}" \
  --vault="Private" \
  "notesPlain=$(cat "$KEYFILE")"; then
  OP_OK=true
else
  echo "  failed — fix the issue and re-run the op command manually"
fi

echo ""
echo "SSH key generated:"
echo "  public:  ${KEYFILE}.pub"
echo "  private: ${KEYFILE}"
$GITHUB_OK && echo "  github:  uploaded as '${TITLE}'" || echo "  github:  NOT uploaded (see error above)"
$OP_OK && echo "  1password: stored as 'SSH key - ${TITLE}'" || echo "  1password: NOT stored (see error above)"
