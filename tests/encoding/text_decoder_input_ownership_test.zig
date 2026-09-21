//! `TextDecoder.decode()`'s input is borrowed, never owned.
//!
//! WHATWG Encoding Standard § 8.1:
//!   `USVString decode(optional [AllowShared] BufferSource input, ...)`
//!
//! The binding layer converts that argument with
//! `conv.convertAllowSharedBufferSource`, which does not allocate — it points a
//! `[]const u8` at V8's ArrayBuffer backing store and returns
//! `AllowSharedBufferSource{ .byte_slice = ... }`. The generic argument-cleanup
//! path could not tell that slice apart from one `fromV8String` had allocated,
//! freed it, and the DebugAllocator aborted the process with
//! `panic: Invalid free` on every `decode()` over a non-empty buffer — 67 of 149
//! `encoding/` WPT files, including all fifteen `textdecoder-*.any.js`.
//!
//! These tests pin the property that made the free invalid, from the encoding
//! side: the `byte_slice` arm ALIASES its input. Nothing here allocates, so
//! `std.testing.allocator` has nothing to report; that is the point.

const std = @import("std");
const webidl = @import("webidl");

const AllowSharedBufferSource = webidl.buffer_sources.AllowSharedBufferSource;

test "byte_slice aliases its input rather than copying it" {
    // A stack buffer stands in for V8's backing store: memory with an owner
    // that is emphatically not a Zig allocator.
    var backing = [_]u8{ 0x82, 0x4F, 0x82, 0x50, 0x82, 0x51 }; // sjis "１２３"

    const source = AllowSharedBufferSource{ .byte_slice = &backing };
    const bytes = try source.asBytes();

    // Same pointer, same length. Handing this to `allocator.free` is the bug.
    try std.testing.expectEqual(@as([*]const u8, &backing), bytes.ptr);
    try std.testing.expectEqual(backing.len, bytes.len);

    // And it is a live view, not a snapshot: mutating the backing store shows
    // through, which no owned copy would do.
    backing[0] = 0x83;
    try std.testing.expectEqual(@as(u8, 0x83), bytes[0]);
}

test "a decoded byte_slice survives the decode call unmodified" {
    // The round trip the WPT files exercise: bytes in a buffer the engine does
    // not own, decoded to scalar values, with the input left untouched and
    // unfreed afterwards.
    const allocator = std.testing.allocator;

    var backing = [_]u8{ 0xA4, 0xA2 }; // euc-jp U+3042 HIRAGANA LETTER A
    const source = AllowSharedBufferSource{ .byte_slice = &backing };

    const enc = @import("encoding").getEncoding("euc-jp") orelse return error.EncodingNotFound;
    var decoder = enc.newDecoder();

    const input = try source.asBytes();
    const output = try allocator.alloc(u16, 4);
    defer allocator.free(output);

    const result = decoder.decode(input, output, true);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_consumed);
    try std.testing.expectEqual(@as(usize, 1), result.code_units_written);
    try std.testing.expectEqual(@as(u16, 0x3042), output[0]);

    // Input untouched. If anything in the decode path had taken ownership, the
    // caller could not still make this assertion.
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xA4, 0xA2 }, &backing);
}

test "an empty byte_slice is still a view, not a freeable allocation" {
    // `convertAllowSharedBufferSource` returns `.{ .byte_slice = &[_]u8{} }` for
    // a detached or zero-length buffer. That case never crashed — the cleanup
    // path skipped zero-length slices — which is exactly why the bug read as
    // "some decodes abort" rather than "decode is broken".
    const source = AllowSharedBufferSource{ .byte_slice = &[_]u8{} };
    const bytes = try source.asBytes();
    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}
