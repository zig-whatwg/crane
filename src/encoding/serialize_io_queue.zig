//! Serialize I/O Queue
//!
//! Utility functions for serializing I/O queues to strings for debugging and testing.
//!
//! WHATWG Encoding Standard §3

const std = @import("std");
const io_queue = @import("io_queue.zig");
const Allocator = std.mem.Allocator;

/// Serialize a byte queue to a hex string
pub fn serializeByteQueue(allocator: Allocator, queue: *const io_queue.ByteQueue) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    const writer = result.writer();
    try writer.writeAll("[");

    var first = true;
    const items = queue.items.items();
    for (items) |item| {
        if (!first) try writer.writeAll(", ");
        first = false;

        switch (item) {
            .value => |v| try writer.print("0x{X:0>2}", .{v}),
            .end_of_queue => try writer.writeAll("EOQ"),
        }
    }

    try writer.writeAll("]");
    return result.toOwnedSlice();
}

/// Serialize a scalar queue to a Unicode string
pub fn serializeScalarQueue(allocator: Allocator, queue: *const io_queue.ScalarQueue) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    const writer = result.writer();
    const items = queue.items.items();
    for (items) |item| {
        switch (item) {
            .value => |v| {
                var buf: [4]u8 = undefined;
                const len = std.unicode.utf8Encode(v, &buf) catch continue;
                try writer.writeAll(buf[0..len]);
            },
            .end_of_queue => break,
        }
    }

    return result.toOwnedSlice();
}
