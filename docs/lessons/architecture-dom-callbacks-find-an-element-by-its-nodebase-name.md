# Architecture: The DOM's callbacks find an element by its NodeBase name, which most elements leave empty

**Date**: 2026-10-05
**Lesson**: dom.mutation's insertion, post-connection and removing steps
hand their callbacks a `*NodeBase`, and an element type's callback finds its
elements by `node.node_name` - which is empty for every element whose impl
does not set it. iframe and script set it in their init
(`Node.setLocalName`), and so do object and embed now (the NodeBase name,
through `dom.instance_bridge`); a new element type that hooks these steps
must too.

**What Happened**: the object element's post-connection callback never ran
for a script-made object: `std.ascii.eqlIgnoreCase(node.node_name,
"object")` saw "". A debug print in the callback listed the node names it
was given: SCRIPT (set by its init) and empty strings. Element's own naming
(`dom.node_creation.setElementNames`, the parser's and createElement's)
sets Element's local name, not the NodeBase's.

**Fix**: object and embed name their NodeBase ("OBJECT", "EMBED") in init,
as iframe and script do. The alternative - look up every node's instance
and its vtable - costs a locked hash lookup per inserted node per callback.

**Takeaway**: **Before filtering a DOM callback by node name, check that
the element type's init sets the NodeBase name; most do not.**
