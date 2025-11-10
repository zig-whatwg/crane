const std = @import("std");
const webidl = @import("webidl");
pub const ReadableStreamBYOBReader = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStreamBYOBReader {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *ReadableStreamBYOBReader) void {
        _ = self;
    }
});
