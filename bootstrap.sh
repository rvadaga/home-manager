#!/usr/bin/env bash
set -euo pipefail

# full macOS bootstrap — from a fresh mac to a fully configured machine
# prerequisites: internet connection, signed into apple account in system settings (for xcode CLT and app store apps)

CONFIG_DIR="$HOME/.config/home-manager"
CONFIG_REPO="https://github.com/rvadaga/home-manager.git"

echo "=== macOS bootstrap ==="
echo ""

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

echo ""
echo "=== bootstrap complete ==="

# show remaining one-time steps
NEXT_STEPS=()
if [ ! -f "${STATE_DIR}/ssh-setup-done" ]; then
  NEXT_STEPS+=("open 1password app and sign in")
  NEXT_STEPS+=("run: ${CONFIG_DIR}/scripts/setup-ssh.sh")
fi
if [ ! -f "${STATE_DIR}/gpg-setup-done" ]; then
  NEXT_STEPS+=("run: ${CONFIG_DIR}/scripts/setup-gpg.sh")
  NEXT_STEPS+=("update machines/mac-workstation.nix with your GPG key ID")
  NEXT_STEPS+=("run: darwin-rebuild switch --flake ${CONFIG_DIR}#mac-workstation")
fi
if [ ! -f "${STATE_DIR}/licenses-setup-done" ]; then
  NEXT_STEPS+=("run: ${CONFIG_DIR}/scripts/setup-licenses.sh")
fi

if [ ${#NEXT_STEPS[@]} -gt 0 ]; then
  echo ""
  echo "remaining one-time steps:"
  for i in "${!NEXT_STEPS[@]}"; do
    echo "  $((i + 1)). ${NEXT_STEPS[$i]}"
  done
else
  echo ""
  echo "all setup steps complete — nothing left to do."
fi
