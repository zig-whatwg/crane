# Codegen: A generated field can be read for its presence, not only its value - find those readers before moving it

**Date**: 2026-11-10
**Lesson**: Moving a generated State field breaks every reader of its value at compile time, but a reader of its PRESENCE (`@hasField`) silently answers false instead: the V8 binding decided an attribute was [SameObject] by whether the owner's State had a `cached_<name>` field, and on that decision drew the edges that keep a child's owner alive.

**Why**: `interface.zig stateCachesSameObject("cached_" ++ prop_name)` was the binding's only source for "this getter returns a [SameObject] child": it chose `needs_this_handle` and `recordSameObjectEdge`, which ties the child's wrapper to its owner's per realm AND draws the edge back from the child to the owner (the edge that keeps `el.attributes` from outliving `el`). A comptime `@hasField` on a removed field is not an error; it is `false`.

**What Happened**: Lane cg1 (N1) moved an element's family-wide [SameObject] caches (classList, part, children, dataset, attributeStyleMap, style, attributes) out of the generated State into the element's rare data. Every unit test passed and the binding compiled. The integrator asked for a red test proving the edge still mattered; a new Crane test (crane/cg1-same-object-keeps-owner.html: keep only the child of a detached element, collect, use the child) failed 4 of 10, and the two existing ones (sameobject-child-keeps-owner, rc5-same-object-keeps-owner) 0 of 1 and 0 of 3, on the Debug bug-finding runner: kept children read dead elements (InvalidStateError, a null ownerElement, undefined dataset values). The fix made the codegen emit the fact itself - `Meta.same_object_attributes`, every [SameObject] attribute whose child the owner keeps, wherever its cache lives - and the binding read that list (the State field check kept as a fallback for hand-written States): 14 of 14, three runs.

**Fix**:
1. Before removing or renaming a generated field, grep for its NAME PATTERN in comptime checks too: `@hasField`, `std.meta.fieldNames`, `"cached_" ++`, `hasField(`.
2. When a field doubles as a marker, emit the marker as data (a Meta list) and make the reader use it.
3. Prove the edge with a test that fails without it: keep the child, drop and collect the owner, use the child, under the poisoning runner.

**Takeaway**: **A comptime presence check on a generated field fails open when the field moves: find every `@hasField` reader before moving one, and give the fact it encoded a declaration of its own.**
