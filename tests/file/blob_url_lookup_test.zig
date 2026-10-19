const std = @import("std");
const file = @import("file");

test "Blob URL resolution excludes fragments while revocation keeps them" {
    const allocator = std.testing.allocator;
    var store = file.BlobURLStore.init(allocator);
    defer store.deinit();
    const blob = try file.BlobData.init(allocator, "kept", "text/plain");
    defer blob.deinit();
    const origin = "https://example.com";
    const url = try store.createObjectURL(blob, origin, null);
    defer allocator.free(url);
    const uuid = url[std.mem.lastIndexOfScalar(u8, url, '/').? + 1 ..];
    const uuid_fragment = try std.mem.concat(allocator, u8, &.{ "#/", uuid });
    defer allocator.free(uuid_fragment);

    for ([_][]const u8{ "#", "#part", "#part/path?query#again", uuid_fragment }) |fragment| {
        const decorated = try std.mem.concat(allocator, u8, &.{ url, fragment });
        defer allocator.free(decorated);
        const resolved = store.resolve(decorated, .{ .environment = origin }) orelse return error.TestExpectedEntry;
        defer resolved.deinit();
        try std.testing.expectEqualStrings("kept", resolved.bytes);
        store.revokeObjectURL(decorated, origin);
        const still_live = store.resolve(url, .{ .environment = origin }) orelse return error.TestExpectedEntry;
        still_live.deinit();
    }
    for ([_][]const u8{ "?query", "?query#fragment", "/other" }) |suffix| {
        const changed = try std.mem.concat(allocator, u8, &.{ url, suffix });
        defer allocator.free(changed);
        const result = store.resolve(changed, .{ .environment = origin });
        defer if (result) |data| data.deinit();
        try std.testing.expect(result == null);
    }
}

test "Blob URL lookup and revocation match the URL prefix as well as UUID" {
    const allocator = std.testing.allocator;
    var store = file.BlobURLStore.init(allocator);
    defer store.deinit();
    const blob = try file.BlobData.init(allocator, "kept", "text/plain");
    defer blob.deinit();
    const origin = "https://example.com";
    const url = try store.createObjectURL(blob, origin, null);
    defer allocator.free(url);
    const uuid = url[std.mem.lastIndexOfScalar(u8, url, '/').? + 1 ..];
    for ([_][]const u8{ "blob:https://other.invalid/", "blob:https://example.com/extra/" }) |prefix| {
        const changed = try std.mem.concat(allocator, u8, &.{ prefix, uuid });
        defer allocator.free(changed);
        const result = store.resolve(changed, .{ .environment = origin });
        defer if (result) |data| data.deinit();
        try std.testing.expect(result == null);
        store.revokeObjectURL(changed, origin);
        const still_live = store.resolve(url, .{ .environment = origin }) orelse return error.TestExpectedEntry;
        still_live.deinit();
    }
}
