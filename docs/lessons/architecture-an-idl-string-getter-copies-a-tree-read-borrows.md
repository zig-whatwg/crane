# Architecture: An IDL string getter copies; a tree read borrows

**Date**: 2026-10-12
**Lesson**: Moving an impl-helper call onto the generated interface is free only when the getter runs the helper's steps; a string getter copies, so the tree's own reads of strings need a borrowing hook, and a construction-time setter needs a construction argument.

**Why**: The impls boundary (AGENTS.md) sends every IDL read through `interfaces.X.member`. For node links the
generated getter and the impl helper run the same steps (`get_nextSibling` and `getNextSibling`: registry
lookup, NodeBase link, instance bridge) and differ only in the error union, which `catch null` folds back -
design 3.1 a2. That equivalence does not hold for everything the design filed under a2. An IDL getter
returning a DOMString answers a string its caller owns: `CharacterData.get_data` is
`DOMString.initDupe(...)`, while the helper it replaces, `getData`, returned the bytes in place. And an IDL
setter runs the IDL algorithm: `CharacterData.set_data` runs "replace data" (a mutation-record check, the
live-range steps, children changed), while `setData` only stored the bytes.

**What Happened**: Lane implsb3 (B3, node-tree reads) found that converting Node's textContent and nodeValue
getters, its descendant-text-content walk and isEqualNode, plus an option's text and a textarea's child text
content, to `interfaces.CharacterData.get_data` would add one allocation and copy per Text node read, and
that converting Text(data), Comment(data) and createProcessingInstruction to `set_data` would run "replace
data" on every `document.createTextNode` (it goes through Text's constructor). The brief's rule was no added
cost on a hot read.

**Fix**:
1. The data became CharacterData's construction argument (`construction_args = .{"data"}`, the user's Q4):
   `interfaces.Text.initWith(allocator, ctx, .{ .data = d })`, as WebKit's `Text::create(document, data)`
   hands it to CharacterData's constructor. Zero cost: the chain is inline.
2. A hook, `dom.character_data.dataOf(node) ?[]const u8`, installed by CharacterData, reads the data in
   place, borrowed until it next changes - WebKit's `CharacterData::data()` returns its String by reference
   for the same reason. One process-wide key (the function pointer), recorded with its `// process-wide:`
   line.
3. Everything else in B3 (node links, node type, node document, attributes, Event and Blob getters, Selection,
   Cache.match) checked first: each generated member is `return try XImpl.member(...)`, a verbatim forwarder.

**Takeaway**: **Before moving a call onto the generated interface, read the generated member and the impl
member side by side: a link getter forwards, a string getter copies, a setter runs the IDL algorithm.** A
string the tree reads goes through a borrowing hook; a fact set at construction goes through `initWith`.
