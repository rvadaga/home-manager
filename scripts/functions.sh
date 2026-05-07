#!/usr/bin/env bash

# --- bootstrap helpers ---

HM_CONFIG_DIR="${HM_CONFIG_DIR:-$HOME/.config/home-manager}"
MACHINE_JSON="${HM_CONFIG_DIR}/machine.json"

# load machine identity from machine.json
load_machine_config() {
  if [ ! -f "$MACHINE_JSON" ]; then
    echo "error: ${MACHINE_JSON} not found"
    echo "create it with: machine, name, and email fields"
    exit 1
  fi
  MACHINE_NAME=$(jq -r .machine "$MACHINE_JSON")
  USER_NAME=$(jq -r .name "$MACHINE_JSON")
  USER_EMAIL=$(jq -r .email "$MACHINE_JSON")
}

# resolve the .state directory
_state_dir() {
  echo "${HM_CONFIG_DIR}/.state"
}

# mark a bootstrap step as complete
mark_step_done() {
  local state_dir
  state_dir="$(_state_dir)"
  mkdir -p "$state_dir"
  date > "${state_dir}/${1}"
}

# upload a key to github, returning success/failure
upload_to_github() {
  local cmd="$1"
  local retry_hint="$2"
  echo "==> uploading public key to github..."
  if eval "$cmd"; then
    return 0
  else
    echo "  failed — fix the issue and re-run:"
    echo "    ${retry_hint}"
    return 1
  fi
}

# store a secret in 1password, returning success/failure
store_in_1password() {
  local title="$1"
  local value="$2"
  echo "==> storing in 1password..."
  if op item create \
    --category="Secure Note" \
    --title="$title" \
    --vault="Private" \
    "notesPlain=${value}"; then
    return 0
  else
    echo "  failed — fix the issue and re-run the op command manually"
    return 1
  fi
}

function rbe() {
  local machine=${1}
  local branch=${2:-$(git rev-parse --abbrev-ref HEAD)}
  local switch_back_to_current_branch_on_remote=${3:-false}
  local repo=$(echo "$PWD" | sed 's|^'"$HOME"'/development/||')

  echo "####"
  echo "Pulling and checking out branch \"$branch\" in \"$repo\" repo on both mac and $machine"
  echo "####\n"

  echo 'on mac'
  git switch $branch > /dev/null
  switch_exit_code=$?

  git fetch origin $branch
  if [ $switch_exit_code -ne 0 ]; then
    git checkout $branch > /dev/null
  else
    stash_output=$(git stash push -m "auto-stash before reset" 2>/dev/null)
    git reset --hard origin/$branch > /dev/null
    if [[ "$stash_output" != "No local changes to save" ]]; then
      git stash pop 2>/dev/null || echo "No stashed changes to apply or merge conflict occurred."
    fi
  fi

  current_branch_on_remote=$(ssh $machine "cd ~/development/$repo; git rev-parse --abbrev-ref HEAD")

  ssh $machine """
    echo 'on $machine';
    cd ~/development/$repo;

    git switch $branch > /dev/null
    switch_exit_code=$?
    git fetch origin $branch
    if [ $switch_exit_code -ne 0 ]; then
      git checkout $branch > /dev/null
    else
      stash_output=\$(git stash push -m 'auto-stash before reset' 2>/dev/null)
      git reset --hard origin/$branch > /dev/null
      if [[ \"\$stash_output\" != \"No local changes to save\" ]]; then
        git stash pop 2>/dev/null || echo \"No stashed changes to apply or merge conflict occurred.\"
      fi
    fi

    echo ''

    if [ \"$switch_back_to_current_branch_on_remote\" = \"true\" ]; then
      git switch $current_branch_on_remote > /dev/null
    fi
    """
}

function vmrst() {
  local machine=${1}
  local repo=$(echo "$PWD" | sed 's|^'"$HOME"'/development/||')

  echo "####"
  echo "Cleaning up files in \"$repo\" repo on $machine"
  echo "####\n"

  ssh $machine """
    cd ~/development/$repo;

    echo '';

    git restore --staged .
    git checkout .
  """
}

function delete_local_branches {
  git branch | grep -v 'main' | xargs git branch -D
}

function delete_remote_tracking_branches {
  git branch -r | grep 'origin' | grep -v 'origin/main$' | xargs git branch -D -r
}

function gist_upload {
  cat $1 | gh gist create -f $1
}

function edt {
  python3 -c "import datetime; timestamp = $1; current_time = datetime.datetime.now(); provided_time = datetime.datetime.fromtimestamp(timestamp); time_difference = current_time - provided_time; print(f'Provided Timestamp: {provided_time.strftime(\"%Y-%m-%d %H:%M:%S %Z\")}'); print(f'Current Time: {current_time.strftime(\"%Y-%m-%d %H:%M:%S %Z\")}'); print(f'Time Difference: {time_difference} (days, seconds, microseconds)')"
}

