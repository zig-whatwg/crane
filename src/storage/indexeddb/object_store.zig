//! IndexedDB Object Store Implementation
//!
//! Implements IDBObjectStore per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbobjectstore
//!
//! ## Properties
//!
//! - `name` - Object store name
//! - `keyPath` - Key path
//! - `indexNames` - Index names
//! - `transaction` - Associated transaction
//! - `autoIncrement` - Whether auto-increment is enabled
//!
//! ## Methods
//!
//! - `put(value, key)` - Add or update a record
//! - `add(value, key)` - Add a new record
//! - `delete(query)` - Delete records
//! - `clear()` - Clear all records
//! - `get(query)` - Get a record
//! - `getKey(query)` - Get a key
//! - `getAll(query, count)` - Get all matching records
//! - `getAllKeys(query, count)` - Get all matching keys
//! - `count(query)` - Count records
//! - `openCursor(query, direction)` - Open a cursor
//! - `openKeyCursor(query, direction)` - Open a key cursor
//! - `index(name)` - Access an index
//! - `createIndex(name, keyPath, options)` - Create an index
//! - `deleteIndex(name)` - Delete an index
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbobjectstore

const std = @import("std");
const IDBTransaction = @import("transaction.zig").IDBTransaction;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBIndex = @import("index.zig").IDBIndex;
const IDBCursor = @import("cursor.zig").IDBCursor;
const IDBCursorDirection = @import("cursor.zig").IDBCursorDirection;
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
const IDBError = @import("errors.zig").IDBError;
const key_path_mod = @import("key_path.zig");
const KeyPath = key_path_mod.KeyPath;
const ExtractedValue = key_path_mod.ExtractedValue;

/// Options for createIndex
pub const IDBIndexParameters = struct {
    /// Whether the index has unique keys
    unique: bool = false,
    /// Whether the index supports multiple keys per record
    multi_entry: bool = false,
};

/// Record in object store
pub const Record = struct {
    key: IDBKey,
    value: []const u8, // Serialized value

    fn deinit(self: *Record, allocator: std.mem.Allocator) void {
        var key_mut = self.key;
        key_mut.deinit();
        allocator.free(self.value);
    }
};

