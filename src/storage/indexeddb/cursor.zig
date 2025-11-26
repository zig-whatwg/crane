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
    ///
    /// Per spec:
    /// 1. If count is 0, throw TypeError
    /// 2. If transaction is not active, throw TransactionInactiveError
    /// 3. If cursor's got value flag is false, throw InvalidStateError
    /// 4. Set got value flag to false
    /// 5. Iterate cursor count times
    pub fn advance(self: *Self, cnt: u32) IDBError!void {
        // Step 1: If count is 0 (zero), throw a TypeError
        if (cnt == 0) {
            return IDBError.TypeError;
        }

        // Step 2: If transaction's state is not active, throw TransactionInactiveError
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Step 3: If cursor's got value flag is false (cursor being iterated or past end),
        // throw InvalidStateError
        if (!self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Step 4: Set cursor's got value flag to false
        self.got_value = false;

        // Step 5: Iterate cursor by count
        var i: u32 = 0;
        while (i < cnt) : (i += 1) {
            if (!self.moveToNext()) {
                break;
            }
        }
    }

    /// Continue to next position
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-continue
    ///
    /// Per spec:
    /// 1. If transaction's state is not active, throw TransactionInactiveError
    /// 2. If cursor's source or effective object store has been deleted, throw InvalidStateError
    /// 3. If cursor's got value flag is false, throw InvalidStateError
    /// 4. If key is given, validate it's in correct direction relative to current position
    /// 5. Set cursor's got value flag to false
    /// 6. Iterate cursor
    pub fn @"continue"(self: *Self, key: ?IDBKey) IDBError!void {
        // Step 1: If transaction's state is not active, throw TransactionInactiveError
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Step 2: If cursor's source or effective object store has been deleted, throw InvalidStateError
        // (Deletion detection would require additional tracking - skip for now as stores aren't deleted mid-cursor)

        // Step 3: If cursor's got value flag is false (cursor being iterated or past end),
        // throw InvalidStateError
        if (!self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Step 4: If key is given, validate direction
        if (key) |k| {
            if (self.key) |current_position| {
                const cmp = compareKeys(k, current_position);

                // If key <= position and direction is "next" or "nextunique", throw DataError
                if ((self.direction == .next or self.direction == .nextunique) and cmp <= 0) {
                    return IDBError.DataError;
                }

                // If key >= position and direction is "prev" or "prevunique", throw DataError
                if ((self.direction == .prev or self.direction == .prevunique) and cmp >= 0) {
                    return IDBError.DataError;
                }
            }
        }

        // Step 5: Set cursor's got value flag to false
        self.got_value = false;

        // Step 6: Iterate cursor
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
    }

    /// Continue to specific primary key (for index cursors)
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-continueprimarykey
    ///
    /// Per spec:
    /// 1. If transaction's state is not active, throw TransactionInactiveError
    /// 2. If cursor's source or effective object store has been deleted, throw InvalidStateError
    /// 3. If cursor's source is not an index, throw InvalidAccessError
    /// 4. If cursor's direction is not "next" or "prev", throw InvalidAccessError
    /// 5. If cursor's got value flag is false, throw InvalidStateError
    /// 6-12. Validate key and primaryKey are in correct direction
    /// 13. Set cursor's got value flag to false
    /// 14. Iterate cursor
    pub fn continuePrimaryKey(self: *Self, key: IDBKey, primary_key: IDBKey) IDBError!void {
        // Step 1: If transaction's state is not active, throw TransactionInactiveError
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Step 2: If cursor's source or effective object store has been deleted, throw InvalidStateError
        // (Deletion detection would require additional tracking - skip for now)

        // Step 3: If cursor's source is not an index, throw InvalidAccessError
        if (self.source != .index) {
            return IDBError.InvalidAccessError;
        }

        // Step 4: If cursor's direction is not "next" or "prev", throw InvalidAccessError
        // (nextunique and prevunique are not allowed for continuePrimaryKey)
        if (self.direction != .next and self.direction != .prev) {
            return IDBError.InvalidAccessError;
        }

        // Step 5: If cursor's got value flag is false, throw InvalidStateError
        if (!self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Steps 6-12: Validate key and primaryKey direction
        if (self.key) |current_position| {
            const key_cmp = compareKeys(key, current_position);

            // Step 13-14: If key < position and direction is "next", throw DataError
            if (self.direction == .next and key_cmp < 0) {
                return IDBError.DataError;
            }

            // Step 15-16: If key > position and direction is "prev", throw DataError
            if (self.direction == .prev and key_cmp > 0) {
                return IDBError.DataError;
            }

            // Steps 17-18: If key equals position, check primaryKey direction
            if (key_cmp == 0) {
                if (self.primary_key) |current_primary| {
                    const pk_cmp = compareKeys(primary_key, current_primary);

                    // If key == position and primaryKey <= object store position and direction is "next"
                    if (self.direction == .next and pk_cmp <= 0) {
                        return IDBError.DataError;
                    }

                    // If key == position and primaryKey >= object store position and direction is "prev"
                    if (self.direction == .prev and pk_cmp >= 0) {
                        return IDBError.DataError;
                    }
                }
            }
        }

        // Step 19: Set cursor's got value flag to false
        self.got_value = false;

        // Step 20: Iterate cursor to find matching keys
        while (self.moveToNext()) {
            if (self.key != null and self.primary_key != null) {
                const key_cmp = compareKeys(self.key.?, key);
                const pk_cmp = compareKeys(self.primary_key.?, primary_key);

                if (self.direction == .next) {
                    // For "next": find first record where key >= target key
                    // and if key == target key, primaryKey >= target primaryKey
                    if (key_cmp > 0 or (key_cmp == 0 and pk_cmp >= 0)) {
                        break;
                    }
                } else {
                    // For "prev": find first record where key <= target key
                    // and if key == target key, primaryKey <= target primaryKey
                    if (key_cmp < 0 or (key_cmp == 0 and pk_cmp <= 0)) {
                        break;
                    }
                }
            }
        }
    }

    /// Update current record
    /// https://w3c.github.io/IndexedDB/#dom-idbcursor-update
    ///
    /// Per spec:
    /// 1. If transaction's state is not active, throw TransactionInactiveError
    /// 2. If transaction is read-only, throw ReadOnlyError
    /// 3. If source or effective object store deleted, throw InvalidStateError
    /// 4. If cursor's got value flag is false, throw InvalidStateError
    /// 5. If cursor's key only flag is true, throw InvalidStateError
    pub fn update(self: *Self, value: []const u8) IDBError!*IDBRequest {
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (txn.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // If cursor's got value flag is false (cursor being iterated or past end),
        // throw InvalidStateError
        if (!self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Note: key_only flag check would go here for key-only cursors
        if (self.key_only) {
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
    ///
    /// Per spec:
    /// 1. If transaction's state is not active, throw TransactionInactiveError
    /// 2. If transaction is read-only, throw ReadOnlyError
    /// 3. If source or effective object store deleted, throw InvalidStateError
    /// 4. If cursor's got value flag is false, throw InvalidStateError
    /// 5. If cursor's key only flag is true, throw InvalidStateError
    pub fn delete(self: *Self) IDBError!*IDBRequest {
        const txn = self.getTransaction();
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        if (txn.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // If cursor's got value flag is false (cursor being iterated or past end),
        // throw InvalidStateError
        if (!self.got_value) {
            return IDBError.InvalidStateError;
        }

        // Note: key_only flag check would go here for key-only cursors
        if (self.key_only) {
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
            self.got_value = false;
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
                    self.got_value = true;
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
                    self.got_value = true;
                    return;
                }
            }
        }

        // No match found
        self.position = null;
        self.key = null;
        self.value = null;
        self.got_value = false;
    }

    fn moveToFirstIndex(self: *Self) void {
        const idx = self.source.index;
        const entries = idx.entries.items;

        if (entries.len == 0) {
            self.position = null;
            self.key = null;
            self.primary_key = null;
            self.got_value = false;
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
                    self.got_value = true;
                    return;
                }
            }
        } else {
            for (entries, 0..) |*entry, i| {
                if (self.matchesRange(entry.index_key)) {
                    self.position = i;
                    self.key = entry.index_key;
                    self.primary_key = entry.primary_key;
                    self.got_value = true;
                    return;
                }
            }
        }

        self.position = null;
        self.key = null;
        self.primary_key = null;
        self.got_value = false;
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
                    self.got_value = true;
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
                    self.got_value = true;
                    return true;
                }
                pos += 1;
            }
        }

        // No more records
        self.position = null;
        self.key = null;
        self.value = null;
        self.got_value = false;
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
                    self.got_value = true;
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
                    self.got_value = true;
                    return true;
                }
                pos += 1;
            }
        }

        self.position = null;
        self.key = null;
        self.primary_key = null;
        self.got_value = false;
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

