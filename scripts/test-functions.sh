#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${script_dir}/functions.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' exit

mock_log="${test_dir}/gh.log"
remote_repo="${test_dir}/remote.git"
seed_repo="${test_dir}/seed"
local_repo="${test_dir}/local"

fail() {
  echo "not ok - $1"
  exit 1
}

pass() {
  echo "ok - $1"
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [ "$expected" != "$actual" ]; then
    echo "expected: $expected"
    echo "actual:   $actual"
    fail "$label"
  fi
}

assert_contains() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  case "$actual" in
    *"$expected"*) ;;
    *) fail "$label" ;;
  esac
}

reset_mock() {
  : > "$mock_log"
  mock_failure=""
  mock_search_output=$'17\tOPEN\tfeature/example\t1111111111111111111111111111111111111111\tfix exact phrase\thttps://github.com/example/tools/pull/17'
}

gh() {
  printf '%s\n' "$*" >> "$mock_log"

  if [ -n "$mock_failure" ] && [[ "$*" == *"$mock_failure"* ]]; then
    echo "mock github failure" >&2
    return 1
  fi

  if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
    printf 'example/tools\t%s\n' "$remote_repo"
    return 0
  fi

  if [ "$1" = "api" ] && [ "$2" = "graphql" ]; then
    printf '%s\n' "$mock_search_output"
    return 0
  fi

  if [ "$1" = "api" ] && [[ "$2" == */git/ref/heads/feature/example ]]; then
    printf '%s\n' "$branch_oid"
    return 0
  fi

  if [ "$1" = "api" ] && [[ "$2" == */pulls/42 ]]; then
    printf '%s\n' "$pr_oid"
    return 0
  fi

  echo "unexpected gh call: $*" >&2
  return 1
}

git init --quiet --bare "$remote_repo"
git init --quiet -b main "$seed_repo"
git -C "$seed_repo" config user.name "example user"
git -C "$seed_repo" config user.email "user@example.com"
git -C "$seed_repo" config commit.gpgsign false
git -C "$seed_repo" config core.fsmonitor false
printf 'main\n' > "${seed_repo}/file.txt"
git -C "$seed_repo" add file.txt
git -C "$seed_repo" commit --quiet -m "add main file"
main_oid=$(git -C "$seed_repo" rev-parse HEAD)
git -C "$seed_repo" remote add origin "$remote_repo"
git -C "$seed_repo" push --quiet origin main

git -C "$seed_repo" checkout --quiet -b feature/example
printf 'first branch version\n' > "${seed_repo}/branch.txt"
git -C "$seed_repo" add branch.txt
git -C "$seed_repo" commit --quiet -m "add branch file"
git -C "$seed_repo" push --quiet origin feature/example

git clone --quiet "$remote_repo" "$local_repo"
git -C "$local_repo" config core.fsmonitor false

printf 'second branch version\n' >> "${seed_repo}/branch.txt"
git -C "$seed_repo" add branch.txt
git -C "$seed_repo" commit --quiet -m "update branch file"
branch_oid=$(git -C "$seed_repo" rev-parse HEAD)
git -C "$seed_repo" push --quiet origin feature/example

git -C "$seed_repo" checkout --quiet -b review/change main
printf 'pull request\n' > "${seed_repo}/review.txt"
git -C "$seed_repo" add review.txt
git -C "$seed_repo" commit --quiet -m "add review file"
pr_oid=$(git -C "$seed_repo" rev-parse HEAD)
git -C "$seed_repo" push --quiet origin HEAD:refs/pull/42/head

reset_mock
search_output=$(gh-pr-search fix exact phrase)
assert_equals "$mock_search_output" "$search_output" "search prints the compact pull-request fields"
search_log=$(<"$mock_log")
assert_contains 'searchQuery=is:pr author:@me in:title "fix exact phrase"' "$search_log" "search limits the text to titles by the current user"
assert_contains 'headRefName' "$search_log" "search asks github for head details"
pass "pull-request title search"

reset_mock
if gh-pr-search >/dev/null 2>&1; then
  fail "search accepts a missing title"
fi
if gh-pr-search '   ' >/dev/null 2>&1; then
  fail "search accepts a blank title"
fi
if [ -s "$mock_log" ]; then
  fail "invalid search input calls github"
fi
pass "search rejects missing and blank text"

reset_mock
mock_failure="api graphql"
if gh-pr-search unavailable >/dev/null 2>&1; then
  fail "search hides a github api failure"
fi
pass "search returns github api failures"

reset_mock
if ! (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "branch head checkout"
fi
assert_equals "$branch_oid" "$(git -C "$local_repo" rev-parse HEAD)" "branch checkout uses the exact remote head"
if git -C "$local_repo" symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  fail "branch checkout leaves an attached head"
fi
branch_log=$(<"$mock_log")
assert_contains "repo view" "$branch_log" "branch checkout infers the repository"
assert_contains "/git/ref/heads/feature/example" "$branch_log" "branch checkout preserves slash-containing names"
pass "branch checkout resolves and detaches at the remote head"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
reset_mock
if ! (cd "$local_repo" && gh-detach-head --pr 42 >/dev/null 2>&1); then
  fail "pull-request head checkout"
fi
assert_equals "$pr_oid" "$(git -C "$local_repo" rev-parse HEAD)" "pull-request checkout uses the exact remote head"
if git -C "$local_repo" symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  fail "pull-request checkout leaves an attached head"
fi
pass "pull-request checkout resolves and detaches at the remote head"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
printf 'local edit\n' >> "${local_repo}/file.txt"
dirty_contents=$(<"${local_repo}/file.txt")
reset_mock
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "branch checkout accepts a dirty tracked file"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "dirty tracked checkout keeps head"
assert_equals "$dirty_contents" "$(<"${local_repo}/file.txt")" "dirty tracked checkout keeps content"
if [ -s "$mock_log" ]; then
  fail "dirty tracked checkout calls github"
fi
git -C "$local_repo" restore file.txt

printf 'untracked\n' > "${local_repo}/local.txt"
reset_mock
if (cd "$local_repo" && gh-detach-head --pr 42 >/dev/null 2>&1); then
  fail "pull-request checkout accepts an untracked file"
fi
assert_equals "untracked" "$(<"${local_repo}/local.txt")" "dirty untracked checkout keeps content"
rm "${local_repo}/local.txt"
pass "dirty worktrees are left unchanged"

reset_mock
for invalid_args in \
  '' \
  '--branch' \
  '--pr' \
  '--pr 0' \
  '--pr no' \
  '--branch feature/example --pr 42' \
  '--unknown value'; do
  read -r -a args <<< "$invalid_args"
  if (cd "$local_repo" && gh-detach-head "${args[@]}" >/dev/null 2>&1); then
    fail "checkout accepts invalid input: $invalid_args"
  fi
done
if [ -s "$mock_log" ]; then
  fail "invalid checkout input calls github"
fi
pass "checkout rejects missing, malformed, and ambiguous input"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
reset_mock
mock_failure="repo view"
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "checkout hides a repository inference failure"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "repository failure keeps head"

reset_mock
mock_failure="git/ref"
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "checkout hides a github api failure"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "api failure keeps head"
pass "checkout returns github repository and api failures"

echo "all function tests passed"
