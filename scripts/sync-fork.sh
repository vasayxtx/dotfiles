#!/usr/bin/env bash
set -euo pipefail

REMOTE="${1:-origin}"

# Get the repo nwo (owner/name) from the remote URL
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null) || {
    echo "Error: remote '$REMOTE' not found"
    exit 1
}

# Extract owner/repo from SSH or HTTPS URL
# Handles: git@github.com:owner/repo.git, git@github.com-alias:owner/repo.git,
#          https://github.com/owner/repo.git
REPO=$(echo "$REMOTE_URL" | sed -E 's#^(https?://[^/]+/|.*:)##; s#\.git$##')

if [[ ! "$REPO" =~ ^[^/]+/[^/]+$ ]]; then
    echo "Error: could not parse owner/repo from '$REMOTE_URL'"
    exit 1
fi

echo "Remote '$REMOTE' -> $REPO"

# Check if it's a fork and get parent info
FORK_INFO=$(gh api "repos/$REPO" --jq '{isFork: .fork, parent: .parent.full_name, parentDefault: .parent.default_branch}')

IS_FORK=$(echo "$FORK_INFO" | jq -r '.isFork')
PARENT=$(echo "$FORK_INFO" | jq -r '.parent')
PARENT_DEFAULT=$(echo "$FORK_INFO" | jq -r '.parentDefault')

if [ "$IS_FORK" != "true" ]; then
    echo "'$REPO' is not a fork. Nothing to sync."
    exit 0
fi

echo "Fork of: $PARENT (default branch: $PARENT_DEFAULT)"

# Get current HEAD of the fork's default branch before sync
BEFORE_SHA=$(gh api "repos/$REPO/branches/$PARENT_DEFAULT" --jq '.commit.sha')

# Sync the fork
echo "Syncing $REPO with $PARENT/$PARENT_DEFAULT..."
gh repo sync "$REPO" --source "$PARENT" --branch "$PARENT_DEFAULT"

# Get HEAD after sync and count new commits
AFTER_SHA=$(gh api "repos/$REPO/branches/$PARENT_DEFAULT" --jq '.commit.sha')

if [ "$BEFORE_SHA" = "$AFTER_SHA" ]; then
    echo "Already up to date."
else
    COMMIT_COUNT=$(gh api "repos/$REPO/compare/${BEFORE_SHA}...${AFTER_SHA}" --jq '.total_commits')
    echo "Synced $COMMIT_COUNT new commit(s)."
fi
