const std = @import("std");
const webidl = @import("webidl");
pub const TextEncoderStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextEncoderStream { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextEncoderStream) void { _ = self; }
});
