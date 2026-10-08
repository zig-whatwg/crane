# Architecture: Shadow Removal Must Walk Shadow Trees

**Date**: 2026-10-08

**Lesson**: A shadow host's lifecycle walk must enter its own shadow root, including closed and nested roots, before traversing its light children.

**Why**: ShadowRoot is not a child in the host's ordinary child list. A light-tree recursion misses both the root and its descendants. Cached connectedness and removing steps then disagree with the actual shadow-including tree.

**What Happened**: Crane's shadow-including descendant helper still traversed only ordinary children. Its connectedness update and removal allocation-failure fallback did the same. Removing a host therefore left shadow scripts marked connected and omitted their removing steps, retaining a script's document render blocker until execution or timeout. The removal callback's cached connectedness guard could suppress cleanup even after traversal was corrected.

**Fix**: Read the host's internal shadow edge through `dom.shadow_hosts.rootForHost` and convert identities through `dom.instance_bridge`. Enter the current host's root before its light children, including when the traversal starts at that host. Apply the same traversal to connectedness and the allocation-free removal fallback. Invoke descendant removing steps with the original removed ancestor, as DOM removal step 14 requires. Treat removing-step invocation as the lifecycle signal rather than gating script cleanup on cached connectedness; state-preserving moves use moving steps separately. Pin closed/nested ordering, connectedness, blocker cleanup and collection allocation failure with allocator-backed native tests and a script-visible delayed-graph fixture.

**Takeaway**: **A shadow-including lifecycle algorithm and its allocation-failure fallback must traverse the same shadow edges in the same order.**

DOM references: [remove](https://dom.spec.whatwg.org/#concept-node-remove), [shadow-including tree order](https://dom.spec.whatwg.org/#concept-shadow-including-tree-order). Browser design references: Blink [ShadowIncludingTreeOrderTraversal::FirstWithin/TraverseNextSibling](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/shadow_including_tree_order_traversal.h), [ContainerNode::NotifyNodeRemoved](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/dom/container_node.cc). Crane takes the traversal design, not Blink's GC or implementation code.
