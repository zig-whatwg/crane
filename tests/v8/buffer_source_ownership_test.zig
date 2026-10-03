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
//!
//! BufferSource left the list on 2026-10-02: its conversion now makes a
//! reference to the object (tests/v8/buffer_source_argument_test.zig), which
//! the argument owns until it is freed.

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const nonOwning = v8.interface_mod.argConversionIsNonOwning;
const types = v8.interface_mod.non_owning_arg_types;

test "AllowSharedBufferSource is non-owning - the crash this predicate exists for" {
    try std.testing.expect(nonOwning(types.AllowSharedBufferSource));
}

test "BufferSource and ArrayBufferView are NOT non-owning: they hold a reference to free" {
    // A BufferSource was listed here while its conversion failed for every
    // value. It is now a reference to the object it was converted from
    // (conv.convertBufferSource): the argument's handle, and for an
    // ArrayBuffer a struct allocated for it, both released when the argument
    // is freed (freeBufferSourceArg). Non-owning would skip that free and
    // leak a Global per call.
    try std.testing.expect(!nonOwning(types.BufferSource));
    try std.testing.expect(!nonOwning(types.ArrayBufferView));
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

// =============================================================================
// BodyInit: ownership by arm, decided by its conversion
// =============================================================================
//
// `convertBodyInit` COPIES a buffer (an ArrayBuffer struct and its bytes) into
// BodyInit's BufferSource arm, so nothing a later argument's getter does to the
// buffer can leave the impl reading freed memory. That makes this BufferSource
// owned, where the type-level predicate above - rightly, for TextDecoder's
// views - says "never free". `freeBodyInitArg` frees BodyInit by arm; these
// tests run it under std.testing.allocator, which fails on a leak AND on a
// free of anything it did not allocate.

const BodyInit = v8.interface_mod.copied_arg_types.BodyInit;
const XhrBodyInit = @FieldType(BodyInit, "xmlhttp_request_body_init");
const BufferSource = @FieldType(XhrBodyInit, "buffer_source");
const ArrayBuffer = @typeInfo(@FieldType(BufferSource, "array_buffer")).pointer.child;

test "BodyInit's copied buffer is freed, struct and bytes" {
    const allocator = std.testing.allocator;
    const buffer = try allocator.create(ArrayBuffer);
    buffer.* = try ArrayBuffer.init(allocator, 5);
    @memcpy(buffer.data, "bytes");
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .buffer_source = .{ .array_buffer = buffer } } });
}

test "BodyInit's empty copy is freed too" {
    const allocator = std.testing.allocator;
    const buffer = try allocator.create(ArrayBuffer);
    buffer.* = try ArrayBuffer.init(allocator, 0);
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .buffer_source = .{ .array_buffer = buffer } } });
}

test "BodyInit's string is freed when owned, and the empty literal is not" {
    const allocator = std.testing.allocator;
    const text = try allocator.dupe(u8, "a body");
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .usvstring = text } });
    // convertBodyInit returns the literal "" for an empty string.
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .usvstring = "" } });
}

test "BodyInit's interface arms are the wrappers' Instances, never freed" {
    // A pointer the testing allocator never handed out: freeing it fails.
    var not_ours: runtime.Instance = undefined;
    const instance: *runtime.Instance = &not_ours;
    const allocator = std.testing.allocator;
    v8.interface_mod.freeBodyInitArg(allocator, .{ .readable_stream = instance });
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .blob = instance } });
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .form_data = instance } });
    v8.interface_mod.freeBodyInitArg(allocator, .{ .xmlhttp_request_body_init = .{ .urlsearch_params = instance } });
}

test "BodyInit's copied BufferSource is freed by arm, not by the reference rule" {
    // convertBodyInit copies the bytes into an ArrayBuffer struct with no
    // `js`: freeBodyInitArg frees struct and bytes, and the reference rule
    // (freeBufferSourceArg) leaves a Zig-made struct to its maker.
    try std.testing.expect(!nonOwning(BodyInit));
    try std.testing.expect(!nonOwning(BufferSource));
    const allocator = std.testing.allocator;
    var zig_made = ArrayBuffer{ .data = &[_]u8{}, .detached = false };
    v8.interface_mod.freeBufferSourceArg(BufferSource, allocator, .{ .array_buffer = &zig_made });
}
