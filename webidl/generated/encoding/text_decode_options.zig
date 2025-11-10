const std = @import("std");
const webidl = @import("webidl");
pub const TextDecodeOptions = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextDecodeOptions { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextDecodeOptions) void { _ = self; }
});
