//! IndexedDB Database Implementation
//!
//! Implements IDBDatabase per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbdatabase
//!
//! ## Properties
//!
//! - `name` - Database name
//! - `version` - Database version
//! - `objectStoreNames` - List of object store names
//!
//! ## Methods
//!
//! - `transaction(storeNames, mode, options)` - Create a transaction
//! - `createObjectStore(name, options)` - Create an object store
//! - `deleteObjectStore(name)` - Delete an object store
//! - `close()` - Close the database connection
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbdatabase

const std = @import("std");
const IDBTransaction = @import("transaction.zig").IDBTransaction;
const IDBTransactionMode = @import("transaction.zig").IDBTransactionMode;
const IDBTransactionDurability = @import("transaction.zig").IDBTransactionDurability;
const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
const IDBError = @import("errors.zig").IDBError;

/// Options for createObjectStore
pub const IDBObjectStoreParameters = struct {
    /// Key path for the object store
    key_path: ?[]const u8 = null,
    /// Whether to auto-increment keys
    auto_increment: bool = false,
};

/// Options for transaction
pub const IDBTransactionOptions = struct {
    durability: IDBTransactionDurability = .default,
};

/// Object store metadata
const ObjectStoreMetadata = struct {
    name: []const u8,
    key_path: ?[]const u8,
    auto_increment: bool,
    /// Current auto-increment key value
    key_generator: u64,
    /// Index names
    index_names: std.ArrayListUnmanaged([]const u8),

    fn deinit(self: *ObjectStoreMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.key_path) |kp| {
            allocator.free(kp);
        }
        for (self.index_names.items) |name| {
            allocator.free(name);
        }
        self.index_names.deinit(allocator);
    }
};

