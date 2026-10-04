const std = @import("std");
const idb = @import("storage").indexeddb;

fn dropRequest(allocator: std.mem.Allocator, request: *idb.IDBOpenDBRequest) void {
    if (request.base.result) |result| switch (result) {
        .database => |db| {
            db.deinit();
            allocator.destroy(db);
        },
        else => {},
    };
    request.deinit();
    allocator.destroy(request);
}

test "IndexedDB database keys distinguish an origin port from a database-name prefix" {
    var factory = idb.IDBFactory.init(std.testing.allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");
    const first = try factory.open("8080:records", 1);
    defer dropRequest(std.testing.allocator, first);
    factory.setStorageKey("https://example.com:8080");
    const second = try factory.open("records", 2);
    defer dropRequest(std.testing.allocator, second);
    try std.testing.expectEqual(@as(u64, 0), second.old_version);
    const port_list = try factory.databases();
    defer std.testing.allocator.free(port_list);
    try std.testing.expectEqual(@as(usize, 1), port_list.len);
    try std.testing.expectEqualStrings("records", port_list[0].name);
    factory.setStorageKey("https://example.com");
    const list = try factory.databases();
    defer std.testing.allocator.free(list);
    try std.testing.expectEqual(@as(usize, 1), list.len);
    try std.testing.expectEqualStrings("8080:records", list[0].name);
}
