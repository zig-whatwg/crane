# Codegen: A partial interface's [SecureContext] is its members', not the interface's

**Date**: 2026-10-05 (ported 2026-10-16)
**Lesson**: The IR merged a partial interface's extended attributes into the interface's own, so `[SecureContext] partial interface Navigator { ... }` (webhid.idl and others) made Navigator - and, by its partials, Window - [SecureContext] themselves.

**Why**: WebIDL 3.3.13 scopes [SecureContext] on a partial interface (or an interface mixin) to the members that partial (or mixin) declares. Nothing read the attribute, so the wrong metadata sat unnoticed until the binding started honouring it - then a non-secure realm would have lost `Window` and `Navigator` outright.

**What Happened**: binding3's item 3 ([SecureContext] exposure) needed per-member exposure. Generated Meta showed `.{ .name = "SecureContext" }` on Window and Navigator; the members that should be hidden (navigator.locks from the [SecureContext] mixin NavigatorLocks, caches from a partial WindowOrWorkerGlobalScope) carried nothing.

**Fix**: `ir.withMemberScopedExtAttrs` pushes a partial's (and an included mixin's) [SecureContext]/[IsolatedContext] onto each member it declares and drops it from the interface; the writer lists `Meta.secure_context_members`. Pinned in tests/codegen/secure_context_members_test.zig.

**Takeaway**: **Before honouring an interface-level extended attribute, check that a partial or mixin did not put it there: some attributes scope members, not the interface.**
