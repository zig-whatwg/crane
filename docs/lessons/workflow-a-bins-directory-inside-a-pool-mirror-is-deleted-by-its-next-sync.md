# Workflow: A bins directory inside a pool mirror is deleted by the mirror's next sync

**Date**: 2026-11-09
**Lesson**: crane-remote.sh syncs a worktree to its mirror with deletion, so a directory you create inside `~/crane-work/<mirror>/` (frozen runners, say) is gone after your next build job; only the excluded paths (zig-out/, tmp/) and the sibling `~/crane-work/<mirror>-bins` survive.

**Why**: The sync makes the mirror equal to the worktree; a path the worktree does not have is extra, and extra is deleted. zig-out/ and tmp/ are excluded from the sync, and `<mirror>-bins` lives beside the mirror, not in it.

**What Happened**: Lane wptcfg batch 1 froze its tip runners into `~/crane-work/wptcfg-l/wptcfg-l-bins/tip2` and `tip3` with SHA256SUMS, ran a test job (crane-remote) in the same mirror, and the next WPT script refused: "wptcfg-l-bins/tip2 SHA256SUMS do not match" - the directory no longer existed. tip3 survived only because zig-out/bin still held the same binaries.

**Fix**: Freeze into `~/crane-work/<mirror>-bins/<tag>/` (the sibling crane-remote carries between hosts), and give a window script's red side a binary that cannot vanish (a generation's frozen runner in ~/crane-frozen when it has the bug).

**Takeaway**: **Never keep frozen binaries inside a pool mirror: its next sync deletes them; freeze into the sibling `~/crane-work/<mirror>-bins/`.**
