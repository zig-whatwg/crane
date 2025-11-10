const std = @import("std");
const webidl = @import("webidl");
pub const TextDecoderOptions = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextDecoderOptions { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextDecoderOptions) void { _ = self; }
});
