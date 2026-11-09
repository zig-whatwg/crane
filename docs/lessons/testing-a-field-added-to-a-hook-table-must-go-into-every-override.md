# Testing: A field added to a hook table must go into every override of it

**Date**: 2026-11-09
**Lesson**: `Hook(T).overrideForTest(replacement)` swaps the WHOLE table until `restore()`, so a field added to `T` reads as its default (null) in every test that overrides the table - and code that now depends on the new field fails only inside those tests.

**Why**: The override is the sanctioned way to spy on a process-wide hook (src/process/hook.zig), and a spy usually rebuilds the table from the fields it cares about: `overrideHooksForTest(.{ .acquire = acquire, .release = release, .forget = forget })`. That literal was complete when it was written. A field added later is left at its default there, silently - no compile error, no warning - and production paths that call through the new field reach a null hook.

**What Happened**: The wrapper redesign's P1 (lane wr1) added `slot_of` to runtime.lifetime's `Hooks`, installed by dom.refcount beside `acquire`/`release`, and moved the V8 adapter's reads of a node's wrapper slot behind `runtime.lifetime.slotOf`, which panics when no owner installed the hook. tests/v8/refcount_wrapper_link_test.zig tallies the wrapper link by overriding the table with its own acquire/release/forget: every wrap inside it would have reached `slotOf` with `slot_of == null`. A grep for `overrideHooksForTest` before the first build found it (the other overrides, tests/runtime/vtable_counted_test.zig, run the test adapter, which never wraps).

**Fix**: When adding a field to a hook table, grep for every `overrideForTest` / `override...ForTest` of that table and pass the owner's function for the new field (`.slot_of = dom.refcount.wrapperSlotOf`), or build the override from the installed table (`var t = hooks.get(); t.acquire = ...`) so later fields carry over. The redesign's P5 adds `traceTree` to the same table: the same grep applies.

**Takeaway**: **An override replaces the whole hook table: a new field reads null in every existing override until each one is updated - grep them when the table grows.**