/// IDBDatabase interface
/// https://w3c.github.io/IndexedDB/#idbdatabase
///
/// Represents a connection to a database.
pub const IDBDatabase = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Database name
    name: []const u8,

    /// Database version
    version: u64,

    /// Object stores in this database
    object_stores: std.StringHashMap(ObjectStoreMetadata),

    /// Whether the database connection is closed
    closed: bool,

    /// Active transactions
    transactions: std.ArrayListUnmanaged(*IDBTransaction),

    /// Version change transaction (if any)
    version_change_transaction: ?*IDBTransaction,

    /// Event handlers
    onabort: ?*const fn (*Self) void,
    onclose: ?*const fn (*Self) void,
    onerror: ?*const fn (*Self) void,
    onversionchange: ?*const fn (*Self, u64, ?u64) void,

    /// Initialize a new IDBDatabase
    pub fn init(allocator: std.mem.Allocator, name: []const u8, version: u64) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .version = version,
            .object_stores = std.StringHashMap(ObjectStoreMetadata).init(allocator),
            .closed = false,
            .transactions = .{},
            .version_change_transaction = null,
            .onabort = null,
            .onclose = null,
            .onerror = null,
            .onversionchange = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        var it = self.object_stores.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.object_stores.deinit();
        self.transactions.deinit(self.allocator);
    }

    /// Get object store names
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-objectstorenames
    pub fn objectStoreNames(self: *Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.object_stores.count());
        errdefer self.allocator.free(names);

        var idx: usize = 0;
        var it = self.object_stores.iterator();
        while (it.next()) |entry| {
            names[idx] = entry.value_ptr.name;
            idx += 1;
        }

        // Sort in ascending order per spec
        std.mem.sort([]const u8, names, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        return names;
    }

    /// Create a transaction
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-transaction
    ///
    /// Steps:
    /// 1. If connection is closing/closed, throw InvalidStateError
    /// 2. If storeNames is empty, throw InvalidAccessError
    /// 3. If mode is not valid, throw TypeError
    /// 4. Create and return transaction
    pub fn transaction(
        self: *Self,
        store_names: []const []const u8,
        mode: IDBTransactionMode,
        options: IDBTransactionOptions,
    ) IDBError!*IDBTransaction {
        // Step 1: Check if closed
        if (self.closed) {
            return IDBError.InvalidStateError;
        }

        // Step 2: Check if storeNames is empty
        if (store_names.len == 0) {
            return IDBError.InvalidAccessError;
        }

        // Verify all store names exist
        for (store_names) |name| {
            if (!self.object_stores.contains(name)) {
                return IDBError.NotFoundError;
            }
        }

        // Step 4: Create transaction
        const txn = try self.allocator.create(IDBTransaction);
        errdefer self.allocator.destroy(txn);

        txn.* = IDBTransaction.init(self.allocator, self, store_names, mode);
        txn.durability = options.durability;

        try self.transactions.append(self.allocator, txn);

        return txn;
    }

    /// Create an object store
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-createobjectstore
    ///
    /// Can only be called during a versionchange transaction.
    ///
    /// Steps:
    /// 1. Let transaction be this's upgrade transaction.
    /// 2. If transaction is null, throw InvalidStateError.
    /// 3. If transaction is not active, throw TransactionInactiveError.
    /// 4. If name already exists, throw ConstraintError.
    /// 5. Create object store and return IDBObjectStore.
    pub fn createObjectStore(
        self: *Self,
        name: []const u8,
        options: IDBObjectStoreParameters,
    ) IDBError!*IDBObjectStore {
        // Step 1-2: Check for versionchange transaction
        const txn = self.version_change_transaction orelse {
            return IDBError.InvalidStateError;
        };

        // Step 3: Check transaction is active
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Step 4: Check name doesn't exist
        if (self.object_stores.contains(name)) {
            return IDBError.ConstraintError;
        }

        // Step 5: Create object store
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);

        var key_path_copy: ?[]const u8 = null;
        if (options.key_path) |kp| {
            key_path_copy = try self.allocator.dupe(u8, kp);
        }
        errdefer if (key_path_copy) |kp| self.allocator.free(kp);

        const metadata = ObjectStoreMetadata{
            .name = name_copy,
            .key_path = key_path_copy,
            .auto_increment = options.auto_increment,
            .key_generator = 1, // Start at 1 per spec
            .index_names = .{},
        };

        try self.object_stores.put(name_copy, metadata);

        // Create IDBObjectStore handle
        const store = try self.allocator.create(IDBObjectStore);
        errdefer self.allocator.destroy(store);

        store.* = IDBObjectStore.init(self.allocator, name, txn);
        store.key_path = options.key_path;
        store.auto_increment = options.auto_increment;

        return store;
    }

    /// Delete an object store
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-deleteobjectstore
    ///
    /// Can only be called during a versionchange transaction.
    pub fn deleteObjectStore(self: *Self, name: []const u8) IDBError!void {
        // Check for versionchange transaction
        const txn = self.version_change_transaction orelse {
            return IDBError.InvalidStateError;
        };

        // Check transaction is active
        if (txn.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // Check name exists
        if (self.object_stores.fetchRemove(name)) |kv| {
            var metadata = kv.value;
            metadata.deinit(self.allocator);
        } else {
            return IDBError.NotFoundError;
        }
    }

    /// Close the database connection
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-close
    pub fn close(self: *Self) void {
        if (self.closed) return;

        self.closed = true;

        // Abort any active transactions
        for (self.transactions.items) |txn| {
            if (txn.state != .finished) {
                txn.abort() catch {};
            }
        }

        // Fire close event
        if (self.onclose) |handler| {
            handler(self);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBDatabase - init and deinit" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    try std.testing.expectEqualStrings("testdb", db.name);
    try std.testing.expectEqual(@as(u64, 1), db.version);
    try std.testing.expect(!db.closed);
}

test "IDBDatabase - close" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    try std.testing.expect(!db.closed);
    db.close();
    try std.testing.expect(db.closed);
}

test "IDBDatabase - transaction requires stores" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    // Empty store names should fail
    const result = db.transaction(&[_][]const u8{}, .readonly, .{});
    try std.testing.expectError(IDBError.InvalidAccessError, result);
}

test "IDBDatabase - transaction on closed db fails" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    db.close();

    const result = db.transaction(&[_][]const u8{"store"}, .readonly, .{});
    try std.testing.expectError(IDBError.InvalidStateError, result);
}

test "IDBDatabase - createObjectStore requires versionchange" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    // Without versionchange transaction, should fail
    const result = db.createObjectStore("store", .{});
    try std.testing.expectError(IDBError.InvalidStateError, result);
}

test "IDBDatabase - objectStoreNames" {
    const allocator = std.testing.allocator;

    var db = IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    // Empty initially
    const names = try db.objectStoreNames();
    defer allocator.free(names);

    try std.testing.expectEqual(@as(usize, 0), names.len);
}
