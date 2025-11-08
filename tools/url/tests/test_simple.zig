const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var output = std.ArrayList(u8){};
    defer output.deinit();

    try output.append('H');
    try output.append('i');

    std.debug.print("{s}\n", .{output.items});
}
