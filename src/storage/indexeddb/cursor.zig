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
    ) IDBError!Self {
        var cursor = Self{
            .allocator = allocator,
            .source = .{ .object_store = object_store },
            .range = try copyRange(allocator, range),
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
        errdefer cursor.deinit();
        _ = try cursor.seek(false);

        return cursor;
    }

    /// Initialize a cursor for an index
    pub fn initForIndex(
        allocator: std.mem.Allocator,
        index: *IDBIndex,
        range: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!Self {
        var cursor = Self{
            .allocator = allocator,
            .source = .{ .index = index },
            .range = try copyRange(allocator, range),
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
        errdefer cursor.deinit();
        _ = try cursor.seek(false);

        return cursor;
    }

    /// Range and visible record state are snapshots, never borrowed storage.
    pub fn deinit(self: *Self) void {
        self.clearSnapshot();
        if (self.range) |*range| range.deinit();
    }
    fn copyRange(allocator: std.mem.Allocator, range: ?IDBKeyRange) IDBError!?IDBKeyRange {
        const borrowed = range orelse return null;
        var result = IDBKeyRange.unbounded();
        result.allocator = allocator;
        result.lower_open = borrowed.lower_open;
        result.upper_open = borrowed.upper_open;
        errdefer result.deinit();
        if (borrowed.lower) |key| result.lower = try key.clone(allocator);
        if (borrowed.upper) |key| result.upper = try key.clone(allocator);
        return result;
    }
    fn clearSnapshot(self: *Self) void {
        if (self.key) |*key| key.deinit();
        if (self.primary_key) |*key| key.deinit();
        if (self.value) |value| self.allocator.free(value);
        self.key = null;
        self.primary_key = null;
        self.value = null;
    }
    fn setSnapshot(self: *Self, position: usize, key: IDBKey, primary: IDBKey, value: ?[]const u8) IDBError!void {
        var copied_key = try key.clone(self.allocator);
        errdefer copied_key.deinit();
        var copied_primary = try primary.clone(self.allocator);
        errdefer copied_primary.deinit();
        const copied_value = if (!self.key_only and value != null) try self.allocator.dupe(u8, value.?) else null;
        // IDB 6.7 steps 10-14: publish only after every snapshot allocation succeeds.
        self.clearSnapshot();
        self.position = position;
        self.key = copied_key;
        self.primary_key = copied_primary;
        self.value = copied_value;
        self.got_value = true;
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
        if (!txn.canExecuteRequest()) {
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
            if (!try self.moveToNext()) {
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
        if (!txn.canExecuteRequest()) {
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
            while (try self.moveToNext()) {
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
            _ = try self.moveToNext();
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
        if (!txn.canExecuteRequest()) {
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
        while (try self.moveToNext()) {
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
        if (!txn.canExecuteRequest()) {
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

        // IDB cursor update steps 10-11 run the ordinary store operation.
        // It recreates a deleted record and shares its allocation/rollback rules.
        const request = try store.put(value, self.primary_key orelse self.key);
        request.source_type = .cursor;
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
        if (!txn.canExecuteRequest()) {
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

        // Cursor delete steps 7-8 share the store operation's preallocation
        // and rollback. The visible cursor snapshot remains unchanged.
        const request = try store.delete(IDBKeyRange.only((self.primary_key orelse self.key).?));
        request.source_type = .cursor;
        return request;
    }

    // Internal helpers

    fn getTransaction(self: *Self) *@import("transaction.zig").IDBTransaction {
        return switch (self.source) {
            .object_store => |s| s.transaction,
            .index => |idx| idx.object_store.transaction,
        };
    }

    fn moveToNext(self: *Self) IDBError!bool {
        if (self.position == null) return false;
        return self.seek(true);
    }
    fn afterPosition(self: *Self, key: IDBKey, primary: IDBKey, advancing: bool) bool {
        if (!self.matchesRange(key)) return false;
        if (!advancing) return true;
        const order = compareKeys(key, self.key.?);
        const reverse = self.direction == .prev or self.direction == .prevunique;
        if (order != 0) return if (reverse) order < 0 else order > 0;
        if (self.source == .object_store or self.direction == .nextunique or self.direction == .prevunique) return false;
        const primary_order = compareKeys(primary, self.primary_key.?);
        return if (reverse) primary_order < 0 else primary_order > 0;
    }
    fn seek(self: *Self, advancing: bool) IDBError!bool {
        const reverse = self.direction == .prev or self.direction == .prevunique;
        // IDB 6.7 step 9: search by key/primary position every time. A record
        // index cannot be a cursor position: writes insert/delete earlier rows.
        switch (self.source) {
            .object_store => |store| {
                const records = store.recordsList().items;
                var offset: usize = 0;
                while (offset < records.len) : (offset += 1) {
                    const i = if (reverse) records.len - 1 - offset else offset;
                    const record = records[i];
                    if (!self.afterPosition(record.key, record.key, advancing)) continue;
                    try self.setSnapshot(i, record.key, record.key, record.value);
                    return true;
                }
            },
            .index => |index| {
                const entries = index.entriesList().items;
                var offset: usize = 0;
                while (offset < entries.len) : (offset += 1) {
                    var i = if (reverse) entries.len - 1 - offset else offset;
                    var entry = entries[i];
                    if (!self.afterPosition(entry.index_key, entry.primary_key, advancing)) continue;
                    // Step 9.1 prevunique: choose the FIRST record with this key,
                    // hence the lowest primary key, in both unique directions.
                    if (self.direction == .prevunique) {
                        while (i > 0 and compareKeys(entries[i - 1].index_key, entry.index_key) == 0) i -= 1;
                        entry = entries[i];
                    }
                    var value: ?[]const u8 = null;
                    for (index.object_store.recordsList().items) |record| {
                        if (compareKeys(record.key, entry.primary_key) == 0) {
                            value = record.value;
                            break;
                        }
                    }
                    try self.setSnapshot(i, entry.index_key, entry.primary_key, value);
                    return true;
                }
            },
        }
        // Step 9.2: no record. No later iteration can use this cursor.
        self.clearSnapshot();
        self.position = null;
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
    ) IDBError!IDBCursorWithValue {
        return IDBCursorWithValue{
            .cursor = try IDBCursor.init(allocator, object_store, range, direction),
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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
    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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
    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
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

    var cursor = try IDBCursor.init(allocator, &store, null, .next);
    defer cursor.deinit();

    // After init, at position 1
    try std.testing.expect(cursor.got_value);

    // Advance past end (only 2 records, advancing by 10)
    try cursor.advance(10);

    // After going past end, got_value should be false
    try std.testing.expect(!cursor.got_value);
    try std.testing.expect(cursor.position == null);
}
