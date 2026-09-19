const std = @import("std");

pub fn main() !void {
    // std.heap.GeneralPurposeAllocator was renamed to std.heap.DebugAllocator in 0.16.
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var output = std.ArrayList(u8){};
    defer output.deinit();

    try output.append('H');
    try output.append('i');

    std.debug.print("{s}\n", .{output.items});
}
