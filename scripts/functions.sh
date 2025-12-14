#!/usr/bin/env bash

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

  # If no arguments provided, use fzf to select a workspace
  if [ $# -eq 0 ]; then
    if [ -d "$workspace_dir" ]; then
      local selected_workspace
      selected_workspace=$(ls "$workspace_dir"/*.code-workspace 2>/dev/null | \
        xargs -n 1 basename | \
        sed 's/\.code-workspace$//' | \
        fzf --prompt="Select workspace: " --height=40% --reverse)

      if [ -n "$selected_workspace" ]; then
        /usr/local/bin/code "$workspace_dir/${selected_workspace}.code-workspace"
      fi
    else
      echo "Workspace directory not found: $workspace_dir"
      return 1
    fi
  else
    # If arguments provided, pass them directly to VS Code
    /usr/local/bin/code "$@"
  fi
}
