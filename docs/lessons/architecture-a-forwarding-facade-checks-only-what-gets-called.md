# Architecture: A forwarding facade checks only what gets called

**Date**: 2026-09-26
**Lesson**: The engine protocol's forwarding functions check an adapter's signatures only for operations something calls, and never catch a mismatch Zig converts implicitly - so the facade needs a comptime conformance check over every operation.

**Why**: Zig analyses lazily: a `pub inline fn` nobody calls is never compiled, so its forwarding call never meets the adapter's function. And a forwarding call type-checks through Zig's implicit conversions - an adapter taking `*const Agent` accepts the facade's `*Agent` argument - so a drifted signature compiles.

**What Happened**: The protocol spike demonstrated four deliberate breaks. A missing `runTaskInRealm`, the old table's `Error!JSValue` return instead of `Owned`, and a wrong parameter type failed at the forwarding call; the `*const Agent` for `*Agent` mismatch compiled until the spike added a conformance block comparing each adapter function's type to the protocol's.

**Fix**: `engine_protocol.zig` runs a comptime check on every use: for each operation, the adapter must declare a function of exactly the protocol's type. Rule: every `pub inline fn` in the facade is an operation, so the check can enumerate them.

**Takeaway**: **A contract checked only by calls is checked only where called; check the whole interface at comptime, by exact type.**
