# Workflow: A pathspec commit takes the whole file - another agent in the worktree may have edited it

**Date**: 2026-11-09
**Lesson**: `git commit -- <paths>` commits each path's whole working-tree content, so with a helper agent editing the same worktree, a file you check and then commit seconds later can carry the helper's hunk.

**Why**: The pathspec form ignores the index for the named paths and reads the files as they are at that instant; nothing tells you a hunk appeared between your `git diff` and your commit.

**What Happened**: Lane wptcfg batch 1 committed its runner split (bf95bdb99f8) with `-- build.zig ...` minutes after checking build.zig held only its own changes. In between, the D1/D2 helper added `"image_decoding"` to `platformBinding`'s kit_parts, so the commit named a kit part whose files were not in it: that commit alone does not build. The next commit (the helper's) completes it.

**Fix**: Before a pathspec commit in a shared worktree, run `git diff -- <paths>` in the SAME command as the commit and abort if it holds a hunk you do not recognise - or have helpers stop editing while you commit, or give each helper a worktree of its own and merge it.

**Takeaway**: **In a worktree two agents edit, diff and commit in one command, or a file you checked can carry the other agent's half-finished hunk into your commit.**
