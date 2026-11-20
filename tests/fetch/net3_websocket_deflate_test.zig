//! permessage-deflate (RFC 7692) as kit/curl's WebSocket transport does it
//! (lane net3): the response's agreed parameters - what it must fail the
//! connection for (section 7) - and the message transformation (7.2) on
//! zlib, checked against the RFC's examples (7.2.3).
const std = @import("std");
const testing = std.testing;
const kit = @import("kit_curl_share");
const deflate = kit.websocket_deflate;

/// zlib is in the link with the bundled libcurl only (trust.enabled).
const zlib = kit.trust.enabled;

test "a response names no extension, or the offered permessage-deflate with valid parameters" {
    try testing.expectEqual(deflate.Agreed.none, try deflate.agree(&.{}));
    try testing.expectEqual(deflate.Agreed.none, try deflate.agree(&.{ "", " , " }));
    try testing.expectEqualDeep(deflate.Agreed{ .deflate = .{} }, try deflate.agree(&.{"permessage-deflate"}));
    try testing.expectEqualDeep(deflate.Agreed{ .deflate = .{
        .server_no_context_takeover = true,
        .client_no_context_takeover = true,
        .server_max_window_bits = 10,
        .client_max_window_bits = 8,
    } }, try deflate.agree(&.{"permessage-deflate; server_no_context_takeover ;client_no_context_takeover; server_max_window_bits=10; client_max_window_bits=\"8\""}));
    // The field twice is one list: still one element.
    try testing.expectEqualDeep(deflate.Agreed{ .deflate = .{ .server_max_window_bits = 15 } }, try deflate.agree(&.{ "", "permessage-deflate; server_max_window_bits=15" }));
}

test "a response the client must fail the connection for (RFC 7692 5 and 7)" {
    for ([_][]const u8{
        "x-webkit-deflate-frame", // not offered
        "permessage-deflate, permessage-deflate", // two elements
        "permessage-deflate; foo", // an unknown parameter
        "permessage-deflate; server_no_context_takeover; server_no_context_takeover", // repeated
        "permessage-deflate; client_no_context_takeover=1", // a value where none is defined
        "permessage-deflate; client_max_window_bits", // no value in a response
        "permessage-deflate; server_max_window_bits=7",
        "permessage-deflate; server_max_window_bits=16",
        "permessage-deflate; server_max_window_bits=09", // a leading zero
        "permessage-deflate; server_max_window_bits=1a",
        "permessage-deflate; server_max_window_bits=\"1\\0\"",
        "Permessage-Deflate",
    }) |value| try testing.expectError(error.Invalid, deflate.agree(&.{value}));
}

test "a message compresses as RFC 7692 7.2.3.1 shows, and context carries to the next (7.2.3.2)" {
    if (comptime !zlib) return error.SkipZigTest;
    const deflater = try deflate.Deflater.create(testing.allocator, 15, false);
    defer deflater.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try deflater.compress("Hello", &out);
    try testing.expectEqualSlices(u8, &.{ 0xf2, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, out.items);
    out.clearRetainingCapacity();
    try deflater.compress("Hello", &out);
    try testing.expectEqualSlices(u8, &.{ 0xf2, 0x00, 0x11, 0x00, 0x00 }, out.items);
    // An empty message is one octet (7.2.3.6).
    out.clearRetainingCapacity();
    try deflater.compress("", &out);
    try testing.expectEqualSlices(u8, &.{0x00}, out.items);
}

test "with client_no_context_takeover each message starts from an empty window" {
    if (comptime !zlib) return error.SkipZigTest;
    const deflater = try deflate.Deflater.create(testing.allocator, 15, true);
    defer deflater.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    for (0..2) |_| {
        out.clearRetainingCapacity();
        try deflater.compress("Hello", &out);
        try testing.expectEqualSlices(u8, &.{ 0xf2, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, out.items);
    }
}

test "the RFC's compressed messages decompress (7.2.3.1 to 7.2.3.5)" {
    if (comptime !zlib) return error.SkipZigTest;
    const inflater = try deflate.Inflater.create(testing.allocator, false);
    defer inflater.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    for ([_][]const u8{
        &.{ 0xf2, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 },
        // The shared window: needs the message before it.
        &.{ 0xf2, 0x00, 0x11, 0x00, 0x00 },
        // A block with no compression.
        &.{ 0x00, 0x05, 0x00, 0xfa, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00 },
        // A block with BFINAL set, then an empty one.
        &.{ 0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x00 },
        // Two blocks in one message.
        &.{ 0xf2, 0x48, 0x05, 0x00, 0x00, 0x00, 0xff, 0xff, 0xca, 0xc9, 0xc9, 0x07, 0x00 },
    }) |message| {
        out.clearRetainingCapacity();
        try inflater.decompress(message, &out, 1 << 20);
        try testing.expectEqualStrings("Hello", out.items);
    }
}

test "a large message round-trips through both, and the limit holds" {
    if (comptime !zlib) return error.SkipZigTest;
    const message = try testing.allocator.alloc(u8, 100_000);
    defer testing.allocator.free(message);
    for (message, 0..) |*byte, i| byte.* = @truncate(i *% 7 +% (i >> 9));
    const deflater = try deflate.Deflater.create(testing.allocator, 15, false);
    defer deflater.destroy();
    const inflater = try deflate.Inflater.create(testing.allocator, false);
    defer inflater.destroy();
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(testing.allocator);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    for (0..3) |_| {
        compressed.clearRetainingCapacity();
        out.clearRetainingCapacity();
        try deflater.compress(message, &compressed);
        try inflater.decompress(compressed.items, &out, 1 << 20);
        try testing.expectEqualSlices(u8, message, out.items);
    }
    compressed.clearRetainingCapacity();
    out.clearRetainingCapacity();
    try deflater.compress(message, &compressed);
    try testing.expectError(error.InvalidData, inflater.decompress(compressed.items, &out, 1000));
    // Not DEFLATE at all.
    const fresh = try deflate.Inflater.create(testing.allocator, false);
    defer fresh.destroy();
    out.clearRetainingCapacity();
    try testing.expectError(error.InvalidData, fresh.decompress(&.{ 0xff, 0xff, 0xff }, &out, 1 << 20));
}

test "zlib's allocations are the caller's, and a failure part-way frees them" {
    if (comptime !zlib) return error.SkipZigTest;
    const Attempt = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const deflater = try deflate.Deflater.create(allocator, 15, false);
            defer deflater.destroy();
            const inflater = try deflate.Inflater.create(allocator, false);
            defer inflater.destroy();
            var compressed: std.ArrayList(u8) = .empty;
            defer compressed.deinit(allocator);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(allocator);
            try deflater.compress("Hello, Hello, Hello", &compressed);
            try inflater.decompress(compressed.items, &out, 1 << 20);
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Attempt.run, .{});
}
