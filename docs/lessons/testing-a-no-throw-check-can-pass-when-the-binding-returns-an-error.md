# Testing: A no-throw check can pass when the binding returns an Error

**Date**: 2026-10-25
**Lesson**: Pair successful API calls with rejection and return-value checks before treating no exception as proof that validation succeeded.

**Why**: The implementation and its language binding are separate steps. A binding can turn a native error into a returned object instead of throwing it, making both successful and failed native calls satisfy a test that only requires no exception.

**What Happened**: The first CSS.registerProperty browser run passed all 129 valid syntax/initial-value cases and failed all 117 invalid ones with "did not throw". The implementation's native validation was working: the namespace callback passed its entire error union to a generic value conversion, which returned an Error object. Already-pending exceptions from property getters still propagated, so even some exception tests passed. The two paths needed to be distinguished.

**Fix**: Keep a minimal rejection test through the actual binding. Check the undefined return required by a successful void API. While the shared namespace fix was routed to its engine owner, run all 246 WPT syntax/value pairs directly against Registration.create with std.testing.allocator; this proved the validation outcomes without relying on the broken throw path. Preserve the exact dependent browser subtests for re-verification after the shared fix lands.

**Takeaway**: **A call that does not throw has not necessarily succeeded. Verify the binding's error path and the operation's observable result.**
