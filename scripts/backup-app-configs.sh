#!/bin/bash
# backs up app configs and system plists to google drive
# runs daily via launchd agent

set -euo pipefail

GDRIVE="$HOME/Library/CloudStorage/GoogleDrive-rahul.vadaga@gmail.com/My Drive/gdrive documents/software"
BTT_SRC="$HOME/Library/Application Support/BetterTouchTool"
BM_SRC="$HOME/Library/Application Support/BetterMouse"

if [[ ! -d "$GDRIVE" ]]; then
  echo "google drive not available at: $GDRIVE"
  exit 0
fi

# bettertouchtool — copy database files, license, presets
BTT_DST="$GDRIVE/bettertouchtool"
mkdir -p "$BTT_DST"
rsync -au --delete \
  --include='btt_data_store.*' \
  --include='bettertouchtool.bttlicense' \
  --include='btt_user_variables.plist' \
  --include='*.bttpreset' \
  --include='PresetBundles/***' \
  --exclude='*' \
  "$BTT_SRC/" "$BTT_DST/"

# also copy btt preferences plist (only if newer)
rsync -au "$HOME/Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$BTT_DST/" 2>/dev/null || true

# bettermouse — copy everything (small directory, only if newer)
BM_DST="$GDRIVE/bettermouse"
mkdir -p "$BM_DST"
rsync -au --delete "$BM_SRC/" "$BM_DST/"

# also copy bettermouse preferences plist (only if newer)
rsync -au "$HOME/Library/Preferences/com.naotanhaocan.BetterMouse.plist" "$BM_DST/" 2>/dev/null || true

# control center and menubar — binary blobs that can't be managed declaratively
MACOS_DST="$GDRIVE/macos-system"
mkdir -p "$MACOS_DST"
rsync -au "$HOME/Library/Preferences/com.apple.controlcenter.plist" "$MACOS_DST/" 2>/dev/null || true
