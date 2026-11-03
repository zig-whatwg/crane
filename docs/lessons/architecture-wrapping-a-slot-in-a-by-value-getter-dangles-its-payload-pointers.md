# Architecture: Wrapping a slot in a by-value getter dangles its payload pointers

**Date**: 2026-11-02
**Lesson**: Moving a global from a plain `var` to an accessor type (`slot.get()`) is a mechanical rewrite everywhere except where code took a POINTER into the old variable: `if (slot) |*payload| return payload;` became a pointer into the getter's temporary copy.

**Why**: Zig's `if (x) |*p|` captures a pointer into `x` when `x` is an lvalue. `x.get()` is an rvalue - a copy on the caller's stack - so the same capture now points at that copy, which dies when the function returns. It compiles, passes every test that reads the result at once, and reads garbage later. Nothing in a regex rewrite (`x orelse` -> `x.get() orelse`) tells the two forms apart.

**What Happened**: Lane hookfreeze1 converted the 73 class-H hook slots to `dom.Hook(T)` with a scripted rewrite. `range_boundaries.liveRange()` returned `?*const LiveRange` with `if (live_range) |*impl| return impl;` - a pointer into the process-wide slot that the live-range steps keep for a whole mutation. The rewrite produced `if (live_range.get()) |*impl| return impl;`. It was caught by grepping the rewritten files for `.get()) |*` before the first build, not by a test. The same rewrite turned `parser_steps.?.link_created = x` into an assignment to a field of a copy (`parser_steps.get().?.link_created = x`), which writes nothing.

**Fix**:
1. The type has two readers: `get()` (a copy, for values used at once) and `read()` (a `*const T` into the slot, for anything kept or iterated in place). A pointer capture uses `read().*`: `if (live_range.read().*) |*impl| return impl;`.
2. Writes in place go through `installing()` (a `*T` under the same permission check), never through `get()`.
3. After a scripted rewrite, grep for the forms that change meaning: `.get()) |*`, `&x.get()`, `.get().<field> =`, `.get().?.<field> =`.

**Takeaway**: **When a variable becomes an accessor, every pointer capture and every field write through it changes meaning: give the type a borrowing reader and an in-place writer, and grep the rewrite for `|*`, `&` and `=` on a getter before trusting it.**
