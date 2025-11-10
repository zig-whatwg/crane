const std = @import("std");
const webidl = @import("webidl");
pub const ReadableStream = webidl.interface(struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStream { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ReadableStream) void { _ = self; }
});

pub const ReadableStreamIterator = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !ReadableStreamIterator { return .{ .allocator = allocator }; }
    pub fn deinit(self: *ReadableStreamIterator) void { _ = self; }
};
