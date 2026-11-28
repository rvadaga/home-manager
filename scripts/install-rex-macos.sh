set -euo pipefail

app_path=$1
app_owner=$2
if [[ -e "$app_path" || -L "$app_path" ]]; then
    exit 0
fi

app_directory=${app_path%/*}
scratch=$(/usr/bin/mktemp -d "$app_directory/.rex-install.XXXXXX")
mount_point="$scratch/mounted"
mounted=false

cleanup() {
    if $mounted; then
        /usr/bin/hdiutil detach -quiet "$mount_point" || return
    fi
    /bin/rm -rf "$scratch"
}
trap cleanup EXIT

echo "Installing Rex preview..." >&2
/usr/bin/curl --disable --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 180 --retry 2 \
    --output "$scratch/Rex.dmg" \
    https://blob.superlogical.com/download/rex-app/preview/latest.dmg
/bin/mkdir "$mount_point"
/usr/bin/hdiutil attach -quiet -readonly -nobrowse -noautoopen \
    -mountpoint "$mount_point" "$scratch/Rex.dmg"
mounted=true

/bin/mkdir "$scratch/staging"
staged_app="$scratch/staging/${app_path##*/}"
/usr/bin/ditto "$mount_point/Rex.app" "$staged_app"
/usr/bin/codesign --verify --deep --strict \
    -R='anchor apple generic and identifier "com.superlogical.rex" and certificate leaf[subject.OU] = "AG92C3PT77"' \
    "$staged_app"
/usr/bin/hdiutil detach -quiet "$mount_point"
mounted=false

# The primary user owns the bundle so Rex can apply its own updates.
/usr/sbin/chown -Rh "$app_owner" "$staged_app"
/bin/mv -n "$staged_app" "$app_directory/"
