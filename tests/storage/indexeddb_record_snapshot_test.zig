const std = @import("std");
const idb = @import("storage").indexeddb;

fn makeSnapshot(allocator: std.mem.Allocator) !void {
    var key_bytes = [_]u8{ 'i', 'd' };
    var primary_bytes = [_]u8{ 'p', 'k' };
    var value_bytes = [_]u8{ 1, 2, 3 };
    var snapshot = try idb.RecordSnapshot.init(allocator, idb.IDBKey.string(&key_bytes), idb.IDBKey.binary(&primary_bytes), &value_bytes);
    defer snapshot.deinit();
    key_bytes[0] = 'x';
    primary_bytes[0] = 'y';
    value_bytes[0] = 9;
    try std.testing.expectEqualStrings("id", snapshot.key.value.string);
    try std.testing.expectEqualStrings("pk", snapshot.primary_key.value.binary);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, snapshot.value);
}

test "IndexedDB record snapshot owns keys and serialized bytes" {
    try makeSnapshot(std.testing.allocator);
}

test "IndexedDB record snapshot releases partial allocations" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, makeSnapshot, .{});
}