/// IDBObjectStore interface
/// https://w3c.github.io/IndexedDB/#idbobjectstore
///
/// Represents a named key-value store.
pub const IDBObjectStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Object store name
    name: []const u8,

    /// Associated transaction
    transaction: *IDBTransaction,

    /// Simple key path (null for out-of-line keys)
    /// This is for backward compatibility with existing code.
    /// For compound key paths, use compound_key_path.
    key_path: ?[]const u8,

    /// Compound key path (array of key paths)
    /// https://w3c.github.io/IndexedDB/#object-store-key-path
    ///
    /// When set, this takes precedence over key_path.
    /// Compound keys allow indexing by multiple properties, e.g., ["firstName", "lastName"]
    compound_key_path: ?[]const []const u8,

    /// Whether auto-increment is enabled
    auto_increment: bool,

    /// Index handles
    indexes: std.StringHashMap(*IDBIndex),

    /// Records (simplified in-memory storage)
    records: std.ArrayListUnmanaged(Record),

    /// Current auto-increment key value
    key_generator: u64,

    /// Initialize a new object store handle
    pub fn init(allocator: std.mem.Allocator, name: []const u8, transaction: *IDBTransaction) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .transaction = transaction,
            .key_path = null,
            .compound_key_path = null,
            .auto_increment = false,
            .indexes = std.StringHashMap(*IDBIndex).init(allocator),
            .records = .{},
            .key_generator = 1,
        };
    }

    /// Set a single key path (simple key)
    pub fn setKeyPath(self: *Self, path: []const u8) void {
        self.key_path = path;
        self.compound_key_path = null;
    }

    /// Set a compound key path (array of paths)
    /// https://w3c.github.io/IndexedDB/#object-store-key-path
    ///
    /// Compound keys allow indexing by multiple properties, e.g., ["firstName", "lastName"]
    /// Results in array keys like [firstName_value, lastName_value]
    pub fn setCompoundKeyPath(self: *Self, paths: []const []const u8) void {
        self.compound_key_path = paths;
        self.key_path = null;
    }

    /// Check if this object store uses in-line keys
    /// https://w3c.github.io/IndexedDB/#object-store-in-line-keys
    ///
    /// An object store has in-line keys if it has a key path.
    pub fn usesInlineKeys(self: *const Self) bool {
        return self.key_path != null or self.compound_key_path != null;
    }

    /// Check if this object store uses a compound key path
    /// https://w3c.github.io/IndexedDB/#object-store-key-path
    pub fn hasCompoundKeyPath(self: *const Self) bool {
        return self.compound_key_path != null;
    }

    /// Get the key path as a string (for single paths only)
    /// Returns null for compound or missing key paths
    pub fn getKeyPathString(self: *const Self) ?[]const u8 {
        return self.key_path;
    }

    /// Get the key path as an array of strings (for compound paths)
    /// Returns null for single or missing key paths
    pub fn getKeyPathArray(self: *const Self) ?[]const []const u8 {
        return self.compound_key_path;
    }

    /// Get the effective key path (internal helper)
    /// Returns the key path in KeyPath union form
    fn getEffectiveKeyPath(self: *const Self) ?KeyPath {
        if (self.compound_key_path) |paths| {
            return .{ .array = paths };
        }
        if (self.key_path) |path| {
            return .{ .single = path };
        }
        return null;
    }

    /// Extract a key from a value using the object store's key path
    /// https://w3c.github.io/IndexedDB/#extract-a-key-from-a-value-using-a-key-path
    ///
    /// For compound key paths, returns an array key containing the values
    /// extracted from each path in order.
    ///
    /// Returns null if:
    /// - The object store doesn't use in-line keys
    /// - Any path in a compound key path doesn't exist in the value
    /// - The extracted value cannot be converted to a valid key
    pub fn extractKeyFromValue(self: *Self, value: ExtractedValue) IDBError!?IDBKey {
        const kp = self.getEffectiveKeyPath() orelse return null;

        const result = try key_path_mod.extractKeyOwned(self.allocator, value, kp, false);
        return switch (result) {
            .key => |k| k,
            .failure, .invalid => null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        var it = self.indexes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();

        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.deinit(self.allocator);
    }

    /// Get index names
    pub fn indexNames(self: *Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.indexes.count());
        errdefer self.allocator.free(names);

        var idx: usize = 0;
        var it = self.indexes.iterator();
        while (it.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// Add or update a record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-put
    pub fn put(self: *Self, value: []const u8, key: ?IDBKey) IDBError!*IDBRequest {
        return self.storeRecord(value, key, false);
    }

    /// Add a new record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-add
    pub fn add(self: *Self, value: []const u8, key: ?IDBKey) IDBError!*IDBRequest {
        return self.storeRecord(value, key, true);
    }

    /// Internal: Store a record
    /// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
    fn storeRecord(self: *Self, value: []const u8, key: ?IDBKey, no_overwrite: bool) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Get or generate key
        var record_key: IDBKey = undefined;

        if (key) |k| {
            record_key = try k.clone(self.allocator);

            // If auto-increment and key is a number, possibly update generator
            if (self.auto_increment and k.key_type == .number) {
                self.maybeUpdateKeyGenerator(k.value.number);
            }
        } else if (self.auto_increment) {
            // Generate key using key generator
            record_key = try self.generateKey();
        } else {
            return IDBError.DataError;
        }
        errdefer {
            var k = record_key;
            k.deinit();
        }

        // Check for existing record
        if (no_overwrite) {
            for (self.records.items) |*record| {
                if (@import("key.zig").compare(record.key, record_key) == 0) {
                    var k = record_key;
                    k.deinit();
                    return IDBError.ConstraintError;
                }
            }
        }

        // Store value
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        // Find and update or insert
        var found = false;
        for (self.records.items) |*record| {
            if (@import("key.zig").compare(record.key, record_key) == 0) {
                self.allocator.free(record.value);
                record.value = value_copy;
                found = true;
                break;
            }
        }

        if (!found) {
            try self.records.append(self.allocator, Record{
                .key = record_key,
                .value = value_copy,
            });
        } else {
            var k = record_key;
            k.deinit();
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .key = record_key });

        try self.transaction.addRequest(request);

        // Note: key_was_generated is reserved for future key injection into value
        // when in-line keys are used. Currently we don't modify the value.

        return request;
    }

    /// Generate a new key using the key generator
    /// https://w3c.github.io/IndexedDB/#key-generator-construct
    ///
    /// Key generator current number starts at 1 and increments.
    /// Maximum safe integer is 2^53 (9007199254740992).
    fn generateKey(self: *Self) IDBError!IDBKey {
        // Check if key generator is exhausted
        // Per spec: "If store uses a key generator and the key generator's
        // current number is greater than 2^53 (9007199254740992)"
        if (self.key_generator > 9007199254740992) {
            return IDBError.ConstraintError;
        }

        const key_value = self.key_generator;
        self.key_generator += 1;

        return IDBKey.number(@floatFromInt(key_value));
    }

    /// Possibly update key generator after storing a record with explicit key
    /// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
    ///
    /// Per spec step 16: "If key is greater than or equal to the current number
    /// of the key generator, then set the current number to the smallest
    /// integer that is greater than key."
    fn maybeUpdateKeyGenerator(self: *Self, key_value: f64) void {
        // Only update if key is a positive integer
        if (key_value < 0 or @floor(key_value) != key_value) {
            return;
        }

        const key_int: u64 = @intFromFloat(key_value);

        // Update generator if key >= current number
        if (key_int >= self.key_generator) {
            // Set to smallest integer greater than key
            // But don't exceed 2^53
            if (key_int < 9007199254740992) {
                self.key_generator = key_int + 1;
            } else {
                // Generator exhausted
                self.key_generator = 9007199254740993;
            }
        }
    }

    /// Get the current key generator value (for testing/debugging)
    pub fn getCurrentKeyGeneratorValue(self: *const Self) u64 {
        return self.key_generator;
    }

    /// Delete records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-delete
    pub fn delete(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Remove matching records
        var i: usize = 0;
        while (i < self.records.items.len) {
            const record = &self.records.items[i];
            if (query.includes(record.key)) {
                var removed = self.records.orderedRemove(i);
                removed.deinit(self.allocator);
            } else {
                i += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .undefined = {} });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Clear all records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-clear
    pub fn clear(self: *Self) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        // Remove all records
        for (self.records.items) |*record| {
            record.deinit(self.allocator);
        }
        self.records.clearRetainingCapacity();

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .undefined = {} });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Get a record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_value: ?[]const u8 = null;
        for (self.records.items) |*record| {
            if (query.includes(record.key)) {
                found_value = record.value;
                break;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;

        if (found_value) |v| {
            request.setResult(.{ .value = v });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try self.transaction.addRequest(request);

        return request;
    }

    /// Get a key
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_key: ?IDBKey = null;
        for (self.records.items) |*record| {
            if (query.includes(record.key)) {
                found_key = record.key;
                break;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;

        if (found_key) |k| {
            request.setResult(.{ .key = k });
        } else {
            request.setResult(.{ .undefined = {} });
        }

        try self.transaction.addRequest(request);

        return request;
    }

    /// Count records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching records
        var cnt: u64 = 0;
        for (self.records.items) |*record| {
            if (query) |q| {
                if (q.includes(record.key)) {
                    cnt += 1;
                }
            } else {
                cnt += 1;
            }
        }

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .count = cnt });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        cursor.* = IDBCursor.init(self.allocator, self, query, direction);

        // Create request
        const request = try self.allocator.create(IDBRequest);
        request.* = IDBRequest.init(self.allocator);
        request.source_type = .object_store;
        request.setResult(.{ .cursor = cursor });

        try self.transaction.addRequest(request);

        return request;
    }

    /// Access an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-index
    pub fn index(self: *Self, name: []const u8) IDBError!*IDBIndex {
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Check if we have a handle
        if (self.indexes.get(name)) |idx| {
            return idx;
        }

        // Index doesn't exist
        return IDBError.NotFoundError;
    }

    /// Create an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-createindex
    pub fn createIndex(
        self: *Self,
        name: []const u8,
        key_path: []const u8,
        options: IDBIndexParameters,
    ) IDBError!*IDBIndex {
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check name doesn't exist
        if (self.indexes.contains(name)) {
            return IDBError.ConstraintError;
        }

        // Create index
        const idx = try self.allocator.create(IDBIndex);
        errdefer self.allocator.destroy(idx);

        idx.* = IDBIndex.init(self.allocator, name, self);
        idx.key_path = key_path;
        idx.unique = options.unique;
        idx.multi_entry = options.multi_entry;

        try self.indexes.put(name, idx);

        return idx;
    }

    /// Delete an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-deleteindex
    pub fn deleteIndex(self: *Self, name: []const u8) IDBError!void {
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Remove index
        if (self.indexes.fetchRemove(name)) |kv| {
            kv.value.deinit();
            self.allocator.destroy(kv.value);
        } else {
            return IDBError.NotFoundError;
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBObjectStore - init" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    try std.testing.expectEqualStrings("store1", store.name);
}

test "IDBObjectStore - count empty" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    const request = try store.count(null);
    defer allocator.destroy(request);

    try std.testing.expect(request.done_flag);
    try std.testing.expectEqual(@as(u64, 0), request.result.?.count);
}

