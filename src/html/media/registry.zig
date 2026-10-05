//! Borrowed media-element records owned by one AgentHost, never by a thread.
const std = @import("std");
const infra = @import("infra");

/// The element removes its entry when loading ends, fails, is cancelled, or
/// deinit runs. Unload/document-fetch hooks filter by realm and walk backwards,
/// re-checking the index after each callback, which may remove other entries.
pub fn Registry(comptime Instance: type, comptime Realm: type) type {
    return struct {
        const Self = @This();
        pub const Entry = struct { instance: Instance, realm: Realm };
        entries: infra.List(Entry),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .entries = infra.List(Entry).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }

        /// An in-flight load is registered once even if it retries candidates.
        pub fn add(self: *Self, instance: Instance, realm: Realm) !void {
            for (self.entries.toSlice()) |entry| if (entry.instance == instance) return;
            try self.entries.append(.{ .instance = instance, .realm = realm });
        }

        /// Re-load, failure, unload and deinit may remove the same entry safely.
        pub fn remove(self: *Self, instance: Instance) void {
            for (self.entries.toSlice(), 0..) |entry, index| {
                if (entry.instance != instance) continue;
                _ = self.entries.remove(index) catch unreachable;
                return;
            }
        }
    };
}
