//! DOMTokenList interface per WHATWG DOM Standard

const std = @import("std");
const webidl = @import("webidl");
const infra = @import("infra");

pub const DOMTokenList = webidl.interface(struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) !DOMTokenList {
        return .{
            .allocator = allocator,
            .tokens = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *DOMTokenList) void {
        self.tokens.deinit();
    }

    pub fn call_add(self: *DOMTokenList, token: []const u8) !void {
        for (self.tokens.items) |t| {
            if (std.mem.eql(u8, t, token)) return;
        }
        try self.tokens.append(token);
    }

    pub fn call_remove(self: *DOMTokenList, token: []const u8) void {
        for (self.tokens.items, 0..) |t, i| {
            if (std.mem.eql(u8, t, token)) {
                _ = self.tokens.orderedRemove(i);
                return;
            }
        }
    }

    pub fn call_contains(self: *const DOMTokenList, token: []const u8) bool {
        for (self.tokens.items) |t| {
            if (std.mem.eql(u8, t, token)) return true;
        }
        return false;
    }

    pub fn get_length(self: *const DOMTokenList) u32 {
        return @intCast(self.tokens.items.len);
    }
});
