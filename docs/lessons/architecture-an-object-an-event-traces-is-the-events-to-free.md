# Architecture: An object an event traces is the event's to free

**Date**: 2026-11-20
**Lesson**: A natively made object handed to an event that keeps it by a traced edge (a DragEvent's dataTransfer, a ClipboardEvent's clipboardData) must not be released with `releaseIfUnwrapped` after the dispatch: release the event, and let the edge decide.

**Why**: `releaseIfUnwrapped` frees an object that has no wrapper of its own at once, whatever points at it. A listener that keeps the EVENT (its wrapper) but never read `event.dataTransfer` leaves the DataTransfer unwrapped; freeing it then leaves the kept event pointing at a freed slot, and a later `event.dataTransfer` reads it. `engine.traceChild` holds the child strongly until the owner's wrapper exists, and the owner's teardown lets that hold go (`forgetTracedChild`), so the event alone is the right handle.

**What Happened**: Lane dnd1's first "fire a DND event" released both the DragEvent and its per-event DataTransfer after dispatch. Reading `releaseIfUnwrapped` and execcommand/clipboard.zig (which releases only the ClipboardEvent) showed the use-after-free before it shipped.

**Fix**: Read what the event's listeners left (effectAllowed, dropEffect) and break the DataTransfer's association while the event still holds it, then release the event only. Release the child yourself only on the path where no event was made.

**Takeaway**: **Whoever owns the traced edge owns the child: release the owner, never the child, once the edge exists.**
