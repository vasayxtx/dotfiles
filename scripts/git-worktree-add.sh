#!/usr/bin/env bash
# NOTE: This script is sourced (not executed) so we can `cd` the caller's shell.
# Do NOT use `set -e` here — it would apply to the parent shell and kill it on any error.

if [ $# -lt 1 ]; then
  echo "Usage: gw-add <worktree-name>"
  return 1 2>/dev/null || exit 1
fi

wt_name="$1"

# Must be inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: not inside a git repository"
  return 1 2>/dev/null || exit 1
fi

# Get the root of the main worktree (not the current worktree)
repo_root="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')" || {
  echo "Error: failed to determine repo root"; return 1 2>/dev/null || exit 1; }
worktrees_dir="${repo_root}-worktrees"
wt_path="${worktrees_dir}/${wt_name}"

current_branch="$(git symbolic-ref --short HEAD)" || {
  echo "Error: failed to determine current branch"; return 1 2>/dev/null || exit 1; }

# Create worktrees directory if needed
mkdir -p "$worktrees_dir" || {
  echo "Error: failed to create ${worktrees_dir}"; return 1 2>/dev/null || exit 1; }

# Create worktree, reusing existing branch if needed
if git show-ref --verify --quiet "refs/heads/$wt_name"; then
  echo "Branch '${wt_name}' already exists."
  echo -n "Reuse it for the new worktree? [y/N] "
  read -r answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    return 1 2>/dev/null || exit 1
  fi
  echo "Reusing branch '${wt_name}'..."
  git worktree add "$wt_path" "$wt_name" || {
    echo "Error: failed to create worktree"; return 1 2>/dev/null || exit 1; }
else
  echo "Creating worktree '${wt_name}' from branch '${current_branch}'..."
  git worktree add -b "$wt_name" "$wt_path" "$current_branch" || {
    echo "Error: failed to create worktree"; return 1 2>/dev/null || exit 1; }
fi

# Copy untracked and unstaged files to the new worktree
_copied=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  mkdir -p "${wt_path}/$(dirname "$file")"
  command cp -f "${repo_root}/${file}" "${wt_path}/${file}"
  _copied=$(( _copied + 1 ))
done < <(git -C "$repo_root" ls-files --others --modified --exclude-standard)
if [ "$_copied" -gt 0 ]; then
  echo "Copied ${_copied} untracked/unstaged file(s) to worktree"
fi
unset _copied

# Copy assume-unchanged files and re-apply the flag in the new worktree
_au_copied=0
while IFS= read -r _line; do
  [ -z "$_line" ] && continue
  # ls-files -v prefixes: lowercase letter = assume-unchanged
  _flag="${_line:0:1}"
  _file="${_line:2}"
  [[ "$_flag" =~ [a-z] ]] || continue
  [ -f "${repo_root}/${_file}" ] || continue
  mkdir -p "${wt_path}/$(dirname "$_file")"
  command cp -f "${repo_root}/${_file}" "${wt_path}/${_file}"
  git -C "$wt_path" update-index --assume-unchanged "$_file" 2>/dev/null
  _au_copied=$(( _au_copied + 1 ))
done < <(git -C "$repo_root" ls-files -v)
if [ "$_au_copied" -gt 0 ]; then
  echo "Copied ${_au_copied} assume-unchanged file(s) to worktree"
fi
unset _au_copied _line _flag _file

echo "Worktree created at: ${wt_path}"

cd "$wt_path"
