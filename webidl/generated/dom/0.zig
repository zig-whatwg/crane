const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

pub const CustomEvent = webidl.interface(struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !CustomEvent {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CustomEvent) void {
        _ = self;
    }
});
