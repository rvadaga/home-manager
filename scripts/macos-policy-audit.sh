# shellcheck shell=bash
set -uo pipefail

usage() {
  echo "usage: macos-policy-audit [--listeners]"
  echo "compare the declared macos policy with effective privacy, firewall, sharing, and listener state"
}

case "${1:-}" in
  "") ;;
  --listeners) ;;
  --help|-h)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

policy_file="${MACOS_POLICY_FILE:-/etc/nix-darwin/policies/macos-policy.json}"
drift=0

if [[ ! -r "$policy_file" ]]; then
  echo "missing policy file: $policy_file" >&2
  exit 2
fi

console_user="$(/usr/bin/stat -f '%Su' /dev/console)"
if ! user_home="$(/usr/bin/dscl . -read "/Users/$console_user" NFSHomeDirectory 2>/dev/null | awk '{ print $2 }')"; then
  user_home=""
fi
if [[ -z "$user_home" ]]; then
  user_home="/Users/$console_user"
fi
system_tcc_db="/Library/Application Support/com.apple.TCC/TCC.db"
user_tcc_db="$user_home/Library/Application Support/com.apple.TCC/TCC.db"

bool_word() {
  if [[ "$1" == "true" ]]; then
    echo "on"
  else
    echo "off"
  fi
}

check_tcc() {
  local label="$1"
  local permission="$2"
  local service="$3"
  local database="$4"
  local expected
  local actual

  expected="$(
    jq -r --arg permission "$permission" '
      .privacy.applications
      | to_entries[]
      | select(.value.permissions[$permission] == true)
      | .value.identifier
    ' "$policy_file" | LC_ALL=C sort -u
  )"

  [[ -n "$expected" ]] || return 0

  if [[ ! -r "$database" ]]; then
    echo "unverified $label: this terminal cannot read $database"
    return 0
  fi

  if ! actual="$(sqlite3 "$database" "select client from access where service = '$service' and auth_value = 2 order by client;")"; then
    echo "unverified $label: sqlite could not query the privacy database"
    return 0
  fi

  while IFS= read -r identifier; do
    [[ -n "$identifier" ]] || continue
    if grep -Fqx "$identifier" <<<"$actual"; then
      echo "ok $label: $identifier"
    else
      echo "missing $label: $identifier"
      drift=1
    fi
  done <<<"$expected"
}

check_boolean() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$expected" == "$actual" ]]; then
    echo "ok $label: $(bool_word "$actual")"
  else
    echo "drift $label: expected $(bool_word "$expected"), found $(bool_word "$actual")"
    drift=1
  fi
}

echo "privacy"
check_tcc "accessibility" "accessibility" "kTCCServiceAccessibility" "$system_tcc_db"
check_tcc "full disk access" "fullDiskAccess" "kTCCServiceSystemPolicyAllFiles" "$system_tcc_db"
check_tcc "screen recording" "screenRecording" "kTCCServiceScreenCapture" "$system_tcc_db"
check_tcc "input monitoring" "inputMonitoring" "kTCCServiceListenEvent" "$system_tcc_db"
check_tcc "bluetooth" "bluetooth" "kTCCServiceBluetoothAlways" "$user_tcc_db"
check_tcc "camera" "camera" "kTCCServiceCamera" "$user_tcc_db"
check_tcc "microphone" "microphone" "kTCCServiceMicrophone" "$user_tcc_db"

echo
echo "firewall"
expected_firewall="$(jq -r '.firewall.enable' "$policy_file")"
firewall_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || true)"
if [[ "$firewall_state" == *"State = 1"* ]]; then
  actual_firewall=true
else
  actual_firewall=false
fi
check_boolean "application firewall" "$expected_firewall" "$actual_firewall"

expected_stealth="$(jq -r '.firewall.stealthMode' "$policy_file")"
stealth_state="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true)"
if [[ "$stealth_state" == *"enabled"* ]]; then
  actual_stealth=true
else
  actual_stealth=false
fi
check_boolean "stealth mode" "$expected_stealth" "$actual_stealth"

echo
echo "sharing"
expected_remote_login="$(jq -r '.sharing.remoteLogin' "$policy_file")"
remote_login_state="$(/usr/sbin/systemsetup -getremotelogin 2>/dev/null || true)"
if [[ "$remote_login_state" == *": On" ]]; then
  actual_remote_login=true
elif [[ "$remote_login_state" == *": Off" ]]; then
  actual_remote_login=false
else
  actual_remote_login=unknown
fi

if [[ "$actual_remote_login" == unknown ]]; then
  echo "unverified remote login: systemsetup did not return its state"
else
  check_boolean "remote login" "$expected_remote_login" "$actual_remote_login"
fi

expected_content_caching="$(jq -r '.sharing.contentCaching' "$policy_file")"
if content_caching_state="$(/usr/bin/AssetCacheManagerUtil isActivated 2>/dev/null)"; then
  if [[ "$content_caching_state" == *"true"* || "$content_caching_state" == *"activated"* ]]; then
    actual_content_caching=true
  else
    actual_content_caching=false
  fi
  check_boolean "content caching" "$expected_content_caching" "$actual_content_caching"
else
  echo "unverified content caching: run this audit as an administrator"
fi

echo "review in system settings or device management:"
jq -r '
  .sharing
  | to_entries[]
  | select(.key != "remoteLogin" and .key != "contentCaching")
  | "  \(.key): \(if .value then "on" else "off" end)"
' "$policy_file"

if [[ "${1:-}" == "--listeners" ]]; then
  echo
  echo "listening tcp sockets"
  lsof -nP -iTCP -sTCP:LISTEN
fi

exit "$drift"