test "IDBCursor - advance with zero count throws TypeError" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add some records (need to destroy returned requests)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);
    const req2 = try store.put("value2", IDBKey.number(2));
    defer allocator.destroy(req2);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // advance(0) should throw TypeError
    try std.testing.expectError(IDBError.TypeError, cursor.advance(0));
}

test "IDBCursor - advance throws InvalidStateError when got_value is false" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Empty store - cursor has no value
    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // got_value should be false for empty store
    try std.testing.expect(!cursor.got_value);

    // advance should throw InvalidStateError
    try std.testing.expectError(IDBError.InvalidStateError, cursor.advance(1));
}

test "IDBCursor - continue throws InvalidStateError when got_value is false" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Empty store - cursor has no value
    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // got_value should be false for empty store
    try std.testing.expect(!cursor.got_value);

    // continue should throw InvalidStateError
    try std.testing.expectError(IDBError.InvalidStateError, cursor.@"continue"(null));
}

test "IDBCursor - continue with key in wrong direction throws DataError" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add records (need to destroy returned requests)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);
    const req2 = try store.put("value2", IDBKey.number(2));
    defer allocator.destroy(req2);
    const req3 = try store.put("value3", IDBKey.number(3));
    defer allocator.destroy(req3);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // Cursor should be at position 0 with key 1
    try std.testing.expect(cursor.got_value);
    try std.testing.expectEqual(@as(f64, 1), cursor.key.?.value.number);

    // continue with key <= current position should throw DataError for "next" direction
    try std.testing.expectError(IDBError.DataError, cursor.@"continue"(IDBKey.number(1)));
    try std.testing.expectError(IDBError.DataError, cursor.@"continue"(IDBKey.number(0)));
}

