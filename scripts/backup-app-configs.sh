#!/bin/bash
# backs up bettertouchtool and bettermouse configs to google drive
# runs daily via launchd agent

set -euo pipefail

GDRIVE="$HOME/Library/CloudStorage/GoogleDrive-rahul.vadaga@gmail.com/My Drive/gdrive documents/software"
BTT_SRC="$HOME/Library/Application Support/BetterTouchTool"
BM_SRC="$HOME/Library/Application Support/BetterMouse"

# bettertouchtool — copy database files, license, presets
BTT_DST="$GDRIVE/bettertouchtool"
mkdir -p "$BTT_DST"
rsync -a --delete \
  --include='btt_data_store.*' \
  --include='bettertouchtool.bttlicense' \
  --include='btt_user_variables.plist' \
  --include='*.bttpreset' \
  --include='PresetBundles/***' \
  --exclude='*' \
  "$BTT_SRC/" "$BTT_DST/"

# also copy btt preferences plist
cp -f "$HOME/Library/Preferences/com.hegenberg.BetterTouchTool.plist" "$BTT_DST/" 2>/dev/null || true

# bettermouse — copy everything (small directory)
BM_DST="$GDRIVE/bettermouse"
mkdir -p "$BM_DST"
rsync -a --delete "$BM_SRC/" "$BM_DST/"

# also copy bettermouse preferences plist
cp -f "$HOME/Library/Preferences/com.naotanhaocan.BetterMouse.plist" "$BM_DST/" 2>/dev/null || true
