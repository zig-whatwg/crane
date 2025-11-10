const std = @import("std");
const webidl = @import("webidl");
pub const ReadableStreamDefaultController = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStreamDefaultController { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ReadableStreamDefaultController) void { _ = self; }
});