test "IDBObjectStore - setKeyPath single" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    store.setKeyPath("id");

    try std.testing.expect(store.usesInlineKeys());
    try std.testing.expect(!store.hasCompoundKeyPath());
    try std.testing.expectEqualStrings("id", store.getKeyPathString().?);
    try std.testing.expect(store.getKeyPathArray() == null);
    try std.testing.expect(store.compound_key_path == null);
}

test "IDBObjectStore - setCompoundKeyPath" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    const paths = [_][]const u8{ "firstName", "lastName" };
    store.setCompoundKeyPath(&paths);

    try std.testing.expect(store.usesInlineKeys());
    try std.testing.expect(store.hasCompoundKeyPath());
    try std.testing.expect(store.getKeyPathString() == null);

    const arr = store.getKeyPathArray().?;
    try std.testing.expectEqual(@as(usize, 2), arr.len);
    try std.testing.expectEqualStrings("firstName", arr[0]);
    try std.testing.expectEqualStrings("lastName", arr[1]);
}

test "IDBObjectStore - extractKeyFromValue with single path" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    store.setKeyPath("id");

    const props = [_]ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 123 } },
        .{ .key = "name", .value = .{ .string = "test" } },
    };
    const value = ExtractedValue{ .object = &props };

    var key = (try store.extractKeyFromValue(value)).?;
    defer key.deinit();

    try std.testing.expectEqual(@import("key.zig").IDBKeyType.number, key.key_type);
    try std.testing.expectEqual(@as(f64, 123), key.value.number);
}

