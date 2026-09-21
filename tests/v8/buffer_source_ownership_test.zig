//! `argConversionIsNonOwning` — did the engine allocate this argument, or is it
//! a view into memory V8 owns?
//!
//! The third predicate in the family that `retention_predicate_test.zig` covers,
//! and the one that had already gone wrong when it was written. `needsArgCleanup`
//! answered "owned" for *any* slice, including the `byte_slice` arm of
//! `AllowSharedBufferSource`, which `conv.convertAllowSharedBufferSource` builds
//! by pointing straight at `v8_ArrayBuffer_Data`:
//!
//!     _ = allocator; // Not needed - we create a non-owning view
//!     ...
//!     return .{ .byte_slice = src_ptr[0..byte_length] };
//!
//! `freeConvertedArg` then called `allocator.free` on V8's backing store and the
//! DebugAllocator aborted:
//!
//!     thread 75993479 panic: Invalid free
//!       debug_allocator.zig:885  ... if (bucket.canary != config.canary) @panic("Invalid free")
//!       interface.zig:2826       ... allocator.free(arg)
//!       interface.zig:2897       ... freeConvertedArg(FieldType, allocator, val)   <- union arm
//!       interface.zig:2876       ... freeConvertedArg(vt, allocator, arg.value)    <- webidl.Opt
//!       interface.zig:3013       ... defer freeConvertedArg(Param1Type, ...)       <- call_decode
//!
//! Every `new TextDecoder(label).decode(nonEmptyTypedArray)` killed the process.
//! 67 of 149 `encoding/` WPT files, all fifteen `textdecoder-*.any.js` among
//! them, plus `gbk-decoder.any.js` and `gb18030-decoder.any.js`.
//!
//! Polarity: TRUE means "do not free". The dangerous answer is FALSE, so the
//! tests below pin both the recognised types and the surrounding behaviour that
//! makes an ordinary owned argument still get freed — a predicate that answered
//! TRUE too widely would leak every string.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const nonOwning = v8.interface_mod.argConversionIsNonOwning;
const types = v8.interface_mod.non_owning_arg_types;

test "buffer-source unions are non-owning - the crash this predicate exists for" {
    try std.testing.expect(nonOwning(types.AllowSharedBufferSource));
    try std.testing.expect(nonOwning(types.BufferSource));
}

test "the recognised union really does carry a bare slice arm" {
    // Why the predicate has to be consulted BEFORE any structural rule: the arm
    // is a `[]const u8`, indistinguishable by shape from a string that
    // `fromV8String` allocated. If this assertion ever fails the arm was
    // renamed or retyped, and whoever did that needs to re-check
    // `convertAllowSharedBufferSource` before trusting the predicate.
    const info = @typeInfo(types.AllowSharedBufferSource).@"union";
    var saw_slice = false;
    inline for (info.fields) |field| {
        const fi = @typeInfo(field.type);
        if (fi == .pointer and fi.pointer.size == .slice) {
            try std.testing.expectEqualStrings("byte_slice", field.name);
            try std.testing.expectEqual(u8, fi.pointer.child);
            saw_slice = true;
        }
    }
    try std.testing.expect(saw_slice);
}

test "an unrecognised type defaults to OWNED, so ordinary arguments still get freed" {
    // The default, pinned deliberately. This predicate's safe-by-default
    // direction is the opposite of `typeRetainsContext`'s: answering TRUE here
    // suppresses a free, so a too-generous default leaks every string, sequence
    // and dictionary argument in the binding layer. Unknown types must fall
    // through to the existing cleanup rules.
    try std.testing.expect(!nonOwning([]const u8));
    try std.testing.expect(!nonOwning(runtime.DOMString));
    try std.testing.expect(!nonOwning(runtime.JSValue));
    try std.testing.expect(!nonOwning([]const runtime.DOMString));
    try std.testing.expect(!nonOwning(u32));
    try std.testing.expect(!nonOwning(bool));

    const SomethingNew = struct { a: u32, bytes: []const u8 };
    try std.testing.expect(!nonOwning(SomethingNew));

    // Notably including a union that merely *looks* like a buffer source. The
    // predicate matches the real type, not the shape, because the question it
    // answers is "which conversion produced this", and only
    // `convertAllowSharedBufferSource` declines to allocate.
    const LookalikeUnion = union(enum) { array_buffer: *anyopaque, byte_slice: []const u8 };
    try std.testing.expect(!nonOwning(LookalikeUnion));
}
