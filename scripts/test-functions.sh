#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${script_dir}/functions.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' exit

mock_log="${test_dir}/gh.log"
git_log="${test_dir}/git.log"
remote_repo="${test_dir}/remote.git"
seed_repo="${test_dir}/seed"
local_repo="${test_dir}/local"
github_origin="https://github.com/example/tools.git"
mock_failure=""
mock_git_fetch_failure=""
mock_search_output=""

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

assert_not_contains() {
  local unexpected="$1"
  local actual="$2"
  local label="$3"

  case "$actual" in
    *"$unexpected"*) fail "$label" ;;
    *) ;;
  esac
}

reset_mock() {
  : > "$mock_log"
  : > "$git_log"
  mock_failure=""
  mock_git_fetch_failure=""
  mock_search_output=$'17\tOPEN\tfeature/example\t1111111111111111111111111111111111111111\tfix exact phrase\thttps://github.com/example/tools/pull/17'
}

gh() {
  printf 'gh-call\n%s\n' "$*" >> "$mock_log"

  if [ -n "$mock_failure" ] && [[ "$*" == *"$mock_failure"* ]]; then
    echo "mock github failure" >&2
    return 1
  fi

  if [ "$1" = "api" ] && [ "$2" = "graphql" ]; then
    printf '%s\n' "$mock_search_output"
    return 0
  fi

  echo "unexpected gh call: $*" >&2
  return 1
}

git() {
  printf '%s\n' "$*" >> "$git_log"

  if [ -n "$mock_git_fetch_failure" ] && [ "$1" = "fetch" ] && [[ "$*" == *"$mock_git_fetch_failure"* ]]; then
    echo "mock git transport failure" >&2
    return 1
  fi

  command git "$@"
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
git -C "$local_repo" remote set-url origin "$github_origin"
git -C "$local_repo" config "url.file://${remote_repo}.insteadOf" "$github_origin"

printf 'second branch version\n' >> "${seed_repo}/branch.txt"
git -C "$seed_repo" add branch.txt
git -C "$seed_repo" commit --quiet -m "update branch file"
branch_oid=$(git -C "$seed_repo" rev-parse HEAD)
git -C "$seed_repo" push --quiet origin feature/example
stale_branch_oid=$(git -C "$local_repo" rev-parse refs/remotes/origin/feature/example)

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
assert_contains '          number' "$search_log" "default search asks for the pull-request number"
assert_contains '          headRefName' "$search_log" "default search asks for the head branch"
assert_contains '          headRefOid' "$search_log" "default search asks for the head oid"
assert_contains '[.number, .state, .headRefName, .headRefOid, .title, .url]' "$search_log" "default search keeps the six-field order"
assert_equals "1" "$(awk '$0 == "gh-call" { count++ } END { print count + 0 }' "$mock_log")" "default search uses one paginated github flow"
pass "pull-request title search keeps its default output"

reset_mock
help_output=$(gh-pr-search --help)
assert_contains 'usage: gh-pr-search [selector]... [--] <title text>' "$help_output" "search help shows the selector form"
assert_contains 'selector: -f <name>[,<name>...] | --field <name>[,<name>...]' "$help_output" "search help shows both selector flags"
assert_contains 'number, state, headRefName, headRefOid, title, url' "$help_output" "search help lists the allowed fields"
assert_contains 'gh-pr-search --field headRefOid --field number' "$help_output" "search help shows repeated long selectors"
assert_contains 'gh-pr-search -f headRefOid -f number' "$help_output" "search help shows repeated short selectors"
assert_contains 'gh-pr-search -f headRefOid,number' "$help_output" "search help shows a comma-separated selector"
assert_contains 'gh-pr-search --field headRefOid,url -f number,state' "$help_output" "search help shows mixed comma-separated selectors"
assert_contains 'at most 1,000 results' "$help_output" "search help states the github result limit"
if [ -s "$mock_log" ]; then
  fail "search help calls github"
fi
pass "search help covers output selection"

for field in headRefOid number url; do
  reset_mock
  case "$field" in
    headRefOid) mock_search_output="1111111111111111111111111111111111111111" ;;
    number) mock_search_output="17" ;;
    url) mock_search_output="https://github.com/example/tools/pull/17" ;;
  esac
  search_output=$(gh-pr-search --field "$field" fix exact phrase)
  assert_equals "$mock_search_output" "$search_output" "search prints only $field"
  search_log=$(<"$mock_log")
  assert_contains "          ${field}" "$search_log" "search requests $field"
  assert_contains "[.${field}]" "$search_log" "search formats only $field"
  assert_equals "1" "$(awk '$0 == "gh-call" { count++ } END { print count + 0 }' "$mock_log")" "single-field search uses one paginated github flow"
  case "$field" in
    headRefOid)
      assert_not_contains '          number' "$search_log" "head oid search requests the number"
      assert_not_contains '          title' "$search_log" "head oid search requests the title"
      ;;
  esac
done
pass "search supports minimal single-field output"

