const std = @import("std");
const Key = @import("storage").indexeddb.IDBKey;

fn cloneArray(allocator: std.mem.Allocator) !void {
    const elements = [_]Key{ Key.string("first"), Key.string("second"), Key.string("third") };
    var clone = try Key.array(&elements).clone(allocator);
    defer clone.deinit();
    try std.testing.expectEqualStrings("third", clone.value.array[2].value.string);
}

test "IndexedDB array key clone cleans earlier children on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, cloneArray, .{});
}
