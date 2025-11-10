const std = @import("std");
const webidl = @import("webidl");
pub const TransformStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TransformStreamDefaultController { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TransformStreamDefaultController) void { _ = self; }
});
