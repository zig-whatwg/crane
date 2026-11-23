# Debugging: A removal that takes several entries invalidates every index

**Date**: 2026-11-21
**Lesson**: When removing one entry can remove others too (a target with its partner, a session with its children), a loop over the list by index reads past its end; find the next victim afresh after each removal instead.

**Why**: `removeTarget(page, with_partner)` drops the page target AND its tab target; `detach(session)` drops the session AND every session it auto-attached. A backward index walk assumed one entry per step, so after a pair went, `items[i - 1]` was out of bounds.

**What Happened**: Target.disposeBrowserContext - which ends every Playwright test - panicked in Server.disposeContext (lane cdpr's conformance trace, G12). Three other loops (removeTarget's sessions, a connection's end, the server's stop) carried `if (i >= len) continue` guards that hid the same assumption.

**Fix**: `while (self.lastTargetOf(context)) |t| self.removeTarget(t, true);` and `while (self.lastSessionWhere(key, matches)) |s| self.detach(s, ...)` - each removal is followed by a fresh search, newest first, with no index carried across it (src/devtools/server.zig).

**Takeaway**: **If the removal call can cascade, never iterate the list by index around it: loop "find one, remove it" until none is found.**