function gct() {
  if [ -z "$1" ]; then
    echo "usage: gct <branch>"
    return 1
  fi
  local branch="$1"
  git fetch origin "$branch" &&
    git switch -C "$branch" --track "origin/$branch"
}

function code() {
  local workspace_dir="$HOME/Desktop/workspaces"
  local code_bin=""

  code_bin="$(whence -p code 2>/dev/null)"

  if [ -z "$code_bin" ] && [ -x /run/current-system/sw/bin/code ]; then
    code_bin="/run/current-system/sw/bin/code"
  elif [ -z "$code_bin" ] && [ -x "$HOME/.nix-profile/bin/code" ]; then
    code_bin="$HOME/.nix-profile/bin/code"
  elif [ -z "$code_bin" ] && [ -x /usr/local/bin/code ]; then
    code_bin="/usr/local/bin/code"
  elif [ -z "$code_bin" ] && [ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    code_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  fi

  if [ -z "$code_bin" ]; then
    echo "VS Code not found on PATH."
    return 1
  fi

  # If no arguments provided, use fzf to select a workspace
  if [ $# -eq 0 ]; then
    if [ -d "$workspace_dir" ]; then
      local selected_workspace
      selected_workspace=$(find "$workspace_dir" -maxdepth 1 -name "*.code-workspace" -type f 2>/dev/null | \
        sed 's|.*/||; s/\.code-workspace$//' | \
        fzf --prompt="Select workspace: " --height=40% --reverse)

      if [ -n "$selected_workspace" ]; then
        "$code_bin" --new-window "$workspace_dir/${selected_workspace}.code-workspace"
      fi
    else
      echo "Workspace directory not found: $workspace_dir"
      return 1
    fi
  else
    # If arguments provided, pass them directly to VS Code
    "$code_bin" "$@"
  fi
}


# Diff two git blobs/paths in VS Code with proper syntax highlighting.
# Usage:
#   cdiff [LEFT_SPEC] [RIGHT_SPEC]
# Or via env vars:
#   LEFT_SPEC=... RIGHT_SPEC=... OUT_DIR=... cdiff

cdiff() {
  set -euo pipefail

  local left_spec=${1:-${LEFT_SPEC}}
  local right_spec=${2:-${RIGHT_SPEC}}
  local out_dir=${OUT_DIR:-"/tmp/git-diff"}

  mkdir -p "$out_dir"

  _cdiff_basename() {
    local spec="$1"
    local path_part="${spec#*:}"
    basename "$path_part"
  }

  local left_basename
  local right_basename
  left_basename="$(_cdiff_basename "$left_spec")"
  right_basename="$(_cdiff_basename "$right_spec")"

  local left_path="$out_dir/left_$left_basename"
  local right_path="$out_dir/right_$right_basename"

  git show "$left_spec" > "$left_path"
  git show "$right_spec" > "$right_path"

  code --diff "$left_path" "$right_path"
}

function claude-recent() {
  local n=${1:-10}
  local history="$HOME/.claude/history.jsonl"
  local tmpnames="/tmp/cc-session-names.tsv"
  local tmpfiles="/tmp/cc-recent-files.tsv"

  jq -r 'select(.display != null and .display != "")
    | "\(.sessionId)\t\(.display | gsub("\n"; " "))"' "$history" \
    | awk -F'\t' '!seen[$1]++ {print}' > "$tmpnames"

  find ~/.claude/projects -name '*.jsonl' -type f \
    -exec gstat -c '%Y %n' {} + \
    | sort -rn \
    | head -"$n" > "$tmpfiles"

  awk -v names="$tmpnames" '
    BEGIN { while ((getline line < names) > 0) {
      split(line, a, "\t"); nm[a[1]] = a[2]
    }}
    {
      epoch = $1; path = $2
      gsub(/.*\//, "", path); sub(/\.jsonl$/, "", path)
      sid = path

      cmd = "gdate -d @" epoch " +\"%Y-%m-%d %H:%M\""
      cmd | getline ts; close(cmd)

      if (sid in nm) {
        display = nm[sid]
      } else {
        fcmd = "head -1 " $2 " | jq -r \".content // empty\" 2>/dev/null"
        fcmd | getline display; close(fcmd)
        gsub(/\n/, " ", display)
      }
      if (display == "") display = "(no name)"
      printf "%s  %.8s  %s\n", ts, sid, substr(display, 1, 80)
    }' "$tmpfiles"

  rm -f "$tmpnames" "$tmpfiles"
}
