# git-backup

Minimalistic fire-and-forget backup tool that uses a git remote as a backup server.
Every backup creates (and pushes) a new commit on a separate branch without altering the local ancestry or working copy.  

## Example

```bash
$ git-backup --push
Created backup commit 2e84d986188126e08f60896684cf19ae7bede88c on branch 'backup/main'.
Pushing 'backup/main' to remote...
Enumerating objects: 6, done.
Counting objects: 100% (6/6), done.
Delta compression using up to 22 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 528 bytes | 528.00 KiB/s, done.
Total 4 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To github.com:LinqLover/git-backup.git
 * [new branch]      backup/main -> christoph.thiede/backup/main
```

## Synopsis

```
Usage: git_backup.sh [--push] [BACKUP_BRANCH]
Backs up *all* unstaged changes into a new commit on a dedicated backup branch
without altering your real index or working directory.

If BACKUP_BRANCH is not specified, defaults to backup/<currentBranch>.

Options:
  --push      Push the backup branch immediately after creating the commit.
  -h, --help  Show this help message.

Examples:
  git_backup.sh
  git_backup.sh my-backup-branch
  git_backup.sh --push
  git_backup.sh --push my-backup-branch
```
