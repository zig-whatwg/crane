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
const RecordData = @import("object_store.zig").RecordData;
const IDBError = @import("errors.zig").IDBError;
const key_path_mod = @import("key_path.zig");

/// Options for createObjectStore
pub const IDBObjectStoreParameters = struct {
    /// Key path for the object store
    key_path: ?[]const u8 = null,
    compound_key_path: ?[]const []const u8 = null,
    /// Whether to auto-increment keys
    auto_increment: bool = false,
};

/// Options for transaction
pub const IDBTransactionOptions = struct {
    durability: IDBTransactionDurability = .default,
};

/// Object store metadata
pub const ObjectStoreMetadata = struct {
    record_data: *RecordData,
    name: []const u8,
    key_path: ?[]const u8,
    compound_key_path: ?[]const []const u8 = null,
    auto_increment: bool,
    /// Current auto-increment key value
    key_generator: u64,
    /// Index names
    index_names: std.ArrayListUnmanaged([]const u8),

    fn clone(self: *const ObjectStoreMetadata, allocator: std.mem.Allocator) !ObjectStoreMetadata {
        const name = try allocator.dupe(u8, self.name);
        errdefer allocator.free(name);
        const path = if (self.key_path) |value| try allocator.dupe(u8, value) else null;
        errdefer if (path) |value| allocator.free(value);
        const compound = if (self.compound_key_path) |paths| try key_path_mod.copyPathList(allocator, paths) else null;
        errdefer if (compound) |paths| key_path_mod.freePathList(allocator, paths);
        const data = try self.record_data.clone();
        errdefer data.release();
        var names: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (names.items) |value| allocator.free(value);
            names.deinit(allocator);
        }
        try names.ensureTotalCapacity(allocator, self.index_names.items.len);
        for (self.index_names.items) |value| names.appendAssumeCapacity(try allocator.dupe(u8, value));
        return .{ .name = name, .key_path = path, .compound_key_path = compound, .auto_increment = self.auto_increment, .key_generator = self.key_generator, .index_names = names, .record_data = data };
    }

    fn deinit(self: *ObjectStoreMetadata, allocator: std.mem.Allocator) void {
        if (self.compound_key_path) |paths| key_path_mod.freePathList(allocator, paths);
        self.record_data.release();
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
    pub const Schema = std.StringHashMap(ObjectStoreMetadata);
    pub const NameSet = std.StringHashMapUnmanaged(void);

    allocator: std.mem.Allocator,

    // Native transactions hold a lease independent of wrapper GC order.
    backing: ?*Self = null,
    references: usize = 1,
    destroy_on_release: bool = false,
    owned_name: ?[]u8 = null,

    /// Database name
    name: []const u8,

    /// Database version
    version: u64,

    /// Object stores in this database
    object_stores: std.StringHashMap(ObjectStoreMetadata),
    /// ED 2.1.1: the connection's object-store set remains observable after
    /// close, independently of subsequent upgrades through other connections.
    connection_names: NameSet = .empty,

    /// Whether the database connection is closed
    closed: bool,

    /// Active transactions
    transactions: std.ArrayListUnmanaged(*IDBTransaction),
    /// ED 2.7.2 creation order across every connection to the same database.
    /// Borrowed entries are removed by their transaction's final native lease.
    scheduled_transactions: std.ArrayListUnmanaged(*IDBTransaction) = .empty,
    next_store_id: u64 = 1,

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
            .transactions = .empty,
            .version_change_transaction = null,
            .onabort = null,
            .onclose = null,
            .onerror = null,
            .onversionchange = null,
        };
    }

    /// Clean up resources
    pub fn deinitSchema(schema_map: *Schema, allocator: std.mem.Allocator) void {
        var iterator = schema_map.valueIterator();
        while (iterator.next()) |metadata| metadata.deinit(allocator);
        schema_map.deinit();
    }

    pub fn cloneSchema(self: *Self) !Schema {
        var copy = Schema.init(self.allocator);
        errdefer deinitSchema(&copy, self.allocator);
        var iterator = self.schema().valueIterator();
        while (iterator.next()) |metadata| {
            var cloned = try metadata.clone(self.allocator);
            errdefer cloned.deinit(self.allocator);
            try copy.put(cloned.name, cloned);
        }
        return copy;
    }

    pub fn deinitNames(allocator: std.mem.Allocator, names: *NameSet) void {
        var keys = names.keyIterator();
        while (keys.next()) |name| allocator.free(name.*);
        names.deinit(allocator);
    }

    pub fn copyConnectionNames(self: *Self) !void {
        std.debug.assert(self.connection_names.count() == 0);
        try self.connection_names.ensureTotalCapacity(self.allocator, self.schema().count());
        var definitions = self.schema().valueIterator();
        while (definitions.next()) |metadata| {
            const name = try self.allocator.dupe(u8, metadata.name);
            self.connection_names.putAssumeCapacity(name, {});
        }
    }

    pub fn cloneConnectionNames(self: *Self) !NameSet {
        var names: NameSet = .empty;
        errdefer deinitNames(self.allocator, &names);
        try names.ensureTotalCapacity(self.allocator, self.connection_names.count());
        var keys = self.connection_names.keyIterator();
        while (keys.next()) |key| {
            const name = try self.allocator.dupe(u8, key.*);
            names.putAssumeCapacity(name, {});
        }
        return names;
    }

    pub fn schema(self: *Self) *std.StringHashMap(ObjectStoreMetadata) {
        return if (self.backing) |database| database.schema() else &self.object_stores;
    }

    pub fn transactionQueue(self: *Self) *std.ArrayListUnmanaged(*IDBTransaction) {
        return if (self.backing) |database| database.transactionQueue() else &self.scheduled_transactions;
    }

    pub fn allocateStoreId(self: *Self) u64 {
        if (self.backing) |database| return database.allocateStoreId();
        const id = self.next_store_id;
        self.next_store_id += 1;
        return id;
    }

    pub fn publishVersion(self: *Self) void {
        if (self.backing) |database| database.version = self.version;
    }

    pub fn retain(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references += 1;
    }

    /// Release a heap-allocated wrapper's owner lease. The final transaction
    /// releases the allocation if the wrapper was collected first.
    pub fn releaseHeapOwnership(self: *Self) void {
        self.destroy_on_release = true;
        self.deinit();
    }

    pub fn deinit(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references -= 1;
        if (self.references != 0) return;
        var it = self.object_stores.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.object_stores.deinit();
        deinitNames(self.allocator, &self.connection_names);
        self.transactions.deinit(self.allocator);
        self.scheduled_transactions.deinit(self.allocator);
        if (self.backing) |database| database.deinit();
        if (self.owned_name) |name| self.allocator.free(name);
        if (self.destroy_on_release) self.allocator.destroy(self);
    }

    /// Get object store names
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-objectstorenames
    pub fn objectStoreNames(self: *Self) ![][]const u8 {
        const names = try self.allocator.alloc([]const u8, self.connection_names.count());
        errdefer self.allocator.free(names);

        var idx: usize = 0;
        var it = self.connection_names.keyIterator();
        while (it.next()) |entry| {
            names[idx] = entry.*;
            idx += 1;
        }

        // Sort in ascending order per spec
        std.mem.sort([]const u8, names, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return @import("key.zig").compareStrings(a, b) < 0;
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
            if (!self.schema().contains(name)) {
                return IDBError.NotFoundError;
            }
        }

        // Step 4: Create transaction
        const txn = try self.allocator.create(IDBTransaction);
        errdefer self.allocator.destroy(txn);

        txn.* = IDBTransaction.init(self.allocator, self, &.{}, mode);
        errdefer txn.deinit();
        try txn.copyScope(store_names);
        txn.durability = options.durability;

        // Publish neither borrowed entry until both reservations succeed.
        try self.transactions.ensureUnusedCapacity(self.allocator, 1);
        try self.transactionQueue().ensureUnusedCapacity(self.allocator, 1);
        self.transactions.appendAssumeCapacity(txn);
        self.transactionQueue().appendAssumeCapacity(txn);

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

        // 4.4 createObjectStore steps 4-6: validate the path before the name.
        if (options.key_path) |path| if (!key_path_mod.isValidKeyPath(path)) return IDBError.InvalidKeyPathError;
        if (options.compound_key_path) |paths| for (paths) |path| {
            if (!key_path_mod.isValidKeyPath(path)) return IDBError.InvalidKeyPathError;
        };
        if (self.schema().contains(name)) {
            return IDBError.ConstraintError;
        }
        // Step 8: a generator cannot inject through an empty or compound path.
        if (options.auto_increment and (options.compound_key_path != null or
            (options.key_path != null and options.key_path.?.len == 0))) return IDBError.InvalidAccessError;

        try txn.ensureRollbackSnapshot();

        // Step 5: Create object store
        const name_copy = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(name_copy);
        const visible_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(visible_name);
        try self.connection_names.ensureUnusedCapacity(self.allocator, 1);

        var key_path_copy: ?[]const u8 = null;
        if (options.key_path) |kp| {
            key_path_copy = try self.allocator.dupe(u8, kp);
        }
        errdefer if (key_path_copy) |kp| self.allocator.free(kp);
        const compound = if (options.compound_key_path) |paths| try key_path_mod.copyPathList(self.allocator, paths) else null;
        errdefer if (compound) |paths| key_path_mod.freePathList(self.allocator, paths);

        const data = try self.allocator.create(RecordData);
        data.* = .{ .allocator = self.allocator, .definition_id = self.allocateStoreId() };
        errdefer data.release();
        const metadata = ObjectStoreMetadata{
            .record_data = data,
            .name = name_copy,
            .key_path = key_path_copy,
            .compound_key_path = compound,
            .auto_increment = options.auto_increment,
            .key_generator = 1, // Start at 1 per spec
            .index_names = .empty,
        };

        // Allocate the handle before transferring metadata to the map.
        // No fallible operation may run after the transfer while its errdefers own it.
        // Create IDBObjectStore handle
        const store = try self.allocator.create(IDBObjectStore);
        errdefer self.allocator.destroy(store);

        store.* = IDBObjectStore.init(self.allocator, name_copy, txn);
        errdefer store.deinit();
        try store.copyDefinition(name_copy, key_path_copy);
        if (compound) |paths| try store.copyCompoundKeyPath(paths);
        store.auto_increment = options.auto_increment;
        try self.schema().put(name_copy, metadata);
        self.connection_names.putAssumeCapacity(visible_name, {});
        store.attachRecords(data);

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

        // Step 4: validate the name before allocating any rollback storage.
        if (!self.schema().contains(name)) return IDBError.NotFoundError;
        try txn.ensureRollbackSnapshot();
        // Reserve the retirement slot before publishing deletion. The handle
        // remains allocated for existing wrappers, but a recreation gets a new one.
        if (txn.object_stores.get(name)) |handle| {
            try txn.retired_stores.ensureUnusedCapacity(txn.allocator, 1);
            try handle.preserveSchemaForRollback();
        }
        var metadata = self.schema().fetchRemove(name).?.value;
        // Steps 5-7: invalidate every handle sharing this definition.
        metadata.record_data.deleted = true;
        if (txn.object_stores.fetchRemove(name)) |entry| {
            // Step 6 changes this handle's set, including after commit. Older
            // finished handles keep their independent index sets unchanged.
            entry.value.clearIndexNames();
            txn.retired_stores.appendAssumeCapacity(entry.value);
        }
        if (self.connection_names.fetchRemove(name)) |entry| self.allocator.free(entry.key);
        metadata.deinit(self.allocator);
    }

    /// Close the database connection
    /// https://w3c.github.io/IndexedDB/#dom-idbdatabase-close
    pub fn close(self: *Self) void {
        if (self.closed) return;

        self.closed = true;

        // Closing a connection, steps 1-2: accepted transactions keep running.
        // Its owner waits for their completion before releasing the connection.

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
