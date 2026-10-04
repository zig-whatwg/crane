//! Allocation-failure regression for the IndexedDB factory.
const std = @import("std");
const storage = @import("storage");

fn openWalk(allocator: std.mem.Allocator) !void {
    var factory = storage.indexeddb.IDBFactory.init(allocator);
    defer factory.deinit();
    factory.setStorageKey("https://example.com");

    // Exercise both a newly inserted map key and an existing temporary key.
    for (0..2) |_| {
        const request = try factory.open("allocation-walk", 1);
        defer {
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
        try std.testing.expect(request.base.done_flag);
    }
}

test "IDBFactory.open - allocation failure releases each key once" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, openWalk, .{});
}
