const std = @import("std");
const fetch = @import("fetch");

fn replaceTrial(allocator: std.mem.Allocator) !void {
    var list = fetch.internal.HeaderList.init(allocator);
    defer list.deinit();
    try list.append("Content-Type", "text/plain; a=first");
    try list.set("content-type", "application/json; a=second");
    try std.testing.expectEqualStrings("application/json; a=second", list.entries.items[0].value);
}

test "replacing Content-Type keeps header storage valid on every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, replaceTrial, .{});
}
