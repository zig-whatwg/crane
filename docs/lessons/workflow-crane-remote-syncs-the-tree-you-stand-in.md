# Workflow: crane-remote.sh syncs the tree you stand in, not the mirror's

**Date**: 2026-11-05
**Lesson**: `crane-remote.sh <mirror>` syncs `git rev-parse --show-toplevel` of the current directory into the mirror, so a lane's job started from the main checkout replaced the lane's mirror with main's tree, deleted the lane's untracked files there, and turned the mirror's shared tests/wpt link into a 1.1 GB copy.

**Why**: The script names the mirror but not the tree: it takes the source from wherever it runs. From the main checkout it rsyncs main's working tree with `--delete` (untracked files and all) and, because the main checkout has a full WPT checkout, it does not exclude `/tests/wpt`: rsync replaces the mirror's `tests/wpt -> ~/crane-work/main/tests/wpt` symlink with a directory and copies the tree into it. The remote side restores the link only when `tests/wpt` is empty or crane/-only, so the copy stays, and later jobs of that mirror read their own copy instead of the host's served tree.

**What Happened**:
- Lane chromeref2 (2026-11-04): a job started from the main checkout synced main's tree into its gate mirror chromeref1-gate (tmp/plans/lane-chromeref1-handoff.md, "Traps hit in batch 2").
- Lane timing1 (2026-11-05 14:52 UTC): a dry run of the measurement window's input checks, `tmp/remote/crane-remote.sh timing1-new 'DRY=1 bash .timing1/window.sh'`, run after a `cd` into the main checkout. It answered `bash: .timing1/window.sh: No such file or directory`: the sync had deleted the mirror's untracked `.timing1/` (the window script, the OLD tree's archive), copied main's untracked `.agents/` and `skills-lock.json` in, and left a 1.1 GB tests/wpt directory where the link had been. The host's shared tree was not written through (rsync replaces a symlink, it does not follow it without `-K`): `~/crane-work/main/tests/wpt` kept its 308 entries and its 2026-09-30 mtime. Deleting the copy (`[ -d tests/wpt ] && [ ! -L tests/wpt ] && rm -rf tests/wpt`) and running the job again from the worktree restored the link; the re-run's input checks passed.

**Fix**:
1. Start every crane-remote job from the lane's worktree: `cd /Users/bcardarella/projects/crane/.claude/worktrees/<lane> && .../tmp/remote/crane-remote.sh <mirror> '<cmd>'`, or through a wrapper that does the `cd` itself (timing1's tmp/timing1/job.sh).
2. The guard (integrator, 2026-11-05 15:23 UTC): crane-remote.sh now refuses a non-main mirror run from the main checkout (exit 2, `crane-remote: refusing: this runs in the MAIN checkout ...`); `CRANE_REMOTE_FROM_MAIN=1` overrides it for the rare deliberate case.
3. If a mirror was synced from the wrong tree: check `ls -ld ~/crane-work/<mirror>/tests/wpt` on its host. A directory where a link should be is a copy: remove it (only after `[ ! -L ]`), confirm the shared tree's entry count and mtime, and re-run from the worktree, which also deletes the stray files.

**Takeaway**: **A sync tool that takes its source from the current directory needs a guard, not care: name the tree you sync, and refuse the main checkout for a lane's mirror.**
