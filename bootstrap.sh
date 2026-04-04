#!/usr/bin/env bash
set -euo pipefail

# full macOS bootstrap — from a fresh mac to a fully configured machine
# prerequisites: internet connection, signed into apple account in system settings (for xcode CLT and app store apps)

CONFIG_DIR="$HOME/.config/home-manager"
CONFIG_REPO="https://github.com/rvadaga/home-manager.git"

echo "=== macOS bootstrap ==="
echo ""

# --- phase 1: install toolchain ---

if ! xcode-select -p &>/dev/null; then
  echo "==> installing xcode command line tools..."
  xcode-select --install
  echo ""
  echo "    waiting for xcode CLT installation to complete."
  echo "    press enter when done."
  read -r
else
  echo "==> xcode command line tools: already installed"
fi

if ! command -v nix &>/dev/null; then
  echo "==> installing nix (determinate systems)..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install
else
  echo "==> nix: already installed"
fi

# ensure nix is on PATH in this shell session
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

if [ ! -x /opt/homebrew/bin/brew ]; then
  echo "==> installing homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "==> homebrew: already installed"
fi

# --- phase 2: user actions needed before automation can continue ---

if ! gh auth status &>/dev/null; then
  echo "==> authenticating github CLI..."
  gh auth login -p https -w -s admin:public_key,write:gpg_key
else
  echo "==> github CLI: already authenticated"
fi

if [ ! -d "$CONFIG_DIR" ]; then
  echo "==> cloning config repo..."
  mkdir -p "$(dirname "$CONFIG_DIR")"
  git clone "$CONFIG_REPO" "$CONFIG_DIR"
else
  echo "==> config repo: already exists at $CONFIG_DIR"
fi

# create machine.json if it doesn't exist
MACHINE_JSON="${CONFIG_DIR}/machine.json"
if [ ! -f "$MACHINE_JSON" ]; then
  echo ""
  echo "==> creating machine.json (per-machine identity used by setup scripts)"
  read -rp "    machine name (e.g. 'work macbook'): " machine_name
  read -rp "    full name (for git commits): " full_name
  read -rp "    email: " email
  cat > "$MACHINE_JSON" <<JSONEOF
{
  "machine": "${machine_name}",
  "name": "${full_name}",
  "email": "${email}"
}
JSONEOF
  echo "    wrote $MACHINE_JSON"
else
  echo "==> machine.json: already exists"
fi

# source shared helpers now that the repo exists
export HM_CONFIG_DIR="$CONFIG_DIR"
source "${CONFIG_DIR}/scripts/functions.sh"
STATE_DIR="$(_state_dir)"
mkdir -p "$STATE_DIR"

echo "==> preparing system files for nix-darwin..."
for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
  if [ -f "$f" ] && [ ! -f "${f}.before-nix-darwin" ]; then
    echo "    renaming $f -> ${f}.before-nix-darwin"
    sudo mv "$f" "${f}.before-nix-darwin"
  fi
done

echo "==> running darwin-rebuild switch..."
if command -v darwin-rebuild &>/dev/null; then
  darwin-rebuild switch --flake "${CONFIG_DIR}#mac-workstation"
else
  echo "    (first run — bootstrapping nix-darwin, this will take a while)"
  nix --extra-experimental-features "nix-command flakes" \
    run nix-darwin -- switch --flake "${CONFIG_DIR}#mac-workstation"
fi

# --- phase 3: setup scripts (need 1password) ---

SETUP_NEEDED=false
if [ ! -f "${STATE_DIR}/ssh-setup-done" ] || [ ! -f "${STATE_DIR}/gpg-setup-done" ] || [ ! -f "${STATE_DIR}/licenses-setup-done" ]; then
  SETUP_NEEDED=true
fi

if [ "$SETUP_NEEDED" = true ]; then
  echo ""
  echo "==> setup scripts need 1Password. open the 1Password app and sign in now."
  echo "    press enter when signed in..."
  read -r

  if [ ! -f "${STATE_DIR}/ssh-setup-done" ]; then
    echo "==> running setup-ssh.sh..."
    "${CONFIG_DIR}/scripts/setup-ssh.sh"
  fi

  if [ ! -f "${STATE_DIR}/gpg-setup-done" ]; then
    echo "==> running setup-gpg.sh..."
    "${CONFIG_DIR}/scripts/setup-gpg.sh"
  fi

  if [ ! -f "${STATE_DIR}/licenses-setup-done" ]; then
    echo "==> running setup-licenses.sh..."
    "${CONFIG_DIR}/scripts/setup-licenses.sh"
  fi
fi

echo ""
echo "=== bootstrap complete ==="

# --- remaining manual steps ---
NEXT_STEPS=()

# gpg key needs to be added to nix config and rebuilt
if [ ! -f "${STATE_DIR}/gpg-config-done" ]; then
  NEXT_STEPS+=("update machines/mac-workstation.nix with the GPG key ID printed above")
  NEXT_STEPS+=("  → run: darwin-rebuild switch --flake ${CONFIG_DIR}#mac-workstation")
fi

# google account apps — chrome first (signs into google), then drive (syncs backup configs)
NEXT_STEPS+=("")
NEXT_STEPS+=("sign in: Google Chrome (google account — syncs bookmarks, extensions, passwords)")
NEXT_STEPS+=("sign in: Google Drive (same google account — syncs BTT/BetterMouse config backups)")

# apps with accounts (independent, any order)
NEXT_STEPS+=("")
NEXT_STEPS+=("sign in: Claude (anthropic account)")
NEXT_STEPS+=("sign in: ChatGPT (openai account)")
NEXT_STEPS+=("sign in: Notion")
NEXT_STEPS+=("sign in: Obsidian (obsidian sync account, if using sync)")
NEXT_STEPS+=("sign in: Spotify")
NEXT_STEPS+=("sign in: WhatsApp (scan QR code from phone)")
NEXT_STEPS+=("sign in: Docker Desktop (docker hub account — optional)")
NEXT_STEPS+=("sign in: VS Code (github account for settings sync)")

# grant permissions (macos will prompt on first launch)
NEXT_STEPS+=("")
NEXT_STEPS+=("grant permissions when prompted:")
NEXT_STEPS+=("  → Itsycal: calendar access")
NEXT_STEPS+=("  → MeetingBar: calendar access")
NEXT_STEPS+=("  → Ice: accessibility access")
NEXT_STEPS+=("  → BetterTouchTool: accessibility access")
NEXT_STEPS+=("  → BetterMouse: accessibility access")

# restore configs from google drive (after gdrive sync completes)
NEXT_STEPS+=("")
NEXT_STEPS+=("after google drive finishes syncing:")
NEXT_STEPS+=("  → quit BetterTouchTool, then: rsync -a \"\$GDRIVE/bettertouchtool/\" ~/Library/Application\\ Support/BetterTouchTool/")
NEXT_STEPS+=("  → quit BetterMouse, then: rsync -a \"\$GDRIVE/bettermouse/\" ~/Library/Application\\ Support/BetterMouse/")

echo ""
echo "remaining steps:"
n=0
for step in "${NEXT_STEPS[@]}"; do
  if [ -z "$step" ]; then
    echo ""
  elif [[ "$step" == "  →"* ]]; then
    echo "     ${step}"
  else
    n=$((n + 1))
    printf "  %2d. %s\n" "$n" "$step"
  fi
done
