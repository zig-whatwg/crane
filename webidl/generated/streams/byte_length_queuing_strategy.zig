const std = @import("std");
const webidl = @import("webidl");
pub const ByteLengthQueuingStrategy = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ByteLengthQueuingStrategy { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ByteLengthQueuingStrategy) void { _ = self; }
});
