//! IndexedDB ED 2.12: copies independent of the underlying store or index.
const std = @import("std");
const Key = @import("key.zig").IDBKey;

pub const RecordSnapshot = struct {
    allocator: std.mem.Allocator,
    key: Key,
    primary_key: Key,
    value: []const u8,

    /// Copy both keys and the StructuredSerializeForStorage output atomically.
    pub fn init(allocator: std.mem.Allocator, key: Key, primary_key: Key, value: []const u8) std.mem.Allocator.Error!RecordSnapshot {
        var copied_key = try key.clone(allocator);
        errdefer copied_key.deinit();
        var copied_primary = try primary_key.clone(allocator);
        errdefer copied_primary.deinit();
        return .{
            .allocator = allocator,
            .key = copied_key,
            .primary_key = copied_primary,
            .value = try allocator.dupe(u8, value),
        };
    }

    pub fn deinit(self: *RecordSnapshot) void {
        self.key.deinit();
        self.primary_key.deinit();
        self.allocator.free(self.value);
    }
};
