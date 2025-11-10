const std = @import("std");
const webidl = @import("webidl");
pub const TextEncoder = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !TextEncoder { return .{ .allocator = allocator }; }
    pub fn deinit(self: *TextEncoder) void { _ = self; }
});
