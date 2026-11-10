# Workflow: crane-pool.sh wpt runs in the mirror as the last crane-remote job left it - a new script needs a sync

**Date**: 2026-11-10
**Lesson**: `crane-pool.sh wpt <mirror> '<cmd>'` runs `<cmd>` in `~/crane-work/<mirror>` on the host without copying the worktree there; only `crane-remote.sh` syncs it. A script written after the last crane-remote job is not on the host, and the run fails at once with "No such file or directory".

**Why**: A WPT run must not rewrite the tree its own runners read, and it may run beside a crane-remote job of the same mirror (`beside`), so the pool moves a mirror's state between hosts (pool_follow) but never pushes the worktree for a run.

**What Happened**: Lane h1 wrote .h1/after.sh during its own server1 window, after window.sh had finished, to rerun a NEW build difference x10 on both bug-finding runners and to resample /proc/<pid>/maps. `crane-pool.sh wpt h1-l --pair generation ...  'bash .h1/after.sh'` answered `bash: .h1/after.sh: No such file or directory` (exit 127). A crane-remote job would have synced it, but it takes a build slot inside the window.

**Fix**: Pass a short script inside the command itself: `B=$(base64 < .h1/after.sh | tr -d '\n'); crane-pool.sh wpt <mirror> ... "echo $B | base64 -d > .h1/after.sh && bash .h1/after.sh"`. Or write every window script before the gate's crane-remote job, which syncs them with the tree.

**Takeaway**: **A pool WPT run sees the worktree as the last crane-remote job copied it: write window scripts before that job, or carry a late one in the command.**
