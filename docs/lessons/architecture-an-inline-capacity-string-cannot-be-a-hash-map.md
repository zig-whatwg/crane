# Architecture: An inline-capacity string cannot be a hash-map key

**Date**: 2026-09-22
**Lesson**: `SmallString` keeps 31 bytes INSIDE the struct, so `toSlice()` on any
by-value copy returns a pointer into a temporary.

**Why**: `TagToken.finishCurrentAttribute` switches from a linear scan to a
`StringHashMapUnmanaged` once a tag carries more than four attributes, and keyed
it on `Attribute.name.toSlice()`. Every Attribute reachable there is a copy:
`for (slice) |existing|` binds a stack slot the NEXT iteration reuses, and
`if (self.current_attribute) |attr|` binds the optional's payload into a frame
that ends when the function returns.

**What Happened**: the seeding loop handed the set N keys that all aliased ONE
address. They hash correctly at insert - the slot holds the right bytes right
then - so nothing goes wrong until the table rehashes. Then every stored key
reads back as the last name written, `grow` finds them all equal, and
`putAssumeCapacityNoClobber` asserts:

    panic: reached unreachable code
      hash_map.HashMapUnmanaged([]const u8,void,...).putAssumeCapacityNoClobberContext
      hash_map.HashMapUnmanaged([]const u8,void,...).grow
      parser.tokens.TagToken.finishCurrentAttribute
      parser.tokenizer.Tokenizer.emitCurrentTag

Seven attributes is the threshold - seeded at the sixth, overflows at the
seventh - so it looked like "one odd WPT file" rather than "the tokenizer".
`<input type min max step value style id>` is an ordinary tag.

**Fix**: the set owns its keys (`allocator.dupe`, freed in `deinit`). A pointer
into `self.attributes` would not have worked either: `infra.List.append`
reallocates.

**Takeaway**: **Before storing a slice as a key, ask what it points INTO, not
what it contains.** Small-string optimisation turns every by-value copy into a
new address for the same text, and the failure surfaces one rehash later, in a
function that looks unrelated.
