const std = @import("std");
const webidl = @import("webidl");
pub const URLSearchParams = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !URLSearchParams {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *URLSearchParams) void {
        _ = self;
    }
}, .{
    .exposed = &.{.all},
});
