# Workflow: A diff against `main` names other lanes' work once main moves

**Date**: 2026-11-16
**Lesson**: A file list or a reverse patch made with `git diff main` from a lane branch is the lane's change only while main is where the branch left it; after another lane merges, it also holds that lane's files, backwards.

**Why**: `git diff main HEAD` compares two trees. A lane branch cut from main at B and not yet re-merged differs from today's main by its own commits AND by everything main gained since B. Lane nm3 made two things that way two hours after branching: its verify list (`git diff --name-only main..HEAD -- tests`) and the reverse patch a base console is built from (`git diff -R main -- src tools tests`). Three lanes had merged meanwhile.

**What Happened**: The verify step failed with rc 1 after a 55-minute native step, on two paths that were not tests of the lane at all (`tests/html/wc1_subtle_settles_test.zig`, which the lane's tree did not have, and the `tests/wpt` gitlink). The base console's patch did not apply in the mirror ("tests/wpt: wrong type") after the tip's console had built for 11 minutes, so the job had to be placed again. Neither cost a wrong number - both failed loudly - but each cost a pool job.

**Fix**:
1. Merge main into the lane branch FIRST, then make the list and the patch: `git diff --name-only main HEAD -- tests | grep '_test.zig$'` and `git diff HEAD main -- src tools tests build.zig build.zig.zon` are then exactly the lane's change.
2. Or name the branch point: `git diff $(git merge-base main HEAD) HEAD`.
3. Before a job that takes a patch, check it on the Mac: `grep '^diff --git' <patch>` should list only files the lane changed.

**Takeaway**: **Merge main, then diff. A `git diff main` made before the merge is a statement about two branches, not about your change.**
