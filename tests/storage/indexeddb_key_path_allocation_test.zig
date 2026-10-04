const std = @import("std");
const key_path = @import("storage").indexeddb.key_path;

fn extractArray(allocator: std.mem.Allocator) !void {
    const elements = [_]key_path.ExtractedValue{ .{ .string = "first" }, .{ .string = "second" } };
    const properties = [_]key_path.ExtractedValue.Property{.{ .key = "tags", .value = .{ .array = &elements } }};
    const result = try key_path.extractKeyOwned(allocator, .{ .object = &properties }, .{ .single = "tags" }, false);
    switch (result) {
        .key => |owned| {
            var key = owned;
            defer key.deinit();
            try std.testing.expectEqual(@as(usize, 2), key.value.array.len);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "IndexedDB key-path array extraction unwinds an unappended child" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, extractArray, .{});
}

test "IndexedDB key injection has no arbitrary path-component limit" {
    const allocator = std.testing.allocator;
    const parts = [_][]const u8{"property"} ** 100;
    const path = try std.mem.join(allocator, ".", &parts);
    defer allocator.free(path);
    try std.testing.expect(key_path.checkKeyInjectable(.{ .object = &.{} }, path));
}
