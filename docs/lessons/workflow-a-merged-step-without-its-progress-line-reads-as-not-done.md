# Workflow: A merged step without its progress line reads as not done

**Date**: 2026-10-24
**Lesson**: Before starting a numbered step of a migration, look for it in the merge log. A step that merged without a line in its roadmap item's `progress` list looks unstarted to everyone who plans from the roadmap.

**Why**: The roadmap page (docs/roadmap.toml) is how the 0.1 scope, the lane queue and the briefs are planned. The DOM lifetime item's progress list recorded refcount steps 1-2 (rc12) and step 3 (rc3), but not step 4 (lane rc4, merged c56db978f7 on 2026-10-10) or steps 5b and 5h (lane rc5, merged 6fd7524b0a on 2026-10-11). The two merges said only "Merge branch 'lane/rc4'" and "Merge branch 'lane/rc5'", and the report lines that should have reached the roadmap never did.

**What Happened**: On 2026-10-24 the user put "refcount steps 4-7" in the 0.1 scope, and the integrator briefed lane refcount4 to do step 4, word for word as rc4's brief had (tmp/orchestration/briefs/rc4-work.md). The lane's first reads found every piece of the step in the tree: `runtime/lifetime.zig`, `CacheEntry.counted`, `joinOpaqueRoot` called from `dom/mutation.zig`, `installTreeHooks` gone, the docs/engine-protocol.md lines. A `git log --grep "refcount step 4"` then named the commits, and tmp/plans/lane-rc4-handoff.md said "Status: DONE". The lane stopped before building anything and was re-scoped to steps 5f and 5g. The roadmap was given the two missing lines in the same lane (5a5f86baf8).

**Fix**:
1. Starting a step: `git log --merges --grep <lane>` and `git log --grep "<plan> step N"` on main, and read the lane's handoff in tmp/plans/ if one exists. If the step is there, stop and tell the integrator before reading further.
2. Merging a lane that moves a roadmap item: add its progress line in the merge round (AGENTS.md "Keep the roadmap current" step 4), naming the merge and its main commits.
3. A merge commit's message names what the lane did, not only its branch: a later `git log --grep` finds the words, not the branch name.

**Takeaway**: **The roadmap is a plan only if every merge writes itself into it - check the merge log before re-doing a step, and write the progress line at merge time, not later.**
