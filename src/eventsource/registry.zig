//! Agent-owned live sources, visited by document abort/unloading hooks.
const std = @import("std");
const infra = @import("infra");

/// A native, non-owning registry. Its owner is one AgentHost, never a thread.
pub fn Registry(comptime Instance: type, comptime Realm: type) type {
    return struct {
        const Self = @This();
        /// Borrowed object and the realm whose document cleanup closes it.
        pub const Entry = struct { instance: Instance, realm: Realm };
        entries: infra.List(Entry),

        /// Construct the agent's empty list.
        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .entries = infra.List(Entry).init(allocator) };
        }
        /// Release list storage after the agent's realms have ended.
        pub fn deinit(self: *Self) void {
            self.entries.deinit();
        }
        /// Register exactly once; a source stays registered through retries.
        pub fn add(self: *Self, instance: Instance, realm: Realm) !void {
            for (self.entries.toSlice()) |entry| if (entry.instance == instance) return;
            try self.entries.append(.{ .instance = instance, .realm = realm });
        }
        /// close/failure/deinit may each remove the same source safely.
        pub fn remove(self: *Self, instance: Instance) void {
            for (self.entries.toSlice(), 0..) |entry, i| {
                if (entry.instance != instance) continue;
                _ = self.entries.remove(i) catch unreachable;
                return;
            }
        }
    };
}
