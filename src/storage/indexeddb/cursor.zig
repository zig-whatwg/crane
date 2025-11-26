//! IndexedDB Cursor Implementation
//!
//! Implements IDBCursor per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbcursor
//!
//! ## Properties
//!
//! - `source` - Object store or index
//! - `direction` - Cursor direction
//! - `key` - Current key
//! - `primaryKey` - Current primary key
//! - `request` - Associated request
//!
//! ## Methods
//!
//! - `advance(count)` - Advance cursor by count
//! - `continue(key)` - Continue to next position
//! - `continuePrimaryKey(key, primaryKey)` - Continue with both keys
//! - `update(value)` - Update current record
//! - `delete()` - Delete current record
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbcursor

const std = @import("std");
const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
const IDBIndex = @import("index.zig").IDBIndex;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
const IDBError = @import("errors.zig").IDBError;
const compareKeys = @import("key.zig").compare;

/// Cursor direction
/// https://w3c.github.io/IndexedDB/#cursor-direction
pub const IDBCursorDirection = enum {
    /// Iterate in ascending order
    next,
    /// Iterate in ascending order, skipping duplicates
    nextunique,
    /// Iterate in descending order
    prev,
    /// Iterate in descending order, skipping duplicates
    prevunique,
};

/// Cursor source type
pub const CursorSource = union(enum) {
    object_store: *IDBObjectStore,
    index: *IDBIndex,
};

