const std = @import("std");
const webidl = @import("webidl");
pub const WritableStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !WritableStreamDefaultController { return .{ .allocator = allocator }; }
    pub fn deinit(self: *WritableStreamDefaultController) void { _ = self; }
});
