const std = @import("std");
const webidl = @import("webidl");
pub const ReadableByteStreamController = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableByteStreamController { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ReadableByteStreamController) void { _ = self; }
});
