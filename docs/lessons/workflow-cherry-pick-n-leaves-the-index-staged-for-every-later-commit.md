# Workflow: `git cherry-pick -n` leaves the index staged for every later commit

**Date**: 2026-11-14
**Lesson**: After `git cherry-pick -n`, the picked change sits in the index. A later `git add <paths> && git commit` commits those paths AND everything the cherry-pick staged, under the new commit's message.

**Why**: `git add <paths>` only adds to the index; `git commit` without paths commits the whole index. `cherry-pick -n` is "apply and stage", so its files stay staged until something commits them.

**What Happened**: Lane nav2 batch 12 re-applied the reverted end-of-parse commit with `git cherry-pick -n edffbee5a4e`, edited further, then committed in logical units with `git add <files>; git commit`. The first unit ("a document's setup before its parse") silently carried the whole synchronous-load change and four test files; the commit that was meant to hold them showed 9 lines. The branch was rewritten (`git reset --soft <base>; git reset`) and committed again.

**Fix**: After a `cherry-pick -n` (or any staging you did not do on purpose), run `git reset` to unstage before committing in units, or commit with explicit paths (`git commit -m ... -- <paths>`), and read `git show --stat HEAD` after each commit.

**Takeaway**: **A commit is the index, not the paths you just added: unstage a `cherry-pick -n` first, and check `--stat` after each logical commit.**
