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

# resolve which darwin config to activate — per-machine, read from machine.json
FLAKE_TARGET=$(jq -r '.flakeTarget // "mac-workstation"' "$MACHINE_JSON")

echo "==> preparing system files for nix-darwin..."
for f in /etc/nix/nix.conf /etc/bashrc /etc/zshrc; do
  if [ -f "$f" ] && [ ! -f "${f}.before-nix-darwin" ]; then
    echo "    renaming $f -> ${f}.before-nix-darwin"
    sudo mv "$f" "${f}.before-nix-darwin"
  fi
done

echo "==> running darwin-rebuild switch (target: ${FLAKE_TARGET})..."
if command -v darwin-rebuild &>/dev/null; then
  sudo darwin-rebuild switch --flake "${CONFIG_DIR}#${FLAKE_TARGET}"
else
  echo "    (first run — bootstrapping nix-darwin, this will take a while)"
  nix --extra-experimental-features "nix-command flakes" \
    run nix-darwin -- switch --flake "${CONFIG_DIR}#${FLAKE_TARGET}"
fi

# load the generated app manifest after nix has validated the registry.
APP_MANIFEST=$(nix eval --json \
  "${CONFIG_DIR}#darwinConfigurations.${FLAKE_TARGET}.config.personal.apps.manifest")

manifest_lines() {
  local section="$1"
  jq -r --arg section "$section" \
    '.[$section][]? | "\(.name): \(.text)"' <<< "$APP_MANIFEST"
}

# --- phase 3: setup scripts ---

SETUP_NEEDED=false
if [ ! -f "${STATE_DIR}/ssh-setup-done" ] || [ ! -f "${STATE_DIR}/gpg-setup-done" ] || [ ! -f "${STATE_DIR}/licenses-setup-done" ]; then
  SETUP_NEEDED=true
fi

if [ "$SETUP_NEEDED" = true ]; then
  SETUP_STEPS=$(manifest_lines setup)
  if [ -n "$SETUP_STEPS" ]; then
    echo ""
    echo "==> complete this app setup before the setup scripts run:"
    while IFS= read -r step; do
      echo "    ${step}"
    done <<< "$SETUP_STEPS"
    echo "    press enter when ready..."
    read -r
  fi

  if [ ! -f "${STATE_DIR}/ssh-setup-done" ]; then
    echo "==> running setup-ssh.sh..."
    "${CONFIG_DIR}/scripts/setup-ssh.sh"
  fi

  if [ ! -f "${STATE_DIR}/gpg-setup-done" ]; then
    echo "==> running setup-gpg.sh..."
    "${CONFIG_DIR}/scripts/setup-gpg.sh"
  fi

  if [ ! -f "${STATE_DIR}/licenses-setup-done" ]; then
    echo "==> applying app licenses..."
    /run/current-system/sw/bin/setup-app-licenses
    mark_step_done "licenses-setup-done"
  fi
fi

echo ""
echo "=== bootstrap complete ==="

# --- remaining manual steps ---
NEXT_STEPS=()

# gpg key needs to be added to nix config and rebuilt
if [ ! -f "${STATE_DIR}/gpg-config-done" ]; then
  NEXT_STEPS+=("update the ${FLAKE_TARGET} entry in machines/hosts.nix with the gpg key id printed above")
  NEXT_STEPS+=("  → run: sudo darwin-rebuild switch --flake ${CONFIG_DIR}#${FLAKE_TARGET}")
fi

SIGN_IN_STEPS=$(manifest_lines signIn)
if [ -n "$SIGN_IN_STEPS" ]; then
  NEXT_STEPS+=("")
  while IFS= read -r step; do
    NEXT_STEPS+=("sign in: ${step}")
  done <<< "$SIGN_IN_STEPS"
fi

PRIVACY_STEPS=$(manifest_lines privacy)
NEXT_STEPS+=("")
NEXT_STEPS+=("grant permissions when prompted:")
while IFS= read -r step; do
  [ -n "$step" ] && NEXT_STEPS+=("  → ${step}")
done <<< "$PRIVACY_STEPS"
NEXT_STEPS+=("  → terminal running darwin-rebuild: app management access")
NEXT_STEPS+=("     — required for homebrew casks to adopt existing /Applications/*.app")
NEXT_STEPS+=("       bundles; without it, xattr writes on adopted apps fail with EPERM")

LOGIN_ITEM_STEPS=$(manifest_lines loginItems)
if [ -n "$LOGIN_ITEM_STEPS" ]; then
  NEXT_STEPS+=("")
  NEXT_STEPS+=("configure login items:")
  while IFS= read -r step; do
    NEXT_STEPS+=("  → ${step}")
  done <<< "$LOGIN_ITEM_STEPS"
fi

RESTORE_STEPS=$(manifest_lines restore)
if [ -n "$RESTORE_STEPS" ]; then
  NEXT_STEPS+=("")
  NEXT_STEPS+=("after google drive finishes syncing:")
  while IFS= read -r step; do
    NEXT_STEPS+=("  → ${step}")
  done <<< "$RESTORE_STEPS"
fi

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
