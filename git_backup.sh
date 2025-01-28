#!/usr/bin/env bash
#
# Backs up *all* unstaged changes into a new commit on a dedicated backup branch
# without altering your real index or working directory.
# Commits will be authored by "o1".
#
# Usage:
#   ./git-backup.sh [BACKUP_BRANCH]
#
# If BACKUP_BRANCH is not specified, defaults to backup/<currentBranch>-<commitSha>.
#

set -e  # Exit on error

cleanup() {
  unset GIT_INDEX_FILE
  rm -f "${TEMP_INDEX:-}" 2>/dev/null || true
}

trap cleanup EXIT

usage() {
  echo "Usage: $(basename "$0") [BACKUP_BRANCH]"
  echo
  echo "If BACKUP_BRANCH is not specified, defaults to backup/<currentBranch>-<commitSha>."
  echo
  echo "Examples:"
  echo "  $(basename "$0")"
  echo "  $(basename "$0") my-backup-branch"
}

# Parse arguments
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 0
fi

if [ $# -gt 1 ]; then
  echo "Error: Too many arguments." >&2
  usage
  exit 1
fi

# Compute default backup branch based on current branch/sha
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
CURRENT_SHA=$(git rev-parse --short HEAD 2>/dev/null || true)

if [ "$CURRENT_BRANCH" = "HEAD" ] || [ -z "$CURRENT_BRANCH" ]; then
  # We are probably in a detached HEAD
  CURRENT_BRANCH="detached-$CURRENT_SHA"
fi

BACKUP_BRANCH_DEFAULT="backup/${CURRENT_BRANCH}"

if [ $# -eq 1 ]; then
  BACKUP_BRANCH="$1"
else
  BACKUP_BRANCH="$BACKUP_BRANCH_DEFAULT"
fi

# 1) Figure out the parent commit:
#    If the backup branch exists, use it; otherwise use HEAD (the current branch).
if git rev-parse --verify "$BACKUP_BRANCH" >/dev/null 2>&1; then
  PARENT_COMMIT="$BACKUP_BRANCH"
else
  # If HEAD doesn't exist (brand new repo with no commits), this might fail.
  # You could handle that by omitting -p or requiring an initial commit.
  PARENT_COMMIT="HEAD"
fi

# 2) Create a temporary index file so we don't disturb the real one
TEMP_INDEX="$(mktemp)"
if [ -f .git/index ]; then
  cp .git/index "$TEMP_INDEX"
else
  touch "$TEMP_INDEX"
fi

# 3) Point Git to the temporary index
export GIT_INDEX_FILE="$TEMP_INDEX"

# 4) Stage all changes into the temporary index
git add -A

# 5) Write the tree object from the temporary index
TREE_SHA=$(git write-tree)

# 6) Create a commit object, referencing the parent commit.
#    We'll set the committer to "o1".
export GIT_COMMITTER_NAME="o1"
export GIT_COMMITTER_EMAIL="o1@backup"

COMMIT_MESSAGE="Backup on $(date)"
COMMIT_SHA=$(echo "$COMMIT_MESSAGE" | git commit-tree "$TREE_SHA" -p "$PARENT_COMMIT")

# 7) Update (or create) the backup branch to point at the new commit
git update-ref "refs/heads/$BACKUP_BRANCH" "$COMMIT_SHA"

# Set remote to the origin of the parent branch
PARENT_REMOTE=$(git config "branch.${PARENT_BRANCH}.remote")
if [[ $PARENT_REMOTE ]]; then
  PARENT_REMOTE_PREFIX=$(git config user.name | sed 's/ /./g' | tr '[:upper:]' '[:lower:]')
  git branch "--set-upstream-to=$PARENT_REMOTE${PARENT_REMOTE_PREFIX:+/$PARENT_REMOTE_PREFIX}/$BACKUP_BRANCH" "$BACKUP_BRANCH"
fi

echo "Created backup commit $COMMIT_SHA on branch '$BACKUP_BRANCH'."
