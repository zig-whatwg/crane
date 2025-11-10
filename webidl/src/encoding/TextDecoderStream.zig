const std = @import("std");
const webidl = @import("webidl");
pub const TextDecoderStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextDecoderStream { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextDecoderStream) void { _ = self; }
});
