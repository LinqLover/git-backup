#!/usr/bin/env bash
#
# Backs up *all* unstaged changes into a new commit on a dedicated backup branch
# without altering your real index or working directory.
# Commits will be authored by "o1".
#
# Usage:
#   ./git-backup.sh [--push] [BACKUP_BRANCH]
#
# If BACKUP_BRANCH is not specified, defaults to backup/<currentBranch>.
#
# Options:
#   --push    Push the backup branch immediately after creating the commit.
#   -h, --help  Show this help message.
#
# Examples:
#   ./git-backup.sh
#   ./git-backup.sh my-backup-branch
#   ./git-backup.sh --push
#   ./git-backup.sh --push my-backup-branch
#

set -e  # Exit on error

cleanup() {
  if [[ $TEMP_INDEX ]]; then
    rm -f "$TEMP_INDEX" 2>/dev/null || true
  else
    rm -f .git/index
  fi
}

trap cleanup EXIT

usage() {
  echo "Usage: $(basename "$0") [--push] [BACKUP_BRANCH]"
  echo
  echo "If BACKUP_BRANCH is not specified, defaults to backup/<currentBranch>."
  echo
  echo "Options:"
  echo "  --push      Push the backup branch immediately after creating the commit."
  echo "  -h, --help  Show this help message."
  echo
  echo "Examples:"
  echo "  $(basename "$0")"
  echo "  $(basename "$0") my-backup-branch"
  echo "  $(basename "$0") --push"
  echo "  $(basename "$0") --push my-backup-branch"
}

# Default flag
should_push=false

# We'll collect positional args here
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    --push)
      should_push=true
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

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
  PARENT_COMMIT="HEAD"
fi

# 2) Create a temporary index file so we don't disturb the real one
if [ -f .git/index ]; then
  TEMP_INDEX="$(mktemp)"
  cp .git/index "$TEMP_INDEX"
  export GIT_INDEX_FILE="$TEMP_INDEX"
else
  # git write-tree does not work with empty GIT_INDEX_FILE, use default index instead and deleting it later
  TEMP_INDEX=""
fi

# 3) Stage all changes into the temporary index
git add -A

# 4) Write the tree object from the temporary index
TREE_SHA=$(git write-tree)

# 5) Create a commit object, referencing the parent commit.
#    We'll set the committer to "o1".
export GIT_COMMITTER_NAME="o1"
#export GIT_COMMITTER_EMAIL="o1@backup"

COMMIT_MESSAGE="Backup on $(date)"
COMMIT_SHA=$(echo "$COMMIT_MESSAGE" | git commit-tree "$TREE_SHA" -p "$PARENT_COMMIT")

# 6) Update (or create) the backup branch to point at the new commit
git update-ref "refs/heads/$BACKUP_BRANCH" "$COMMIT_SHA"

echo "Created backup commit $COMMIT_SHA on branch '$BACKUP_BRANCH'."

# Optionally set upstream, if we can find a remote for the current branch
PARENT_REMOTE=$(git config "branch.$CURRENT_BRANCH.remote" 2>/dev/null || true)

if [ -n "$PARENT_REMOTE" ]; then
  # If the current branch has a remote, we can set the backup branch upstream to the same remote
  PARENT_REMOTE_PREFIX=$(git config user.name | sed 's/ /./g' | tr '[:upper:]' '[:lower:]')
  BACKUP_REMOTE_BRANCH="${PARENT_REMOTE_PREFIX:+$PARENT_REMOTE_PREFIX/}$BACKUP_BRANCH"
  git config "branch.$BACKUP_BRANCH.remote" "$PARENT_REMOTE"
  git config "branch.$BACKUP_BRANCH.merge" "refs/heads$BACKUP_REMOTE_BRANCH"
fi

# If --push was passed, push the new branch
if [ "$should_push" = true ]; then
  echo "Pushing '$BACKUP_BRANCH' to remote..."
  git push --set-upstream "$PARENT_REMOTE" "$BACKUP_BRANCH:$BACKUP_REMOTE_BRANCH"
fi
