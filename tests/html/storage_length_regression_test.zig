//! Storage length is its map size; named-property binding must reach this map.
const std = @import("std");
const Storage = @import("html_core").web_storage.Storage;

test "Storage length: insert, replace, quota failure, remove and clear count map entries" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap([]u8).init(allocator);
    defer map.deinit();
    var storage = Storage.initBorrowed(allocator, .{ .backing_map = &map, .allocator = allocator }, .local, "https://example.test");
    defer storage.deinit();
    defer storage.clear();

    try std.testing.expectEqual(@as(usize, 0), storage.length());
    try storage.setItem("name", "user1");
    try std.testing.expectEqual(@as(usize, 1), storage.length());
    try storage.setItem("name", "user2");
    try std.testing.expectEqual(@as(usize, 1), storage.length());
    try std.testing.expectEqualStrings("user2", storage.getItem("name").?);
    try storage.setItem("name", "user2");
    try std.testing.expectEqual(@as(usize, 1), storage.length());

    storage.quota = 9;
    try std.testing.expectError(error.QuotaExceededError, storage.setItem("name", "longer"));
    try std.testing.expectEqual(@as(usize, 1), storage.length());
    try std.testing.expectEqualStrings("user2", storage.getItem("name").?);
    try std.testing.expectError(error.QuotaExceededError, storage.setItem("other", "value"));
    try std.testing.expectEqual(@as(usize, 1), storage.length());
    storage.removeItem("missing");
    try std.testing.expectEqual(@as(usize, 1), storage.length());
    storage.removeItem("name");
    try std.testing.expectEqual(@as(usize, 0), storage.length());
    try storage.setItem("again", "1");
    storage.clear();
    try std.testing.expectEqual(@as(usize, 0), storage.length());
    try std.testing.expect(storage.key(0) == null);
}

test "Storage length: empty, embedded NUL and WTF-8 keys remain distinct" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap([]u8).init(allocator);
    defer map.deinit();
    var storage = Storage.initBorrowed(allocator, .{ .backing_map = &map, .allocator = allocator }, .session, "https://example.test");
    defer storage.deinit();
    defer storage.clear();
    const keys = [_][]const u8{ "", "foo", "foo\x00bar", "foo\x00baz", "\xed\xa0\x80", "\xef\xbf\xbd" };
    for (keys, 0..) |key, i| {
        try storage.setItem(key, "first");
        try std.testing.expectEqual(i + 1, storage.length());
    }
    for (keys) |key| {
        try storage.setItem(key, "replacement");
        try std.testing.expectEqual(keys.len, storage.length());
        try std.testing.expectEqualStrings("replacement", storage.getItem(key).?);
    }
}
