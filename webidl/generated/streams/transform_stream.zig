const std = @import("std");
const webidl = @import("webidl");
pub const TransformStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TransformStream { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TransformStream) void { _ = self; }
});
