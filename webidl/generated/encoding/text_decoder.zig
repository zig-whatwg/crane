const std = @import("std");
const webidl = @import("webidl");
pub const TextDecoder = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextDecoder { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextDecoder) void { _ = self; }
});
