const std = @import("std");
const webidl = @import("webidl");
pub const TextEncoderEncodeIntoResult = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextEncoderEncodeIntoResult { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextEncoderEncodeIntoResult) void { _ = self; }
});
