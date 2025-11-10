const std = @import("std");
const webidl = @import("webidl");
pub const TextDecoderCommon = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextDecoderCommon { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextDecoderCommon) void { _ = self; }
});
