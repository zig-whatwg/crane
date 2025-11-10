const std = @import("std");
const webidl = @import("webidl");
pub const WritableStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !WritableStream { return .{ .allocator = allocator }; }
    pub fn deinit(self: *WritableStream) void { _ = self; }
});
