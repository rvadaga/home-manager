#!/usr/bin/env bash
set -euo pipefail

# full macOS bootstrap — from a fresh mac to a fully configured machine
# prerequisites: internet connection, signed into apple account in system settings (for xcode CLT and app store apps)

CONFIG_DIR="$HOME/.config/home-manager"
CONFIG_REPO="git@github.com:rahulvadaga/home-manager.git"

echo "=== macOS bootstrap ==="
echo ""

# step 1: xcode command line tools
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

# step 2: nix (determinate systems installer)
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

# step 3: homebrew (nix-darwin manages it declaratively, but it must exist first)
if [ ! -x /opt/homebrew/bin/brew ]; then
  echo "==> installing homebrew..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "==> homebrew: already installed"
fi

# step 4: github CLI auth (with scopes needed by setup scripts)
if ! gh auth status &>/dev/null; then
  echo "==> authenticating github CLI..."
  gh auth login -p https -w -s admin:public_key,write:gpg_key
else
  echo "==> github CLI: already authenticated"
fi

# step 5: clone config repo
if [ ! -d "$CONFIG_DIR" ]; then
  echo "==> cloning config repo..."
  mkdir -p "$(dirname "$CONFIG_DIR")"
  git clone "$CONFIG_REPO" "$CONFIG_DIR"
else
  echo "==> config repo: already exists at $CONFIG_DIR"
fi

# step 6: rename files that nix-darwin needs to own
echo "==> preparing system files for nix-darwin..."
for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
  if [ -f "$f" ] && [ ! -f "${f}.before-nix-darwin" ]; then
    echo "    renaming $f -> ${f}.before-nix-darwin"
    sudo mv "$f" "${f}.before-nix-darwin"
  fi
done

# step 7: first darwin-rebuild switch
echo "==> running first darwin-rebuild switch..."
echo "    (this will take a while on first run)"
nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin -- switch --flake "${CONFIG_DIR}#mac-workstation"

echo ""
echo "=== bootstrap complete ==="
echo ""
echo "next steps (manual, one-time):"
echo "  1. open 1password app and sign in"
echo "  2. run: ${CONFIG_DIR}/scripts/setup-ssh.sh \"<name>\" \"<email>\""
echo "  3. run: ${CONFIG_DIR}/scripts/setup-gpg.sh \"<name>\" \"<email>\""
echo "  4. update machines/mac-workstation.nix with your GPG key ID"
echo "  5. run: darwin-rebuild switch --flake ${CONFIG_DIR}#mac-workstation"
echo "  6. run: ${CONFIG_DIR}/scripts/setup-licenses.sh"