test "IDBObjectStore - extractKeyFromValue with compound path" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    const paths = [_][]const u8{ "firstName", "lastName" };
    store.setCompoundKeyPath(&paths);

    const props = [_]ExtractedValue.Property{
        .{ .key = "firstName", .value = .{ .string = "John" } },
        .{ .key = "lastName", .value = .{ .string = "Smith" } },
    };
    const value = ExtractedValue{ .object = &props };

    var key = (try store.extractKeyFromValue(value)).?;
    defer key.deinit();

    // Should be an array key ["John", "Smith"]
    try std.testing.expectEqual(@import("key.zig").IDBKeyType.array, key.key_type);
    try std.testing.expectEqual(@as(usize, 2), key.value.array.len);
    try std.testing.expectEqualStrings("John", key.value.array[0].value.string);
    try std.testing.expectEqualStrings("Smith", key.value.array[1].value.string);
}

test "IDBObjectStore - extractKeyFromValue returns null for missing path" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    const paths = [_][]const u8{ "firstName", "lastName" };
    store.setCompoundKeyPath(&paths);

    // Object is missing lastName
    const props = [_]ExtractedValue.Property{
        .{ .key = "firstName", .value = .{ .string = "John" } },
    };
    const value = ExtractedValue{ .object = &props };

    const key = try store.extractKeyFromValue(value);
    try std.testing.expect(key == null);
}

