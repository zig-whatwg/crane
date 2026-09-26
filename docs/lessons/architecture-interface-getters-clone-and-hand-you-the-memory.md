# Architecture: Interface getters clone and hand you the memory

**Date**: 2026-09-22
**Lesson**: `Element.get_localName`, `get_namespaceURI`, `get_prefix`,
`Attr.get_name`/`get_value` and friends all end in
`try x.clone(instance.ctx.allocator)` with the comment "transfer ownership to
caller (interface layer will free)".

**Why**: That comment is written for the SCRIPT caller. When JS reads the
property, the binding layer frees the returned `DOMString`. A Zig caller has no
such layer, so it owns the allocation.

**What Happened**: Writing `cloneNode` against the interfaces - the direction
the impls boundary asks for - leaked the element's local name, namespace and
prefix plus three strings per attribute, on every clone, in a path that runs for
every `cloneNode`, `importNode` and `Range.cloneContents`. Invisible to
`std.testing.allocator`, because it is the context allocator.

**Fix**: `defer x.deinit(node.ctx.allocator)` on every getter result. Free with
**`ctx.allocator`**, which is what the getter cloned into -
`node_internal.allocator` is not necessarily the same one. `DOMString.deinit`
is a no-op for `.empty` and `.interned`, so it is safe unconditionally.

**Takeaway**: **"The interface layer will free it" means the JS binding will.
Calling a `get_*` from Zig makes you the owner.**