reset_mock
mock_search_output=$'1111111111111111111111111111111111111111\t17'
search_output=$(gh-pr-search --field headRefOid --field number exact phrase)
assert_equals "$mock_search_output" "$search_output" "search supports repeated long selectors"
search_log=$(<"$mock_log")
assert_contains '[.headRefOid, .number]' "$search_log" "repeated long selectors keep caller order"

reset_mock
mock_search_output=$'1111111111111111111111111111111111111111\t17'
search_output=$(gh-pr-search -f headRefOid -f number exact phrase)
assert_equals "$mock_search_output" "$search_output" "search supports repeated short selectors"
search_log=$(<"$mock_log")
assert_contains '[.headRefOid, .number]' "$search_log" "repeated short selectors keep caller order"

reset_mock
mock_search_output=$'1111111111111111111111111111111111111111\t17'
search_output=$(gh-pr-search -f headRefOid,number exact phrase)
assert_equals "$mock_search_output" "$search_output" "search supports a comma-separated short selector"
search_log=$(<"$mock_log")
assert_contains '[.headRefOid, .number]' "$search_log" "comma-separated fields keep caller order"

reset_mock
mock_search_output=$'1111111111111111111111111111111111111111\thttps://github.com/example/tools/pull/17\t17\tOPEN'
search_output=$(gh-pr-search --field headRefOid,url exact -f number,state phrase)
assert_equals "$mock_search_output" "$search_output" "search flattens mixed selector groups"
search_log=$(<"$mock_log")
assert_contains 'searchQuery=is:pr author:@me in:title "exact phrase"' "$search_log" "mixed selectors can appear between title words"
assert_contains '[.headRefOid, .url, .number, .state]' "$search_log" "mixed selector groups keep caller order"
assert_equals "1" "$(awk '$0 == "gh-call" { count++ } END { print count + 0 }' "$mock_log")" "mixed selectors use one paginated github flow"
pass "search supports repeated, comma-separated, and mixed selectors"

reset_mock
mock_search_output="17"
search_output=$(gh-pr-search -f number -- --draft title)
assert_equals "17" "$search_output" "search accepts a title beginning with a dash"
search_log=$(<"$mock_log")
assert_contains 'searchQuery=is:pr author:@me in:title "--draft title"' "$search_log" "search preserves a dash-leading title"
pass "search separates options from dash-leading titles"

reset_mock
mock_search_output=$'17\n23'
search_output=$(gh-pr-search -f number repeated title)
assert_equals "$mock_search_output" "$search_output" "search prints one selected value for each match"

reset_mock
mock_search_output=""
if ! search_output=$(gh-pr-search -f url absent title); then
  fail "search rejects zero matches"
fi
assert_equals "" "$search_output" "search prints nothing for zero matches"
pass "search handles multiple and zero matches"

reset_mock
if gh-pr-search >/dev/null 2>&1; then
  fail "search accepts a missing title"
fi
if gh-pr-search '   ' >/dev/null 2>&1; then
  fail "search accepts a blank title"
fi
if gh-pr-search --field >/dev/null 2>&1; then
  fail "search accepts a missing selector value"
fi
if gh-pr-search -f >/dev/null 2>&1; then
  fail "search accepts a missing short-selector value"
fi
if gh-pr-search --field -- fix >/dev/null 2>&1; then
  fail "search accepts the option separator as a selector value"
fi
if gh-pr-search -f -- fix >/dev/null 2>&1; then
  fail "search accepts the option separator as a short-selector value"
fi
if gh-pr-search --field repository fix >/dev/null 2>&1; then
  fail "search accepts an unknown field"
fi
if gh-pr-search -f headRefOid,repository fix >/dev/null 2>&1; then
  fail "search accepts an unknown field in a comma group"
fi
if gh-pr-search -f ,headRefOid fix >/dev/null 2>&1; then
  fail "search accepts a leading empty field"
fi
if gh-pr-search --field headRefOid, fix >/dev/null 2>&1; then
  fail "search accepts a trailing empty field"
fi
if gh-pr-search -f headRefOid,,number fix >/dev/null 2>&1; then
  fail "search accepts an empty field between commas"
fi
if gh-pr-search -f '' fix >/dev/null 2>&1; then
  fail "search accepts an empty field group"
fi
if gh-pr-search --field url >/dev/null 2>&1; then
  fail "search accepts a selector without title text"
fi
if gh-pr-search -f url '   ' >/dev/null 2>&1; then
  fail "search accepts a short selector with a blank title"
fi
if gh-pr-search --unknown fix >/dev/null 2>&1; then
  fail "search accepts an unknown option"
fi
if [ -s "$mock_log" ]; then
  fail "invalid search input calls github"
fi
pass "search rejects missing text and invalid selectors"

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
branch_git_log=$(<"$git_log")
assert_equals "$branch_oid" "$(git -C "$local_repo" rev-parse HEAD)" "branch checkout uses the exact remote head"
if git -C "$local_repo" symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  fail "branch checkout leaves an attached head"
fi
assert_equals "$branch_oid" "$(git -C "$local_repo" rev-parse FETCH_HEAD)" "branch checkout detaches at fetch head"
assert_contains 'fetch --quiet --no-tags origin refs/heads/feature/example' "$branch_git_log" "branch checkout fetches the exact slash-containing ref"
assert_equals "1" "$(awk '$0 == "fetch --quiet --no-tags origin refs/heads/feature/example" { count++ } END { print count + 0 }' "$git_log")" "branch checkout uses one fetch"
if [ "$stale_branch_oid" = "$branch_oid" ]; then
  fail "branch fixture lacks a stale remote-tracking ref"
