# Testing: A Size Baseline Can Hide an Unrelated Inline Cost

**Date**: 2026-10-29
**Lesson**: Before adding an independent field to a reference layout, account for its cost on every instance.

**Why**: A test that bounds one feature's memory growth must include unrelated fields on both sides. Updating that reference is valid only after the unrelated feature's own storage cost is understood; otherwise it can conceal an unnecessary allocation cost on every element.

**What Happened**: Typed OM added a 16-byte ObjectLink to ElementStyle. The sibling-cache size bound failed because its Before layout lacked that independent field. The initial proposal was to normalize the reference layout, following two hint-cache precedents. Those precedents were 8-byte lazy pointers, while the new field charged every styled element for an identity used only by computedStyleMap(). The integrator's Q173 ruling required a lazy record instead.

**Fix**: Keep one optional pointer on ElementStyle. Allocate its weak, generation-checked ObjectLink only when computedStyleMap() needs it; publish after successful map construction, clean up failed construction with errdefer, and free the record with the style. Keep the existing wrapper edges responsible for object lifetime. Pin pointer size, default-null state, first-call allocation, repeated identity, allocation failure and destruction under std.testing.allocator. Then include that pointer in the sibling-cache reference layout without changing its bound. Disclose the 8-byte per-style cost in the final measurements. WebKit's Element::computedStyleMap and ElementRareData use lazy cached identity; combining Crane's hint pointers behind one rare-data pointer is a separate follow-up.

**Takeaway**: **A reference-layout correction is not approval of the field's memory cost. Measure the field independently before normalizing the baseline.**
