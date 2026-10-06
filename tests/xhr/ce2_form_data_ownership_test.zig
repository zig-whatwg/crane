const std = @import("std");
const xhr = @import("xhr");

fn appendWithFailures(allocator: std.mem.Allocator) !void {
    const data = try xhr.form_data.FormData.init(allocator);
    defer data.deinit();
    var token: u8 = 0;
    try data.appendBlobInstance("upload", &token, "payload.txt");
    try std.testing.expectEqual(@as(usize, 1), data.entries.items.len);
    try std.testing.expectEqualStrings("upload", data.entries.items[0].name);
    try std.testing.expectEqualStrings("payload.txt", data.entries.items[0].filename.?);
}

test "CE2 FormData: Blob entry releases both strings on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, appendWithFailures, .{});
}
