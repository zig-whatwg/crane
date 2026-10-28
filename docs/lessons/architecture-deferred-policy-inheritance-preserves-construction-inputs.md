# Architecture: Deferred policy inheritance preserves construction inputs

**Date**: 2026-10-27
**Lesson**: When an origin resolves after document creation, a delayed policy calculation must use the inputs captured at creation.

**Why**: Permissions Policy §9.5–9.7 derives a document's inherited feature values from its parent's policy, the container attributes and the new origin. Crane can construct an iframe document with an unresolved OriginRecord. Its parent or allow attribute can change before the first policy query.

**What Happened**: The old policy module retained a borrowed parent-policy pointer and recomputed inheritance recursively. The document factories also permit unresolved origins. The integrator required their existing creation behavior to remain intact (codex-fetchlater Q24/Q25), while the new policy record captures everything needed for the eventual calculation.

**Fix**: Calculate inherited values immediately when the origin is known. Otherwise resolve the parent's actual policy first, then copy its effective enforcing policy, the container declarations and construction-time origin-domain values into an owned snapshot. Preserve opaque identity with the existing native OriginRecord hold. At first use, complete the captured child's origin serialization, calculate inherited values once, finish response-policy construction and free the snapshot. Document destruction also frees an unresolved snapshot. Tests cover parent destruction, later allow/domain changes and every allocation failure.

**Takeaway**: **Delaying a calculation must preserve the time at which its inputs were defined.**
