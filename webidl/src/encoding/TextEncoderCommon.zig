const std = @import("std");
const webidl = @import("webidl");
pub const TextEncoderCommon = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextEncoderCommon { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextEncoderCommon) void { _ = self; }
});
