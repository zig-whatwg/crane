# Workflow: crane-remote syncs your tree when the job is placed, not when you start it

**Date**: 2026-11-27
**Lesson**: A red run made by checking a fix out, starting `crane-remote.sh`, and putting the fix back after a fixed wait can run the GREEN tree: the worktree is copied to the host only when the job gets a build slot, which can be minutes after the command starts.

**Why**: `crane-remote.sh` queues on the Mac until a host has a slot (it prints "no room for <mirror> yet ... queued", or waits up to 15 minutes for a warm host), and only then rsyncs the worktree to the mirror and prints `job pid <n> on <host>`. Until that line, the job has not read a single file.

**What Happened**: Lane gate2 saved its site fix as a patch, checked the files out to the red test commit, started the red run in the background, and re-applied the patch after a 120-second loop that waited for `job pid` but gave up instead of failing. The pool was busy (chat.local overloaded, server1 in a timed window), the job was still queued, and the fix was back in the worktree before the sync: the "red" run would have built the green tree. The still-queued job was killed before it was placed, and the red run was started again.

**Fix**:
1. Start the red job with its output to a file (`crane-remote.sh <mirror> '<cmd>' > tmp/red.out 2>&1`, in the background).
2. Wait with ONE background command that ends only when the job was placed or ended: `until grep -q "job pid\|^rc=" tmp/red.out; do sleep 5; done` - no timeout that falls through.
3. Only then re-apply the patch (or move off the WIP commit).
4. Better still, when the pool is busy: commit the red test on its own and the fix after it, and run the red job on the red commit while you do nothing to the worktree but read.

**Takeaway**: **The tree a pool job builds is the worktree at the moment `job pid` is printed. Do not touch the files a red run must see until that line, and never let the wait for it time out into the next step.**
