const std = @import("std");
const file = @import("file");

test "xw1 a captured blob URL entry survives revoke and authorizes at read" {
    try std.testing.expect(@hasDecl(file.BlobURLStore, "capture"));
    if (comptime !@hasDecl(file.BlobURLStore, "capture")) return;
    const a = std.testing.allocator;
    var store = file.BlobURLStore.init(a);
    defer store.deinit();
    const blob = try file.BlobData.init(a, "captured bytes", "text/plain");
    defer blob.deinit();
    const key = "https://example.test https://example.test 0";
    const url = try store.createObjectURL(blob, key, null);
    defer a.free(url);
    const entry = store.capture(url) orelse return error.TestExpectedEntry;
    defer entry.release();
    const fragment = try std.mem.concat(a, u8, &.{ url, "#fragment" });
    defer a.free(fragment);
    const other = store.capture(fragment) orelse return error.TestExpectedEntry;
    defer other.release();
    try std.testing.expect(entry == other);
    const clone = entry.retain();
    defer clone.release();
    const origin = try clone.getOrigin(a);
    defer origin.deinit(a);
    const serialized = try origin.serialize(a);
    defer a.free(serialized);
    try std.testing.expectEqualStrings("https://example.test", serialized);
    store.revokeObjectURL(url, key);
    try std.testing.expect(store.capture(url) == null);
    try std.testing.expect(store.resolve(url, .{ .environment = key }) == null);
    const data = try clone.read(a, .{ .environment = key });
    defer data.deinit(a);
    try std.testing.expectEqualStrings("captured bytes", data.bytes);
    try std.testing.expectEqualStrings("text/plain", data.content_type);
    try std.testing.expectError(error.WrongPartition, entry.read(a, .{ .environment = "https://example.test https://other.test 1" }));
    const navigation = try entry.read(a, .top_level_navigation);
    defer navigation.deinit(a);
    try std.testing.expectEqualStrings("captured bytes", navigation.bytes);
}

test "xw1 a captured opaque blob origin stays opaque to script" {
    try std.testing.expect(@hasDecl(file.BlobURLStore, "capture"));
    if (comptime !@hasDecl(file.BlobURLStore, "capture")) return;
    const a = std.testing.allocator;
    var store = file.BlobURLStore.init(a);
    defer store.deinit();
    const blob = try file.BlobData.init(a, "opaque", "text/plain");
    defer blob.deinit();
    const url = try store.createObjectURL(blob, "null", null);
    defer a.free(url);
    const entry = store.capture(url) orelse return error.TestExpectedEntry;
    defer entry.release();
    const origin = try entry.getOrigin(a);
    defer origin.deinit(a);
    const serialized = try origin.serialize(a);
    defer a.free(serialized);
    try std.testing.expectEqualStrings("null", serialized);
    try std.testing.expectError(error.WrongPartition, entry.read(a, .{ .environment = "null" }));
}

test "xw1 uncaptured navigation retains the old opaque key comparison but captured reads require identity" {
    const a = std.testing.allocator;
    var store = file.BlobURLStore.init(a);
    defer store.deinit();
    const blob = try file.BlobData.init(a, "navigation", "text/html");
    defer blob.deinit();
    const key = "null https://example.test 1 c -";
    const url = try store.createObjectURLWithOrigin(blob, key, 12, null);
    defer a.free(url);
    const entry = store.capture(url) orelse return error.NoEntry;
    defer entry.release();
    for ([_][]const u8{ "null https://example.test 1", "null https://example.test 1 - -" }) |legacy| {
        const resolved = store.resolve(url, .{ .environment = legacy }) orelse return error.NavigationLost;
        resolved.deinit();
        try std.testing.expectError(error.WrongPartition, entry.read(a, .{ .environment = legacy }));
    }
    try std.testing.expect(store.resolve(url, .{ .environment = "null https://example.test 1 d -" }) == null);
}
