const std = @import("std");
const webidl = @import("webidl");
pub const ReadableStreamDefaultReader = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStreamDefaultReader { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ReadableStreamDefaultReader) void { _ = self; }
});
