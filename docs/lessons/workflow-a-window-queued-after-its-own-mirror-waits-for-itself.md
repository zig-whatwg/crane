# Workflow: A window queued `--after` its own mirror waits for itself

**Date**: 2026-11-20
**Lesson**: `crane-pool.sh queue <host> <mirror> ... --after <mirror>` naming the SAME mirror, enqueued after that mirror's previous window has ended, holds the new window behind itself: `queue-list` shows it "after <mirror> (waits for it)" and the keeper never drains for it.

**Why**: `--after <owner>` means "not before that owner's queued or running window ends here", and the window being enqueued is itself that owner's queued window. The order you meant (run after my current window) is already given by first-come order and by the host running one window at a time, so `--after` on your own mirror adds nothing even when it works.

**What Happened**: The integrator told lane maj5 to queue its final cost window on chat.local with `--after maj5-c` ("your current window"), but that window had already ended. maj5 queued it at 2:58 PM ET, and the keeper held it for 53 minutes ("after maj5-c (waits for it)") while the host was free, until maj5 read the `queue-list` line. `queue-drop` and a re-enqueue without `--after` put it at position 1 at once. A queue fix is now in the window-queue tooling's queue: an `--after` naming yourself, or an owner with nothing queued, will count as met, and an `--after` that can never be met will ALERT.

**Fix**: Use `--after` only for ANOTHER owner's window (an integrator sweep, another lane's A/B). For a follow-on window of your own, enqueue it without `--after`. After every enqueue, read the `queue-list` line once: "(waits for it)" next to your own mirror's name means the window will never start.

**Takeaway**: **Never queue a window `--after` its own mirror: check `queue-list` once after enqueuing, and drop and re-queue any window that waits on itself.**