/// IDBCursor interface
/// https://w3c.github.io/IndexedDB/#idbcursor
///
/// Iterates over records in a store or index.
pub const IDBCursor = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Source (object store or index)
    source: CursorSource,

    /// Key range to iterate
    range: ?IDBKeyRange,

    /// Cursor direction
    direction: IDBCursorDirection,

    /// Current position (index into records)
    position: ?usize,

    /// Current key
    key: ?IDBKey,

    /// Current primary key (for index cursors)
    primary_key: ?IDBKey,

    /// Current value (for cursors with value)
    value: ?[]const u8,

    /// Whether this is a key-only cursor
    key_only: bool,

    /// Whether cursor has been used
    got_value: bool,

    /// Associated request
    request: ?*IDBRequest,

    /// Initialize a cursor for an object store
    pub fn init(
        allocator: std.mem.Allocator,
        object_store: *IDBObjectStore,
        range: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) Self {
        var cursor = Self{
            .allocator = allocator,
            .source = .{ .object_store = object_store },
            .range = range,
            .direction = direction,
            .position = null,
            .key = null,
            .primary_key = null,
            .value = null,
            .key_only = false,
            .got_value = false,
            .request = null,
        };

        // Position cursor at first matching record
        cursor.moveToFirst();

        return cursor;
    }

    /// Initialize a cursor for an index
    pub fn initForIndex(
        allocator: std.mem.Allocator,
        index: *IDBIndex,
        range: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) Self {
        var cursor = Self{
            .allocator = allocator,
            .source = .{ .index = index },
            .range = range,
            .direction = direction,
            .position = null,
            .key = null,
            .primary_key = null,
            .value = null,
            .key_only = false,
            .got_value = false,
            .request = null,
        };

        // Position cursor at first matching entry
        cursor.moveToFirstIndex();

        return cursor;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        _ = self;
        // Keys are borrowed from records, don't free
    }

    /// Advance cursor by count positions
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-advance
    pub fn advance(self: *Self, cnt: u32) IDBError!void {
        if (cnt == 0) {
            return IDBError.TypeError;
        }

        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (self.position == null) {
            return IDBError.InvalidStateError;
        }

        // Advance by count
        var i: u32 = 0;
        while (i < cnt) : (i += 1) {
            if (!self.moveToNext()) {
                break;
            }
        }

        self.got_value = false;
    }

    /// Continue to next position
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-continue
    pub fn @"continue"(self: *Self, key: ?IDBKey) IDBError!void {
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (self.position == null) {
            return IDBError.InvalidStateError;
        }

        if (key) |k| {
            // Continue to specific key
            while (self.moveToNext()) {
                if (self.key) |current_key| {
                    const cmp = compareKeys(current_key, k);
                    if (self.direction == .next or self.direction == .nextunique) {
                        if (cmp >= 0) break;
                    } else {
                        if (cmp <= 0) break;
                    }
                }
            }
        } else {
            // Continue to next
            _ = self.moveToNext();
        }

        self.got_value = false;
    }

    /// Continue to specific primary key (for index cursors)
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-continueprimarykey
    pub fn continuePrimaryKey(self: *Self, key: IDBKey, primary_key: IDBKey) IDBError!void {
        // Only valid for index cursors
        if (self.source != .index) {
            return IDBError.InvalidAccessError;
        }

        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Continue until we find matching keys
        while (self.moveToNext()) {
            if (self.key != null and self.primary_key != null) {
                if (compareKeys(self.key.?, key) == 0 and
                    compareKeys(self.primary_key.?, primary_key) >= 0)
                {
                    break;
                }
            }
        }

        self.got_value = false;
    }

    /// Update current record
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-update
    pub fn update(self: *Self, value: []const u8) IDBError!*IDBRequest {
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (txn.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        if (self.position == null or self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Get the object store
        const store = switch (self.source) {
            .object_store => |s| s,
            .index => |idx| idx.object_store,
        };

        // Update the record
        if (self.primary_key orelse self.key) |pk| {
            for (store.records.items) |*record| {
                if (compareKeys(record.key, pk) == 0) {
                    store.allocator.free(record.value);
                    record.value = try store.allocator.dupe(u8, value);
                    break;
                }
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .cursor;
        request.setResult(.{ .key = self.key.? });

        try txn.addRequest(request);

        return request;
    }

    /// Delete current record
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-delete
    pub fn delete(self: *Self) IDBError!*IDBRequest {
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (txn.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        if (self.position == null or self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Get the object store
        const store = switch (self.source) {
            .object_store => |s| s,
            .index => |idx| idx.object_store,
        };

        // Delete the record
        if (self.primary_key orelse self.key) |pk| {
            var i: usize = 0;
            while (i < store.records.items.len) {
                const record = &store.records.items[i];
                if (compareKeys(record.key, pk) == 0) {
                    var removed = store.records.orderedRemove(i);
                    removed.deinit(store.allocator);
                    break;
                }
                i += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .cursor;
        request.setResult(.{ .undefined = {} });

        try txn.addRequest(request);

        return request;
    }

    // Internal helpers

    fn getTransaction(self: *Self) *@import("transaction.zig").IDBTransaction {
        return switch (self.source) {
            .object_store => |s| s.transaction,
            .index => |idx| idx.object_store.transaction,
        };
    }

    fn moveToFirst(self: *Self) void {
        const store = self.source.object_store;
        const records = store.records.items;

        if (records.len == 0) {
            self.position = null;
            self.key = null;
            self.value = null;
            return;
        }

        // Find first matching record based on direction
        if (self.direction == .prev or self.direction == .prevunique) {
            // Start from end
            var i: usize = records.len;
            while (i > 0) {
                i -= 1;
                if (self.matchesRange(records[i].key)) {
                    self.position = i;
                    self.key = records[i].key;
                    self.primary_key = records[i].key;
                    self.value = records[i].value;
                    return;
                }
            }
        } else {
            // Start from beginning
            for (records, 0..) |*record, i| {
                if (self.matchesRange(record.key)) {
                    self.position = i;
                    self.key = record.key;
                    self.primary_key = record.key;
                    self.value = record.value;
                    return;
                }
            }
        }

        // No match found
        self.position = null;
        self.key = null;
        self.value = null;
    }

    fn moveToFirstIndex(self: *Self) void {
        const idx = self.source.index;
        const entries = idx.entries.items;

        if (entries.len == 0) {
            self.position = null;
            self.key = null;
            self.primary_key = null;
            return;
        }

        // Find first matching entry based on direction
        if (self.direction == .prev or self.direction == .prevunique) {
            var i: usize = entries.len;
            while (i > 0) {
                i -= 1;
                if (self.matchesRange(entries[i].index_key)) {
                    self.position = i;
                    self.key = entries[i].index_key;
                    self.primary_key = entries[i].primary_key;
                    return;
                }
            }
        } else {
            for (entries, 0..) |*entry, i| {
                if (self.matchesRange(entry.index_key)) {
                    self.position = i;
                    self.key = entry.index_key;
                    self.primary_key = entry.primary_key;
                    return;
                }
            }
        }

        self.position = null;
        self.key = null;
        self.primary_key = null;
    }

    fn moveToNext(self: *Self) bool {
        if (self.position == null) return false;

        return switch (self.source) {
            .object_store => self.moveToNextStore(),
            .index => self.moveToNextIndex(),
        };
    }

    fn moveToNextStore(self: *Self) bool {
        const store = self.source.object_store;
        const records = store.records.items;
        var pos = self.position.?;

        if (self.direction == .prev or self.direction == .prevunique) {
            // Move backward
            while (pos > 0) {
                pos -= 1;
                if (self.matchesRange(records[pos].key)) {
                    // Check for unique direction
                    if (self.direction == .prevunique) {
                        if (self.key != null and compareKeys(records[pos].key, self.key.?) == 0) {
                            continue;
                        }
                    }
                    self.position = pos;
                    self.key = records[pos].key;
                    self.primary_key = records[pos].key;
                    self.value = records[pos].value;
                    return true;
                }
            }
        } else {
            // Move forward
            pos += 1;
            while (pos < records.len) {
                if (self.matchesRange(records[pos].key)) {
                    // Check for unique direction
                    if (self.direction == .nextunique) {
                        if (self.key != null and compareKeys(records[pos].key, self.key.?) == 0) {
                            pos += 1;
                            continue;
                        }
                    }
                    self.position = pos;
                    self.key = records[pos].key;
                    self.primary_key = records[pos].key;
                    self.value = records[pos].value;
                    return true;
                }
                pos += 1;
            }
        }

        // No more records
        self.position = null;
        self.key = null;
        self.value = null;
        return false;
    }

    fn moveToNextIndex(self: *Self) bool {
        const idx = self.source.index;
        const entries = idx.entries.items;
        var pos = self.position.?;

        if (self.direction == .prev or self.direction == .prevunique) {
            while (pos > 0) {
                pos -= 1;
                if (self.matchesRange(entries[pos].index_key)) {
                    if (self.direction == .prevunique) {
                        if (self.key != null and compareKeys(entries[pos].index_key, self.key.?) == 0) {
                            continue;
                        }
                    }
                    self.position = pos;
                    self.key = entries[pos].index_key;
                    self.primary_key = entries[pos].primary_key;
                    return true;
                }
            }
        } else {
            pos += 1;
            while (pos < entries.len) {
                if (self.matchesRange(entries[pos].index_key)) {
                    if (self.direction == .nextunique) {
                        if (self.key != null and compareKeys(entries[pos].index_key, self.key.?) == 0) {
                            pos += 1;
                            continue;
                        }
                    }
                    self.position = pos;
                    self.key = entries[pos].index_key;
                    self.primary_key = entries[pos].primary_key;
                    return true;
                }
                pos += 1;
            }
        }

        self.position = null;
        self.key = null;
        self.primary_key = null;
        return false;
    }

    fn matchesRange(self: *Self, key: IDBKey) bool {
        if (self.range) |range| {
            return range.includes(key);
        }
        return true;
    }
};

/// IDBCursorWithValue interface
/// https://w3c.github.io/IndexedDB/#idbcursorwithvalue
///
/// Cursor that also exposes the current value.
pub const IDBCursorWithValue = struct {
    cursor: IDBCursor,

    pub fn init(
        allocator: std.mem.Allocator,
        object_store: *IDBObjectStore,
        range: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBCursorWithValue {
        return IDBCursorWithValue{
            .cursor = IDBCursor.init(allocator, object_store, range, direction),
        };
    }

    pub fn deinit(self: *IDBCursorWithValue) void {
        self.cursor.deinit();
    }

    /// Get current value
    pub fn getValue(self: *IDBCursorWithValue) ?[]const u8 {
        return self.cursor.value;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBCursor - init empty store" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // Empty store - position should be null
    try std.testing.expect(cursor.position == null);
    try std.testing.expect(cursor.key == null);
}

test "IDBCursor - direction enum" {
    try std.testing.expectEqual(IDBCursorDirection.next, .next);
    try std.testing.expectEqual(IDBCursorDirection.nextunique, .nextunique);
    try std.testing.expectEqual(IDBCursorDirection.prev, .prev);
    try std.testing.expectEqual(IDBCursorDirection.prevunique, .prevunique);
}
