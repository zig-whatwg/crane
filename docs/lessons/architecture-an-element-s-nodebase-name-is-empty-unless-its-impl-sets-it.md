# Architecture: An element's NodeBase name is empty unless its impl sets it

**Date**: 2026-09-29
**Lesson**: `NodeBase.node_name` - what DOM-level code such as the insertion-steps callbacks reads to recognise an element - is "" for every element whose impl does not call `NodeImpl.setLocalName` in its `init`. `Element.setLocalName`, which `createElement` and the parsers call, sets only Element's own local name.

**Why**: Node's `setLocalName` writes the upper-cased name into the NodeBase, and Element's `setLocalName` does not touch the NodeBase. Only HTMLScriptElement, SVGScriptElement and HTMLIFrameElement call Node's in their `init`, so every other element reaches `mutation.zig` with an empty name. A callback that filters on `eqlIgnoreCase(node.node_name, "x")` then returns before doing anything. Nothing fails and nothing is logged.

**What Happened**: The details element's insertion steps ("ensure details exclusivity by closing the given element if needed") were registered and called for every inserted node, and they never acted. An open `<details name=g>` appended beside an open member stayed open. The attribute change steps, which the element's own impl runs, worked, so exclusivity looked finished. A warn log at the top of the callback showed the name check failing. The same filter is in `HTMLIFrameElement.findBaseWithTarget`, which looks for `<base target>` by `child.node_name == "base"`. HTMLBaseElement never sets its name, so that lookup has never found a base element.

**Fix**: HTMLDetailsElement's `init` calls `NodeImpl.setLocalName(instance, "details")`, as script and iframe already do. The durable fix is for element creation to set the NodeBase name for every element, not one impl at a time.

**Takeaway**: **Before filtering NodeBase nodes by `node_name`, check that the element's impl sets it; an empty name is a filter that silently matches nothing.**
