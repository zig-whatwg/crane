# Workflow: A lane inside a long command cannot see a closing notice

**Date**: 2026-10-25
**Lesson**: A lane agent learns about a timed window only when it next reads the coordination file, so a lane waiting inside a long command runs through the notice; a local watcher that sets its STOP file is what stops it in time.

**Why**: Timed cost series need a quiet chat.local. The liaison announces each window with a CLOSING NOTICE line in tmp/plans/held-files.md, and every lane is told to stop at its next boundary and post PAUSED. But an agent reads that file only between its own tool calls. While it waits on a background job or a long remote build, nothing tells it a notice appeared. A crane-remote build job also outlives the tmux session or script that started it.

**What Happened**: On 2026-10-25 it happened twice in one day.
- refcount4 misread a WINDOW OPEN line as GAP OPEN and restarted its untimed WPT chain inside row 119's timed window. Its driver checked STOP only between whole steps, so it moved on to the next chunk. The integrator killed the chain 20 minutes later.
- leaks7 was inside a remote `zig build test` gate and a leak run when cascadefast1's notice went out. It posted nothing for 10 minutes, so the integrator killed the gate. Its tmux session had already ended, but the crane-remote job kept building.
Neither run spoiled a measurement, because the series had not started. Both delayed a window by 10-20 minutes.

**Fix**:
1. Before its first chat job, a lane starts a local background watcher. The watcher creates the lane's STOP file as soon as a new line containing "CLOSING NOTICE" appears in held-files. A watcher that exits after firing is re-armed at once, chat work planned or not: vars1's fired on one notice and was not running for the next.
2. Every chat script checks STOP before each job and each chunk, and exits cleanly when it is set.
3. The lane's stop also kills its crane-remote jobs on chat (`ssh chat.local kill <pid>`), not just the local tmux or script.
4. The lane resumes only on a held-files line that BEGINS with "GAP OPEN". The liaison posts GAP OPEN only as such a line.
5. The integrator stops a lane that has not paused 10 minutes after a notice. The lane reruns the killed job from scratch and never keeps a partial result.
The lane brief template (tmp/orchestration/brief-template.md) now carries steps 1-4.

**Takeaway**: **A lane cannot react to a notice it has not read: give every lane a watcher that sets STOP the moment a CLOSING NOTICE appears, and make its stop kill the remote job too.**
