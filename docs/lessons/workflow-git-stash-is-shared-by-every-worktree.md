# Workflow: `git stash` is shared by every worktree of the repository

**Date**: 2026-10-11
**Lesson**: A lane stashed its changes so it could run a test against unmodified code, then queued `git stash pop` to run after a background job. The stash list belongs to the repository, not the worktree: `stash@{0}` at pop time can be another lane's work.

**Why**: Every worktree shares the repository's refs, and `refs/stash` is one of them. `git stash list` in a lane worktree showed ten entries from `main`, `lane/workers` and older sessions. A bare `git stash pop` pops whatever is on top. If another session stashes while a background command waits, the pop applies that session's changes to the wrong branch and drops them from the list.

**What Happened**: The idxfast lane wanted a red run of new tests against the base code. It ran `git stash push -- <src files>`, started a remote build of about 10 minutes, and chained `git stash pop` after it. Noticing the shared list, it stopped the local command before it reached the pop and popped by explicit reference (`stash@{0}`, checked to read "WIP on lane/idxfast"). The remote job kept running because crane-remote.sh ignores hangups, and its log was read on chat.

**Fix**: Do not stash in a worktree to get a base-code run. Instead, save the diff (`git diff -- src/ > patch`) and `git checkout -- <files>`. Start the remote job, wait until crane-remote.sh prints "job pid" (the rsync is done by then), then `git apply patch`. If you must stash, pop only by explicit reference after checking its message, never from a command that runs later.

**Takeaway**: **The stash is repository-wide. In a multi-worktree checkout, a deferred `git stash pop` can apply another session's work, so carry base-code runs on a saved patch instead.**