fi
if [ -s "$mock_log" ]; then
  fail "branch checkout calls github api"
fi
pass "branch checkout fetches and detaches at the exact remote head"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
reset_mock
if ! (cd "$local_repo" && gh-detach-head --pr 42 >/dev/null 2>&1); then
  fail "pull-request head checkout"
fi
pr_git_log=$(<"$git_log")
assert_equals "$pr_oid" "$(git -C "$local_repo" rev-parse HEAD)" "pull-request checkout uses the exact remote head"
if git -C "$local_repo" symbolic-ref --quiet HEAD >/dev/null 2>&1; then
  fail "pull-request checkout leaves an attached head"
fi
assert_equals "$pr_oid" "$(git -C "$local_repo" rev-parse FETCH_HEAD)" "pull-request checkout detaches at fetch head"
assert_contains 'fetch --quiet --no-tags origin refs/pull/42/head' "$pr_git_log" "pull-request checkout fetches github's exact head ref"
assert_equals "1" "$(awk '$0 == "fetch --quiet --no-tags origin refs/pull/42/head" { count++ } END { print count + 0 }' "$git_log")" "pull-request checkout uses one fetch"
if [ -s "$mock_log" ]; then
  fail "pull-request checkout calls github api"
fi
pass "pull-request checkout fetches and detaches at the exact github head"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
printf 'local edit\n' >> "${local_repo}/file.txt"
dirty_contents=$(<"${local_repo}/file.txt")
reset_mock
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "branch checkout accepts a dirty tracked file"
fi
dirty_git_log=$(<"$git_log")
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "dirty tracked checkout keeps head"
assert_equals "$dirty_contents" "$(<"${local_repo}/file.txt")" "dirty tracked checkout keeps content"
assert_not_contains 'fetch ' "$dirty_git_log" "dirty tracked checkout fetches a ref"
git -C "$local_repo" restore file.txt

printf 'untracked\n' > "${local_repo}/local.txt"
reset_mock
if (cd "$local_repo" && gh-detach-head --pr 42 >/dev/null 2>&1); then
  fail "pull-request checkout accepts an untracked file"
fi
dirty_git_log=$(<"$git_log")
assert_equals "untracked" "$(<"${local_repo}/local.txt")" "dirty untracked checkout keeps content"
assert_not_contains 'fetch ' "$dirty_git_log" "dirty untracked checkout fetches a ref"
rm "${local_repo}/local.txt"
pass "dirty worktrees are left unchanged"

reset_mock
for invalid_args in \
  '' \
  '--branch' \
  '--pr' \
  '--pr 0' \
  '--pr 00' \
  '--pr no' \
  '--branch feature/example --pr 42' \
  '--unknown value'; do
  read -r -a args <<< "$invalid_args"
  if (cd "$local_repo" && gh-detach-head "${args[@]}" >/dev/null 2>&1); then
    fail "checkout accepts invalid input: $invalid_args"
  fi
done
if [ -s "$git_log" ] || [ -s "$mock_log" ]; then
  fail "invalid checkout input reads the repository or calls github"
fi
pass "checkout rejects missing, malformed, and ambiguous input"

git -C "$local_repo" checkout --quiet --detach "$main_oid"
git -C "$local_repo" remote remove origin
reset_mock
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "checkout hides a repository inference failure"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "repository failure keeps head"
git -C "$local_repo" remote add origin "$github_origin"

reset_mock
git -C "$local_repo" remote set-url origin "$remote_repo"
if (cd "$local_repo" && gh-detach-head --pr 42 >/dev/null 2>&1); then
  fail "pull-request checkout accepts a non-github origin"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "remote-shape failure keeps head"
git -C "$local_repo" remote set-url origin "$github_origin"

reset_mock
mock_git_fetch_failure="refs/heads/feature/example"
if (cd "$local_repo" && gh-detach-head --branch feature/example >/dev/null 2>&1); then
  fail "checkout hides a git transport failure"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "transport failure keeps head"
if [ -s "$mock_log" ]; then
  fail "transport failure calls github api"
fi

reset_mock
if (cd "$local_repo" && gh-detach-head --branch missing >/dev/null 2>&1); then
  fail "branch checkout accepts a missing remote ref"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "missing branch keeps head"

reset_mock
if (cd "$local_repo" && gh-detach-head --pr 99 >/dev/null 2>&1); then
  fail "pull-request checkout accepts a missing remote ref"
fi
assert_equals "$main_oid" "$(git -C "$local_repo" rev-parse HEAD)" "missing pull request keeps head"
pass "checkout returns repository, remote-shape, and git transport failures"

echo "all function tests passed"
