#!/usr/bin/env bash
# NOTE: This script is sourced (not executed) so aliases work properly.
# Do NOT use `set -e` here — it would apply to the parent shell and kill it on any error.

if [ $# -lt 1 ]; then
  echo "Usage: gw-remove-branch [git-worktree-remove-options...] <worktree-name>"
  return 1 2>/dev/null || exit 1
fi

# Last argument is the worktree/branch name, the rest are flags for git worktree remove
wt_name="${@[-1]}"
extra_args=("${@[1,-2]}")

# Must be inside a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: not inside a git repository"
  return 1 2>/dev/null || exit 1
fi

repo_root="$(git worktree list --porcelain | head -1 | sed 's/^worktree //')"
worktrees_dir="${repo_root}-worktrees"
wt_path="${worktrees_dir}/${wt_name}"

# Remove worktree if it exists
if [ -d "$wt_path" ]; then
  echo "Removing worktree at '${wt_path}'..."
  git worktree remove "${extra_args[@]}" "$wt_path" 2>&1 || {
    echo "Error: failed to remove worktree"; return 1 2>/dev/null || exit 1; }
else
  echo "Worktree '${wt_name}' not found, skipping."
fi

# Delete branch if it exists (must happen after worktree removal)
if git show-ref --verify --quiet "refs/heads/$wt_name"; then
  echo "Deleting branch '${wt_name}'..."
  git branch -D "$wt_name" || {
    echo "Error: failed to delete branch"; return 1 2>/dev/null || exit 1; }
else
  echo "Branch '${wt_name}' not found, skipping."
fi

echo "Done."
