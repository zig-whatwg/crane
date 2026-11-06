# Workflow: A staged deletion rides into the next commit of other paths

**Date**: 2026-11-04
**Lesson**: `git rm` stages the deletion at once; a later `git add <some files> && git commit` commits it too, whatever paths were named.

**Why**: `git commit` commits the whole index, not the paths just added. A file removed with `git rm` while other work is in progress is already in the index.

**What Happened**: lane loadpath1 deleted src/browser/navigation.zig with `git rm` while rewriting the load path, then committed two revised RED test files with `git add tests/... && git commit`. The deletion went into the RED commit. The RED run's snapshot worktree, checked out at that commit to test the new tests against the BASE source, had a base Context.zig importing a file that no longer existed - the pool job synced the broken tree and had to be killed and requeued (about 25 minutes of a contended build slot).

**Fix**: `git reset --soft` to before the commit, `git restore --staged .`, then add and commit the test files alone and the source change after. A RED job's script now checks a base file exists before it builds.

**Takeaway**: **Before committing a subset of the work, read `git status`: a deletion staged earlier is committed with whatever you add - stage deletions only in the commit that needs them (or use `git commit <paths>`).**
