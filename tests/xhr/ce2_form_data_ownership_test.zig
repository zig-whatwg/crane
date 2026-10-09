const std = @import("std");
const xhr = @import("xhr");

fn alwaysLive(_: xhr.form_data.BlobInstance) bool {
    return true;
}

fn liveWhileTokenIsOne(blob: xhr.form_data.BlobInstance) bool {
    const token: *const u8 = @ptrCast(blob.object);
    return token.* == 1;
}

fn appendWithFailures(allocator: std.mem.Allocator) !void {
    const data = try xhr.form_data.FormData.init(allocator);
    defer data.deinit();
    var token: u8 = 0;
    try data.appendBlobInstance("upload", .{ .object = &token, .generation = 0, .realm = &token, .is_live = &alwaysLive }, "payload.txt");
    try std.testing.expectEqual(@as(usize, 1), data.entries.items.len);
    try std.testing.expectEqualStrings("upload", data.entries.items[0].name);
    try std.testing.expectEqualStrings("payload.txt", data.entries.items[0].filename.?);
}

test "CE2 FormData: Blob entry releases both strings on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, appendWithFailures, .{});
}

// CE2-M2: an entry whose File is gone (its owner's liveness check says so)
// is no entry - dropped before every read, skipped by iteration - and never
// handed out.
test "CE2-M2 FormData: an entry whose File is gone is dropped before every read" {
    const data = try xhr.form_data.FormData.init(std.testing.allocator);
    defer data.deinit();
    var gone: u8 = 1;
    var kept: u8 = 1;
    try data.appendString("a", "first");
    try data.appendBlobInstance("f", .{ .object = &gone, .generation = 7, .realm = &gone, .is_live = &liveWhileTokenIsOne }, "gone.txt");
    try data.appendBlobInstance("f", .{ .object = &kept, .generation = 8, .realm = &kept, .is_live = &liveWhileTokenIsOne }, "kept.txt");
    try std.testing.expect(data.get("f").?.blob_instance.object == @as(*anyopaque, &gone));

    gone = 0;
    var iter = data.iterator();
    var seen: usize = 0;
    while (iter.next()) |entry| : (seen += 1) {
        if (entry[1] == .blob_instance) try std.testing.expect(entry[1].blob_instance.object == @as(*anyopaque, &kept));
    }
    try std.testing.expectEqual(@as(usize, 2), seen);
    try std.testing.expect(data.get("f").?.blob_instance.object == @as(*anyopaque, &kept));
    const all = try data.getAll(std.testing.allocator, "f");
    defer std.testing.allocator.free(all);
    try std.testing.expectEqual(@as(usize, 1), all.len);
    try std.testing.expectEqual(@as(usize, 2), data.entries.items.len);

    kept = 0;
    try std.testing.expect(!data.has("f"));
    try std.testing.expect(data.get("f") == null);
    try std.testing.expect(data.has("a"));
    try std.testing.expectEqual(@as(usize, 1), data.entries.items.len);
}
