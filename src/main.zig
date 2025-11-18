const std = @import("std");
const whatwg = @import("whatwg");

pub fn main() !void {
    std.debug.print("WHATWG Standards Implementation in Zig\n", .{});
    std.debug.print("Run `zig build test` to run the tests.\n", .{});
}
