#!/usr/bin/env bash
set -euo pipefail

# fetch license keys from 1password and apply via defaults write
# safe to run multiple times — idempotent

echo "==> fetching license keys from 1password..."

BETTERMOUSE_LICENSE=$(op read "op://Private/BetterMouse License/license-key" 2>/dev/null || echo "")
BTT_LICENSE=$(op read "op://Private/BetterTouchTool License/license-key" 2>/dev/null || echo "")

if [ -n "$BETTERMOUSE_LICENSE" ]; then
  defaults write com.hegenberg.BetterMouse licenseKey "$BETTERMOUSE_LICENSE"
  echo "  bettermouse: applied"
else
  echo "  bettermouse: not found in 1password (skipped)"
fi

if [ -n "$BTT_LICENSE" ]; then
  defaults write com.hegenberg.BetterTouchTool BHTLicenseKey "$BTT_LICENSE"
  echo "  bettertouchtool: applied"
else
  echo "  bettertouchtool: not found in 1password (skipped)"
fi

echo ""
echo "done."

# mark step complete
STATE_DIR="$(dirname "$0")/../.state"
mkdir -p "$STATE_DIR"
date > "${STATE_DIR}/licenses-setup-done"
