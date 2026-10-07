//! Roots bridging a native Instance result to the binding's return conversion.
const std = @import("std");
const infra = @import("infra");

/// Hold is an independent owned engine value; release must not invoke script.
/// The scheduled microtask borrows the enclosing agent state, not this list.
pub fn PendingReturns(comptime Realm: type, comptime Hold: type) type {
    return struct {
        const Self = @This();
        const Entry = struct { realm: Realm, hold: ?Hold };
        entries: infra.List(Entry),
        scheduled: bool = false,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .entries = infra.List(Entry).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.releaseAll();
            self.entries.deinit();
        }

        /// Takes hold only on success; true asks the owner to schedule a
        /// microtask. A rejected schedule calls releaseAll before returning.
        pub fn append(self: *Self, realm: Realm, hold: Hold) !bool {
            try self.entries.append(.{ .realm = realm, .hold = hold });
            if (self.scheduled) return false;
            self.scheduled = true;
            return true;
        }

        pub fn clearRealm(self: *Self, realm: Realm) void {
            for (self.entries.toSliceMut()) |*entry| {
                if (entry.realm != realm) continue;
                const hold = entry.hold orelse continue;
                entry.hold = null;
                hold.release();
            }
        }

        pub fn releaseAll(self: *Self) void {
            for (self.entries.toSliceMut()) |*entry| {
                const hold = entry.hold orelse continue;
                entry.hold = null;
                // Owned handles belong to the agent, even after their realm
                // retires. Releasing one never dereferences an Instance.
                hold.release();
            }
            self.entries.clear();
            self.scheduled = false;
        }
    };
}
