const std = @import("std");
const webidl = @import("webidl");

pub const CountQueuingStrategy = webidl.interface(struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !CountQueuingStrategy {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CountQueuingStrategy) void {
        _ = self;
    }
});
