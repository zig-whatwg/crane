# Architecture: An errdefer that outlives the handoff frees what the new owner will free

**Date**: 2026-09-26
**Lesson**: `startConnect` stored its curl handles in the connection and then polled with its errdefers still armed.

**Why**: Once ownership moves, an armed errdefer and the new owner both free the same thing on the next error.

**What Happened**: A connection failure after the handoff double-freed the handles.

**Fix**: End the errdefer scope where ownership moves (a block, or move the store to the last step).

**Takeaway**: **End the errdefer scope where ownership moves.**
