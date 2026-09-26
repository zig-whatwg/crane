# Codegen: Callback FUNCTIONS cannot move to CallbackWrapper until the registry is real

**Status (2026-09-25)**: the registry is real now - `register` tracks and `cleanupForContext` resets a torn-down context's callbacks (0100e3e5b), and callback wrappers own their context (ef7e6e2fa). The ordering below still holds for the migration itself: measure the teardown race before relanding the generator change.

**Date**: 2026-09-21
**Lesson**: `src/runtime/engines/v8/callback_registry.zig` is a 20-line stub whose
two functions are both no-ops, so every `CallbackWrapper` ever created leaks.

**Why**: WebIDL has two callback kinds and codegen treats them differently.
Callback *interfaces* (EventListener, NodeFilter) generate as
`?*runtime.CallbackWrapper` and work. Callback *functions* generate as a bare
`*const fn`, which `conversions.zig:1209` satisfies by TAGGING the V8 function
pointer. Nothing can be called through that, so
`CustomElementConstructor = *const fn () *runtime.Instance` means `super()` can
never work - `custom-elements/CustomElementRegistry.html` sits at 8/46.

Migrating callback functions onto `?*runtime.CallbackWrapper` is the right fix
and the generator change is ~10 lines. It was written, measured, and reverted
TWICE. The reason is not the 26 compile errors it surfaces - those are
mechanical, and `callback_wrapper.zig:53` exposes exactly the
`callback_function_global: ?GlobalHandle` that `extractEventHandler` needs.

**What Happened**: the blocker is ownership, and it is one level down.

    today   el.onclick = fn   tags a pointer. NO allocation. The impl owns
                              and disposes its one Global handle.
    after   el.onclick = fn   allocates a wrapper + 2 Global handles, and
                              `callback_registry.register` DISCARDS its
                              argument, so nothing frees any of it.

So the migration converts a correctly-disposed hot path into a per-assignment
leak. `cleanupForContext` is never called from anywhere in `src/`, and only 2
sites call `register` at all.

Fixing the registry first is the obvious move and runs straight into the other
wall: cleanup has to happen at context teardown, and added work in
deinit/onObjectFreed has cost 2-3 crashes per 6 WPT runs, proven three ways.
The 0.1 gate is ZERO crashes.

**Fix**: the ordering is registry -> teardown race -> migration, and the
teardown race is the real blocker. Do NOT reland the generator change before
`register` tracks and `cleanupForContext` frees. The reverted generator lives
at `.claude/jobs/2e30a6c4/tmp/generator-callbackwrapper.zig`.

**Takeaway**: **When a change is mechanical but keeps getting reverted, the
blocker is under it, not in it.** Two reverts were spent on the 26 compile
errors before anyone read the registry it was migrating onto.
