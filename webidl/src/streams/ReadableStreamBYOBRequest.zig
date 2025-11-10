const std = @import("std");
const webidl = @import("webidl");
pub const ReadableStreamBYOBRequest = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStreamBYOBRequest {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *ReadableStreamBYOBRequest) void {
        _ = self;
    }
});
