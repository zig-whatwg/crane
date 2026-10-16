# Architecture: An owned timer's drop is the turn's end, not a free

**Date**: 2026-10-15
**Lesson**: When the data a timer carries is shared - a token the socket also points at - the timer's `drop` must run the ownership rule's "turn ended" exit (free only what the rule says is the turn's), not free the data outright.

**Why**: `setTimeoutOwned(.., drop)` exists for the timer whose loop ends before it fires ([A task queued on a loop that never runs again leaks its data](architecture-a-task-queued-on-a-loop-that-never-runs-again-leaks-its-data.md)). For data the task alone owns, `drop` is a free. The WebSocket pump token is not that: it is owned by the scheduled turn, the running turn or the socket, by state ([A token armed during its own turn belongs to that turn](architecture-a-token-armed-during-its-own-turn-belongs-to-that-turn.md)). A drop that freed it while the socket still pointed at it would turn a leak into a use-after-free at the socket's teardown.

**What Happened**: `PumpToken.arm` used a plain `setTimeout`. A worker's end makes its sockets disappear (detach: the scheduled turn now owns the token) and then `WorkerEventLoop.deinit` ends its timers without firing them, so the turn that would have freed the token never ran: 2 x 64 B per worker socket under `leaks --atExit` (websockets/constructor.any.js and Create-on-worker-shutdown.any.js: 4 leaks / 2,703,520 B, against the snapshot pair's 2 / 2,703,392). Codex row 40's review traced it (tmp/analysis/review-codex-websocket2.md, D10).

**Fix**: `arm` uses `setTimeoutOwned` with `PumpToken.dropTurn`, which is the turn's end without its steps: `armed = false`; free the token only if the socket went and no turn is running; otherwise the socket gets it back and its `detach` frees it. `dropTurn` also records that the timer ended, and `arm` never schedules on an ended timer again (its manager is freed). A timer that arms nothing (0) leaves the token unarmed, the socket's. Four fake-timer tests in src/websocket/pump_token.zig, each red (leaking) before.

**Takeaway**: **Before writing a drop, ask who else points at the data. A drop is one more exit of the ownership rule: write it as the rule's exit for "the turn ended" and test it with the timer ending both before and after the other owner lets go.**
