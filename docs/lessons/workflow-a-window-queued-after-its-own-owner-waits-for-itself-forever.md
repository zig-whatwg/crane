# Workflow: A window queued after its own owner waits for itself forever

**Date**: 2026-11-24
**Lesson**: `crane-pool.sh queue ... --after <owner>` waits for THAT owner's queued or running window on the host; given the window's own mirror, it waits for itself and never runs, while every later window goes ahead of it.

**Why**: The keeper reads `--after` as "not before that owner's window here ends", and the window it is asked about is one of that owner's queued windows - its own. Nothing ever ends it. The queue does not refuse the flag, and `queue-list` only says "after cs1-l (waits for it)", which reads like a normal wait.

**What Happened**: Lane cs1 queued its targeted A/B on server1 with `--after cs1-l` (meaning "after my own gate build", which needs no flag: a window's drain already waits for the host's running builds). The window sat for 256 minutes; hard1b-l and bind1-l were handed server1 before it, and the integrator found it from the queue list. Dropped (`queue-drop server1 cs1-l`) and queued again with no `--after`.

**Fix**:
1. Use `--after` only with ANOTHER owner whose window must end first.
2. To run after your own build job, queue with no `--after`: the drain waits for every running build on the host, yours included.
3. After queuing, read `queue-list <host>` once: a line with "after <your own mirror>" is this mistake.

**Takeaway**: **`--after` names another lane's window, never your own; a window's drain already waits for your builds.**
