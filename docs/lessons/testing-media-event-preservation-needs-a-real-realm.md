# Testing: Media event preservation needs a real realm

**Date**: 2026-10-27
**Lesson**: A fake task queue does not supply the engine realm that a rooted media event requires.

**Why**: Media runtime Event.take retains both the event and target through engine.retainValue. That protocol operation wraps platform objects in their relevant realm. A ContextData with no engine cannot satisfy the contract, even if its event-loop vtable accepts tasks.

**What Happened**: A selector preservation test called HTMLMediaElement.set_muted using an engine-free DOM context and a bounded queue with drop cleanup. Event construction failed before anything reached the queue; the Event's type string leaked because releaseIfUnwrapped deliberately leaves no-engine instances alone. Changing the queue cleanup could not fix a failure before handoff.

**Fix**: Keep engine-free snapshot/default-state assertions in the native DOM fixture. Exercise muting and volume setters through the existing Browser Page helper on a fresh thread, using std.testing.allocator. A detached video with no src or playback is enough; read selectors immediately and let Browser teardown own queued events. Do not change the runtime's ownership contract to accommodate the fixture.

**Takeaway**: **Before substituting a test queue, check whether constructing the queued object already requires the real engine host.**
