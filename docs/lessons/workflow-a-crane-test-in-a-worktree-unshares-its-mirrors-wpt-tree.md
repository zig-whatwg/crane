# Workflow: A Crane test written in a worktree unshares its mirror's WPT tree

**Date**: 2026-10-30
**Lesson**: A pool mirror shares main's WPT tree only while its worktree has no WPT checkout. The test for that has to ignore crane/, or one Crane test written in the worktree replaces the whole shared tree on the mirror.

**Why**: A worktree has no initialised tests/wpt submodule. So tmp/remote/crane-remote.sh links each mirror's tests/wpt to the host's shared ~/crane-work/main/tests/wpt, whose crane/ is fed from the MAIN checkout. Its test was "the worktree's tests/wpt is empty".

**What Happened**: Codex row 128 wrote om1-box-reification.html into its worktree's tests/wpt/crane/ (D524). The next sync saw a non-empty tests/wpt. It stopped excluding the tree, and on chat.local it replaced the mirror's symlink with a directory holding only crane/. In the row's final native gate, 73 of main's native decoder tests failed (Q216): the font, image and media fixtures they read through tests/wpt were gone. The source and the shared tree were both fine.

**Fix**:
1. crane-remote.sh now treats a tests/wpt holding only crane/ and dotfiles as "no checkout". It warns that those Crane tests belong in the main checkout.
2. On the host, it relinks a mirror's tests/wpt whenever that is a real directory holding only crane/.
3. Crane tests go in the MAIN checkout's tests/wpt/crane/ (the lane brief template already says so). A copy in a worktree is never synced.

**Takeaway**: **A "does this directory exist / is it empty" test that decides whether to share a tree must define its emptiness by what makes the tree real, not by any file at all.**
