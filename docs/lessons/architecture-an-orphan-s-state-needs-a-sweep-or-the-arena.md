# Architecture: An element's own state block needs a registry and a sweep, or it leaks for every orphan

**Date**: 2026-10-16
**Lesson**: SVGScriptElement kept its state with `allocator.create` and no teardown sweep, so every SVG script dropped while unwrapped (innerHTML = '' over `<svg><script>`) leaked its state - and, for a document-parsed one, its script text.

**Why**: An orphan - a node removed from its tree while script held no wrapper of it - is reached by no tree teardown and no collector until refcounting lands (lesson architecture-an-element-alive-at-teardown-is-swept-not-deinitd). Its only exit is its type's sweep at the Browser's end (`dom.teardown_sweeps`), which frees what each remaining registry entry owns. A block outside every registry has no exit at all.

**What Happened**: Codex row 41 (Q19/D16) counted one `leaked:` line on crane/san-svg-detach-innerhtml and -sethtmlunsafe and none on -removechild, on frozen main. The two paths remove nodes the same way (`dom.mutation.remove`); the removeChild control is clean only because `removeChild(x)` wraps its argument, so the wrapper's collection runs the deinit. tests/html/fraginert_svg_script_orphan_test.zig reproduced it under std.testing.allocator (4 leaks).

**Fix**: SVGScriptElement's state is a registry entry in the Browser's arena (`runtime.InstanceRegistry(.svg_script_element, ...)`, `Registry.createIn(instance, runtime.arenaOf(instance))`), deinit'd and removed by deinitOwn, and its sweep (`.script_elements` phase) frees every remaining entry's script text - HTMLScriptElement's shape.

**Takeaway**: **An element impl that keeps a state block of its own needs both exits: a registry entry (in the arena) that its deinit removes, and a teardown sweep for the orphans no deinit reaches. Test a leak fix with an unwrapped node dropped by innerHTML, not with removeChild, which wraps.**
