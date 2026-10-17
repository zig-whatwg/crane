# Workflow: A queued remote job builds the mirror as its slot finds it

**Date**: 2026-10-17
**Lesson**: crane-remote.sh syncs a lane's mirror when the job is submitted, then waits for a build slot; until the slot comes, a plain `rsync` of the worktree into the mirror makes the queued job build the newer tree - no resubmission, no lost place in the queue.

**Why**: Build slots are first-come-first-served tickets (2026-10-17), and with five long-held slots a job can wait an hour. Cancelling a queued job to submit one with newer sources sends it to the back of the queue. The job's command reads the mirror only once it starts.

**What Happened**: Lane sw1-b4 submitted a unit-test job, kept coding for 40 minutes while it waited first in the queue, and then needed the newer code built. It re-ran the job's rsync line by hand (same excludes, `/tmp` and `/tests/wpt` protected) before the slot came; the job built and tested the newer tree. Twice more the same way, including a gate that then covered a whole new item.

**Fix**: while the job holds no slot (`ls ~/crane-slots/*/holder` shows no line with the mirror's name), run crane-remote.sh's own rsync (`--delete`, excluding `/.git /.claude /zig-out /.zig-cache /tmp /wpt-results /jsengines/v8 /tests/wpt`). Never once it holds a slot: a sync under a running build rewrites its sources mid-compile (the 2026-09-30 clobbered gate).

**Takeaway**: **Before its slot comes, a queued job's mirror is still yours to update - sync it instead of resubmitting; after, never touch it.**
