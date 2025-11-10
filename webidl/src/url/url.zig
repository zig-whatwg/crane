const std = @import("std");
const webidl = @import("webidl");
pub const URL = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !URL {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *URL) void {
        _ = self;
    }
}, .{
    .exposed = &.{.global},
});