test "IDBObjectStore - extractKeyFromValue returns null without key path" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    // No key path set - uses out-of-line keys
    const props = [_]ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 123 } },
    };
    const value = ExtractedValue{ .object = &props };

    const key = try store.extractKeyFromValue(value);
    try std.testing.expect(key == null);
}

// ============================================================================
// Auto-Increment Tests
// ============================================================================

test "IDBObjectStore - auto-increment generates sequential keys" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // First key should be 1
    const key1 = try store.generateKey();
    try std.testing.expectEqual(@as(f64, 1), key1.value.number);

    // Second key should be 2
    const key2 = try store.generateKey();
    try std.testing.expectEqual(@as(f64, 2), key2.value.number);

    // Third key should be 3
    const key3 = try store.generateKey();
    try std.testing.expectEqual(@as(f64, 3), key3.value.number);

    // Current generator should be 4
    try std.testing.expectEqual(@as(u64, 4), store.getCurrentKeyGeneratorValue());
}

test "IDBObjectStore - auto-increment updates generator for explicit keys" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // Current generator starts at 1
    try std.testing.expectEqual(@as(u64, 1), store.getCurrentKeyGeneratorValue());

    // Store record with explicit key 100
    store.maybeUpdateKeyGenerator(100);

    // Generator should now be 101
    try std.testing.expectEqual(@as(u64, 101), store.getCurrentKeyGeneratorValue());

    // Next generated key should be 101
    const key = try store.generateKey();
    try std.testing.expectEqual(@as(f64, 101), key.value.number);
}

test "IDBObjectStore - auto-increment ignores non-integer keys" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // Fractional numbers should not update generator
    store.maybeUpdateKeyGenerator(5.5);
    try std.testing.expectEqual(@as(u64, 1), store.getCurrentKeyGeneratorValue());

    // Negative numbers should not update generator
    store.maybeUpdateKeyGenerator(-10);
    try std.testing.expectEqual(@as(u64, 1), store.getCurrentKeyGeneratorValue());
}

test "IDBObjectStore - auto-increment lower key doesn't update generator" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // Generate some keys to advance generator
    _ = try store.generateKey(); // 1
    _ = try store.generateKey(); // 2
    _ = try store.generateKey(); // 3
    try std.testing.expectEqual(@as(u64, 4), store.getCurrentKeyGeneratorValue());

    // Explicit key lower than current should not update
    store.maybeUpdateKeyGenerator(2);
    try std.testing.expectEqual(@as(u64, 4), store.getCurrentKeyGeneratorValue());
}

test "IDBObjectStore - auto-increment add generates key" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // Add record without key - should generate key
    const req = try store.add("value1", null);
    defer allocator.destroy(req);

    try std.testing.expect(req.result != null);
    try std.testing.expectEqual(@as(f64, 1), req.result.?.key.value.number);

    // Add another - should get key 2
    const req2 = try store.add("value2", null);
    defer allocator.destroy(req2);

    try std.testing.expectEqual(@as(f64, 2), req2.result.?.key.value.number);
}
