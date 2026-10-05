# Architecture: An element alive at teardown is swept, not deinit'd

**Status** (2026-10-05, leaks3): the in-document case is gone. The realm's end tears its document down through each element's own deinit (`deinitNodeByType` dispatches on the vtable), so an input still in its document frees its value in its deinit; the input's sweep freed nothing over 2,881 files and was retired. What still reaches the browser's end is an ORPHAN - a node removed while unwrapped, or whose wrapper was collected while it was in a tree - which no exit frees (1,632 nodes over the same files); the sweeps that remain cover those, and the lazily filled maps' runtime boundary (`src/dom/teardown_sweeps.zig`).

**Date**: 2026-09-29
**Lesson**: `HTMLInputElement.set_value` was reported as leaking "one dupe per call". It did not: the input's `deinit` frees its value, but an input still in the document when the browser ends is never deinit'd one by one. Final teardown (`impls/cleanup.zig`, `cleanupAllDomRegistries`) sweeps Element's and HTMLElement's registries wholesale, and nothing swept the input's own table.

**Why**: Per-element state that owns heap memory has two exits: its `deinit`, when the wrapper is collected, and the teardown sweep, when it is not. A type that keeps state outside the swept registries - an input's dirty value, a textarea's raw value in its StateMap - leaks it whenever the element outlives the page. Arena-backed state hides this (the arena goes wholesale); a `ctx.allocator` dupe does not.

**What Happened**: `CRANE_LEAK_TRACES=1` on a Crane test that sets `value` on an in-document text input, a hidden input, a checkbox, a detached input and a textarea: two leaks from `HTMLInputElement.set_value` and one from `HTMLTextAreaElement.set_value`, on frozen main. The detached input's value was freed - its wrapper was collected and its `deinit` ran - and the in-document ones were not. In the rel-*-target files the input is `type=hidden`, whose value setter should not store a value at all: in the default value mode it sets the `value` content attribute.

**Fix**: `src/dom/teardown_sweeps.zig`, a hook a type with its own side table installs a sweep into (once, from its init); `cleanupAllDomRegistries` runs every installed sweep after Element's. HTMLInputElement's state records its allocator so the registry's `deinitAllAndClear` can free the value; HTMLTextAreaElement's StateMap entries record theirs. And input's value setter follows the value modes: only the value mode stores a value.

**Takeaway**: **Heap memory an element owns has two exits - its deinit and the teardown sweep - and a new side table must take both. Test a leak fix with the element still in the document at exit, not only with a detached one.**