test "IDBCursor - continuePrimaryKey throws InvalidAccessError for non-index cursor" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add records (need to destroy returned request)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // continuePrimaryKey should throw InvalidAccessError for object store cursor
    try std.testing.expectError(
        IDBError.InvalidAccessError,
        cursor.continuePrimaryKey(IDBKey.number(1), IDBKey.number(1)),
    );
}

test "IDBCursor - got_value is true after cursor finds record" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add records (need to destroy returned requests)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);
    const req2 = try store.put("value2", IDBKey.number(2));
    defer allocator.destroy(req2);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // After init with records, got_value should be true
    try std.testing.expect(cursor.got_value);
    try std.testing.expectEqual(@as(f64, 1), cursor.key.?.value.number);

    // After successful continue, got_value should be true again
    try cursor.@"continue"(null);
    try std.testing.expect(cursor.got_value);
    try std.testing.expectEqual(@as(f64, 2), cursor.key.?.value.number);
}

test "IDBCursor - advance sets got_value to false then true on success" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add records (need to destroy returned requests)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);
    const req2 = try store.put("value2", IDBKey.number(2));
    defer allocator.destroy(req2);
    const req3 = try store.put("value3", IDBKey.number(3));
    defer allocator.destroy(req3);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // After init, at position 1
    try std.testing.expect(cursor.got_value);
    try std.testing.expectEqual(@as(f64, 1), cursor.key.?.value.number);

    // Advance by 2 to get to position 3
    try cursor.advance(2);
    try std.testing.expect(cursor.got_value);
    try std.testing.expectEqual(@as(f64, 3), cursor.key.?.value.number);
}

test "IDBCursor - advance past end sets got_value to false" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // Add records (need to destroy returned requests)
    const req1 = try store.put("value1", IDBKey.number(1));
    defer allocator.destroy(req1);
    const req2 = try store.put("value2", IDBKey.number(2));
    defer allocator.destroy(req2);

    var cursor = IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // After init, at position 1
    try std.testing.expect(cursor.got_value);

    // Advance past end (only 2 records, advancing by 10)
    try cursor.advance(10);

    // After going past end, got_value should be false
    try std.testing.expect(!cursor.got_value);
    try std.testing.expect(cursor.position == null);
}
