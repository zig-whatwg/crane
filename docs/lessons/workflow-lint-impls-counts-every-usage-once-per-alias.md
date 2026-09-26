# Workflow: lint-impls counts every usage once per local alias

**Date**: 2026-09-26
**Lesson**: In a file that binds a non-ancestor impl locally in several functions (`const EventImpl = @import("Event.zig");` six times in EventTarget.zig), adding one more such binding raised EVERY `EventImpl.member` count in the file by one - `Event.clearPath: allowed 6, found 7`, listing the same line seven times - and failed `zig build test` with 16 keys above the baseline.

**Why**: the impls-boundary lint counts a usage once per alias declaration of that name in the file, so the file's counts scale with how many functions bind the alias. The baseline recorded the old multiple.

**Fix**: add no new binding. Route the new path through a function that already holds the alias - `dispatchTrusted` and `call_dispatchEvent` both delegate to one `dispatchEventWithTrust`, which keeps the single existing `EventImpl` binding. Check with `grep -c '@import("X.zig")' file` before and after.

**Takeaway**: **Before binding a non-ancestor impl in one more function, count the file's existing bindings - the lint multiplies by them. Better still, reach it through an interface or hook, which the lint does not count at all.**
