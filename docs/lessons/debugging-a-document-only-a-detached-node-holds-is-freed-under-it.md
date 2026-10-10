# Debugging: A document that only a detached node holds is freed under that node

**Date**: 2026-10-09
**Lesson**: A node removed from a windowless document (createHTMLDocument, DOMParser) and kept by script is alone in its own tree; nothing keeps the document's wrappers, so the document's instance is freed while the node's `owner_document` still points at it, and `node.ownerDocument` segfaults.

**Why**: Crane frees a node through its tree's root wrapper and keeps wrappers alive by tree edges (wrapper_cache.zig). A node's owner document is a raw pointer that is not a tree edge. While the node is in the document, the tree edges keep the document's wrapper; once it is removed, they do not.

**What Happened**: The D6 test of the reference-counting migration (tests/wpt/crane/rc-document-held-through-detached-node.html: createHTMLDocument, append and remove a paragraph, drop the document, collect, read `n.ownerDocument`) crashed the runner on main 2a3f07d8d6: SIGSEGV in `template_registry.getTemplate`, reached from `Node.get_ownerDocument` -> `conversions.instanceToV8`, hashing the interface name of a freed instance. Its control, the same document with the node still in it, passes.

**Fix**: Not fixed in the lane that found it. Reference counting fixes it by design (decision D6: `Document.foreign_holds` counts held detached nodes of the document, and its tree stays while any exist; WebKit's `referencing_nodes` keeps the storage). Until then a node's owner document needs an edge from the node's wrapper.

**Takeaway**: **Write the test for a design decision against the current build before building on the decision: it may be a crash today, not a gap.**
