const std = @import("std");
const webidl = @import("webidl");
pub const WritableStreamDefaultWriter = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !WritableStreamDefaultWriter { return .{ .allocator = allocator }; }
    pub fn deinit(self: *WritableStreamDefaultWriter) void { _ = self; }
});
