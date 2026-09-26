# Architecture: A conversion that allocates nothing still looks allocated

**Date**: 2026-09-21
**Lesson**: `needsArgCleanup` called every slice "owned", including one that aliased V8's heap.

**Why**: `conv.convertAllowSharedBufferSource` discards its allocator on purpose
(`_ = allocator; // Not needed - we create a non-owning view`) and returns
`.{ .byte_slice = src_ptr[0..len] }` over `v8_ArrayBuffer_Data`. Nothing in the
type says so — the arm is a plain `[]const u8`, the same shape a string that
`fromV8String` allocated has.

**What Happened**: `freeConvertedArg` walked the union, found the slice, and
handed V8's backing store to `allocator.free`. `panic: Invalid free` on every
`new TextDecoder(label).decode(nonEmptyTypedArray)` — 67 of 149 `encoding/` WPT
files, all fifteen `textdecoder-*` among them. The empty case survived because
the cleanup path skips zero-length slices, so it read as "some decodes crash".

**Fix**: `argConversionIsNonOwning`, consulted *before* any structural rule
(the arm that carries the view is itself a slice, so every later rule claims
it). Pinned by `tests/v8/buffer_source_ownership_test.zig` — including the
default, which must stay "owned" or every string argument leaks.

**Takeaway**: **Ownership is a property of the conversion, not of the type.
Grep `conversions.zig` for "non-owning" before trusting a structural rule.**
