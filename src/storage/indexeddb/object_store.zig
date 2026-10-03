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

    pub fn deinit(self: *Record, allocator: std.mem.Allocator) void {
        var key_mut = self.key;
        key_mut.deinit();
        allocator.free(self.value);
    }
};

/// Records belong to a database store, not to an individual transaction handle.
pub const RecordData = struct {
    allocator: std.mem.Allocator,
    references: usize = 1,
    definition_id: u64 = 0,
    next_index_id: u64 = 1,
    deleted: bool = false,
    records: std.ArrayListUnmanaged(Record) = .empty,
    key_generator: u64 = 1,
    indexes: std.StringHashMapUnmanaged(*@import("index.zig").IndexData) = .empty,

    pub fn clone(self: *const RecordData) std.mem.Allocator.Error!*RecordData {
        const copy = try self.allocator.create(RecordData);
        copy.* = .{ .allocator = self.allocator, .key_generator = self.key_generator, .deleted = self.deleted, .definition_id = self.definition_id, .next_index_id = self.next_index_id };
        errdefer copy.release();
        try copy.records.ensureTotalCapacity(self.allocator, self.records.items.len);
        for (self.records.items) |record| {
            var key = try record.key.clone(self.allocator);
            errdefer key.deinit();
            const value = try self.allocator.dupe(u8, record.value);
            copy.records.appendAssumeCapacity(.{ .key = key, .value = value });
        }
        try copy.indexes.ensureTotalCapacity(self.allocator, self.indexes.count());
        var definitions = self.indexes.valueIterator();
        while (definitions.next()) |definition| {
            const index_data = try definition.*.clone();
            copy.indexes.putAssumeCapacity(index_data.name, index_data);
        }
        return copy;
    }

    pub fn retain(self: *RecordData) void {
        self.references += 1;
    }
    pub fn release(self: *RecordData) void {
        std.debug.assert(self.references > 0);
        self.references -= 1;
        if (self.references != 0) return;
        for (self.records.items) |*record| record.deinit(self.allocator);
        self.records.deinit(self.allocator);
        var definitions = self.indexes.valueIterator();
        while (definitions.next()) |definition| definition.*.release();
        self.indexes.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// IDBObjectStore interface
/// https://w3c.github.io/IndexedDB/#idbobjectstore
///
/// Represents a named key-value store.
pub const IDBObjectStore = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    references: usize = 1,
    destroy_on_release: bool = false,
    owned_name: ?[]u8 = null,
    owned_key_path: ?[]u8 = null,
    owned_compound_key_path: ?[]const []const u8 = null,
    /// ED 2.6 handles keep their own index set after the transaction finishes.
    index_names_view: std.StringHashMapUnmanaged(void) = .empty,
    rollback_index_names: ?std.StringHashMapUnmanaged(void) = null,
    rollback_name: ?[]u8 = null,
    next_index_id: u64 = 1,

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

    record_data: ?*RecordData = null,
    retired_indexes: std.ArrayListUnmanaged(*IDBIndex) = .empty,

    /// Records for a standalone handle
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
            .records = .empty,
            .key_generator = 1,
        };
    }

    pub fn copyDefinition(self: *Self, name: []const u8, key_path: ?[]const u8) !void {
        const copied_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(copied_name);
        const copied_path = if (key_path) |path| try self.allocator.dupe(u8, path) else null;
        if (self.owned_name) |old| self.allocator.free(old);
        if (self.owned_key_path) |old| self.allocator.free(old);
        if (self.owned_compound_key_path) |old| key_path_mod.freePathList(self.allocator, old);
        self.owned_compound_key_path = null;
        self.compound_key_path = null;
        self.owned_name = copied_name;
        self.owned_key_path = copied_path;
        self.name = copied_name;
        self.key_path = copied_path;
    }

    pub fn copyCompoundKeyPath(self: *Self, paths: []const []const u8) !void {
        const copy = try key_path_mod.copyPathList(self.allocator, paths);
        if (self.owned_key_path) |old| self.allocator.free(old);
        if (self.owned_compound_key_path) |old| key_path_mod.freePathList(self.allocator, old);
        self.owned_key_path = null;
        self.key_path = null;
        self.owned_compound_key_path = copy;
        self.compound_key_path = copy;
    }

    pub fn attachRecords(self: *Self, data: *RecordData) void {
        std.debug.assert(self.record_data == null);
        data.retain();
        self.record_data = data;
    }

    fn deinitNameSet(allocator: std.mem.Allocator, names: *std.StringHashMapUnmanaged(void)) void {
        var keys = names.keyIterator();
        while (keys.next()) |name| allocator.free(name.*);
        names.deinit(allocator);
    }

    pub fn snapshotIndexNames(self: *Self) !void {
        const data = self.record_data orelse return;
        std.debug.assert(self.index_names_view.count() == 0);
        try self.index_names_view.ensureTotalCapacity(self.allocator, data.indexes.count());
        var names = data.indexes.keyIterator();
        while (names.next()) |name| {
            const copy = try self.allocator.dupe(u8, name.*);
            self.index_names_view.putAssumeCapacity(copy, {});
        }
    }

    /// Prepare all metadata needed by ED 5.8 before a schema mutation. Abort
    /// can then restore visible names without allocating while it rolls back.
    pub fn preserveSchemaForRollback(self: *Self) !void {
        if (self.rollback_index_names != null) return;
        var names: std.StringHashMapUnmanaged(void) = .empty;
        errdefer deinitNameSet(self.allocator, &names);
        try names.ensureTotalCapacity(self.allocator, self.index_names_view.count());
        var keys = self.index_names_view.keyIterator();
        while (keys.next()) |name| {
            const copy = try self.allocator.dupe(u8, name.*);
            names.putAssumeCapacity(copy, {});
        }
        const name = try self.allocator.dupe(u8, self.name);
        self.rollback_name = name;
        self.rollback_index_names = names;
    }

    pub fn rename(self: *Self, name: []const u8) IDBError!void {
        // ED 4.5 name setter steps 4-8, in observable exception order.
        if (self.isDeleted() or self.transaction.mode != .versionchange) return IDBError.InvalidStateError;
        if (self.transaction.state != .active) return IDBError.TransactionInactiveError;
        if (std.mem.eql(u8, self.name, name)) return;
        const schema = self.transaction.db.schema();
        if (schema.contains(name)) return IDBError.ConstraintError;
        try self.transaction.ensureRollbackSnapshot();
        try self.preserveSchemaForRollback();
        const definition_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(definition_name);
        const handle_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(handle_name);
        const visible_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(visible_name);
        const connection_names = &self.transaction.db.connection_names;
        try connection_names.ensureUnusedCapacity(self.allocator, 1);
        // Steps 9-10: both maps have capacity after removing their old keys.
        var definition = schema.fetchRemove(self.name) orelse return IDBError.NotFoundError;
        const cached = self.transaction.object_stores.fetchRemove(self.name);
        if (connection_names.fetchRemove(self.name)) |entry| self.allocator.free(entry.key);
        connection_names.putAssumeCapacity(visible_name, {});
        self.allocator.free(definition.value.name);
        definition.value.name = definition_name;
        schema.putAssumeCapacity(definition_name, definition.value);
        if (self.owned_name) |old| self.allocator.free(old);
        self.owned_name = handle_name;
        self.name = handle_name;
        if (cached) |entry| self.transaction.object_stores.putAssumeCapacity(handle_name, entry.value);
    }

    pub fn rollbackSchema(self: *Self, original: ?*const @import("database.zig").ObjectStoreMetadata) void {
        // ED 5.5.2 and 5.8.5: identity, not a reused name, decides whether this
        // is an old store. New stores retain their last name but lose indexes.
        if (self.record_data) |data| data.deleted = original == null;
        if (original == null) {
            self.clearIndexNames();
        } else if (self.rollback_index_names) |names| {
            deinitNameSet(self.allocator, &self.index_names_view);
            self.index_names_view = names;
            self.rollback_index_names = null;
            // The finished transaction's handle map still borrows the current
            // name. Keep that allocation until handle destruction as well.
            std.mem.swap(?[]u8, &self.owned_name, &self.rollback_name);
            self.name = self.owned_name.?;
        }
        var indexes = self.indexes.valueIterator();
        while (indexes.next()) |handle| handle.*.rollbackSchema(if (original) |metadata| metadata.record_data else null);
        for (self.retired_indexes.items) |handle| handle.rollbackSchema(if (original) |metadata| metadata.record_data else null);
    }

    pub fn recordsList(self: *Self) *std.ArrayListUnmanaged(Record) {
        return if (self.record_data) |data| &data.records else &self.records;
    }

    fn generator(self: *const Self) *u64 {
        return if (self.record_data) |data| &data.key_generator else @constCast(&self.key_generator);
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

    /// An index/cursor wrapper retains its store independently of GC order.
    pub fn retain(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references += 1;
    }
    /// A newly created store wrapper transfers heap destruction to its last lease.
    pub fn releaseHeapOwnership(self: *Self) void {
        self.destroy_on_release = true;
        self.deinit();
    }
    /// Clean up resources
    pub fn deinit(self: *Self) void {
        std.debug.assert(self.references > 0);
        self.references -= 1;
        if (self.references != 0) return;
        if (self.owned_name) |name| self.allocator.free(name);
        if (self.owned_key_path) |path| self.allocator.free(path);
        if (self.owned_compound_key_path) |paths| key_path_mod.freePathList(self.allocator, paths);
        if (self.rollback_name) |name| self.allocator.free(name);
        if (self.rollback_index_names) |*names| deinitNameSet(self.allocator, names);
        deinitNameSet(self.allocator, &self.index_names_view);
        var it = self.indexes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.indexes.deinit();
        for (self.retired_indexes.items) |index_handle| {
            index_handle.deinit();
            self.allocator.destroy(index_handle);
        }
        self.retired_indexes.deinit(self.allocator);

        if (self.record_data) |data| {
            data.release();
        } else {
            for (self.records.items) |*record| record.deinit(self.allocator);
            self.records.deinit(self.allocator);
        }
        if (self.destroy_on_release) self.allocator.destroy(self);
    }

    /// ED 4.4 deleteObjectStore step 6 changes only the current handle's set.
    pub fn clearIndexNames(self: *Self) void {
        deinitNameSet(self.allocator, &self.index_names_view);
        self.index_names_view = .empty;
    }

    /// Get index names
    pub fn indexNames(self: *Self) ![][]const u8 {
        // deleteObjectStore step 6: a live deleted handle has an empty index set.
        if (self.isDeleted() and self.transaction.state != .finished)
            return self.allocator.alloc([]const u8, 0);
        const names = try self.allocator.alloc([]const u8, self.index_names_view.count());
        errdefer self.allocator.free(names);

        var idx: usize = 0;
        var it = self.index_names_view.iterator();
        while (it.next()) |entry| {
            names[idx] = entry.key_ptr.*;
            idx += 1;
        }

        return names;
    }

    /// All handles for this definition observe deletion, including the
    /// temporary handle returned by the native database creation operation.
    pub fn isDeleted(self: *const Self) bool {
        return if (self.record_data) |data| data.deleted else false;
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
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (!self.transaction.canExecuteRequest()) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        try self.transaction.ensureRollbackSnapshot();
        const old_generator = self.generator().*;
        errdefer self.generator().* = old_generator;

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

        // IDB 6.1 step 2: a failed add leaves the existing record intact.
        var existing: ?usize = null;
        var insertion: usize = self.recordsList().items.len;
        for (self.recordsList().items, 0..) |record, record_index| {
            const order = @import("key.zig").compare(record.key, record_key);
            if (order == 0) {
                if (no_overwrite) return IDBError.ConstraintError;
                existing = record_index;
                break;
            }
            if (order > 0 and insertion == self.recordsList().items.len) insertion = record_index;
        }

        // Allocate every fallible resource before transferring the key/value.
        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);
        const request = try self.allocator.create(IDBRequest);
        errdefer self.allocator.destroy(request);
        try self.transaction.requests.ensureUnusedCapacity(self.allocator, 1);
        if (existing == null) try self.recordsList().ensureUnusedCapacity(self.allocator, 1);

        // IDB 6.1 steps 3-4: replace the value, or publish a new record.
        const result_key = if (existing) |record_index| blk: {
            const record = &self.recordsList().items[record_index];
            self.allocator.free(record.value);
            record.value = value_copy;
            record_key.deinit();
            break :blk record.key;
        } else blk: {
            self.recordsList().insertAssumeCapacity(insertion, .{ .key = record_key, .value = value_copy });
            break :blk record_key;
        };
        request.* = IDBRequest.init(self.allocator);
        request.transaction = self.transaction;
        request.source_type = .object_store;
        request.setResult(.{ .key = result_key });
        self.transaction.requests.appendAssumeCapacity(request);
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
        if (self.generator().* > 9007199254740992) {
            return IDBError.ConstraintError;
        }

        const key_value = self.generator().*;
        self.generator().* += 1;

        return IDBKey.number(@floatFromInt(key_value));
    }

    /// Possibly update key generator after storing a record with explicit key
    /// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
    ///
    /// Per spec step 16: "If key is greater than or equal to the current number
    /// of the key generator, then set the current number to the smallest
    /// integer that is greater than key."
    fn maybeUpdateKeyGenerator(self: *Self, key_value: f64) void {
        // Possibly update the key generator, steps 1-6. Clamp before converting
        // to an integer: +Infinity is valid and exhausts the generator.
        if (std.math.isNan(key_value)) return;
        const value = @floor(@min(key_value, 9007199254740992));
        if (value < @as(f64, @floatFromInt(self.generator().*))) return;
        self.generator().* = @as(u64, @intFromFloat(value)) + 1;
    }

    /// Get the current key generator value (for testing/debugging)
    pub fn getCurrentKeyGeneratorValue(self: *const Self) u64 {
        return self.generator().*;
    }

    /// Delete records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-delete
    pub fn delete(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (!self.transaction.canExecuteRequest()) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        try self.transaction.ensureRollbackSnapshot();

        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);

        // ED 6.4 steps 1-2: records and all referencing index entries change
        // together, after the last fallible allocation.
        self.removeIndexEntries(query);
        var i: usize = 0;
        while (i < self.recordsList().items.len) {
            const record = &self.recordsList().items[i];
            if (query.includes(record.key)) {
                var removed = self.recordsList().orderedRemove(i);
                removed.deinit(self.allocator);
            } else {
                i += 1;
            }
        }

        // Create request
        request.completePrepared(.{ .undefined = {} });

        return request;
    }

    /// Clear all records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-clear
    pub fn clear(self: *Self) IDBError!*IDBRequest {
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (!self.transaction.canExecuteRequest()) {
            return IDBError.TransactionInactiveError;
        }

        // Check mode
        if (self.transaction.mode == .readonly) {
            return IDBError.ReadOnlyError;
        }

        try self.transaction.ensureRollbackSnapshot();

        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);

        // Remove all records
        for (self.recordsList().items) |*record| {
            record.deinit(self.allocator);
        }
        self.recordsList().clearRetainingCapacity();
        // ED 6.6 step 2: clear every referencing index as well.
        self.removeIndexEntries(IDBKeyRange.unbounded());

        // Create request
        request.completePrepared(.{ .undefined = {} });

        return request;
    }

    fn removeIndexEntries(self: *Self, range: IDBKeyRange) void {
        if (self.record_data) |data| {
            var indexes = data.indexes.valueIterator();
            while (indexes.next()) |index_data| index_data.*.removeEntriesInRange(range);
        } else {
            var indexes = self.indexes.valueIterator();
            while (indexes.next()) |index_handle| index_handle.*.removeEntriesInRange(range);
        }
        // Already accepted operations can still name a subsequently deleted
        // index; its retained physical data follows the same ordered deletion.
        for (self.retired_indexes.items) |index_handle| index_handle.removeEntriesInRange(range);
    }

    /// Get a record
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_value: ?[]const u8 = null;
        for (self.recordsList().items) |*record| {
            if (query.includes(record.key)) {
                found_value = record.value;
                break;
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);

        if (found_value) |v| {
            request.completePrepared(.{ .value = v });
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Get a key
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Find first matching record
        var found_key: ?IDBKey = null;
        for (self.recordsList().items) |*record| {
            if (query.includes(record.key)) {
                found_key = record.key;
                break;
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);

        if (found_key) |k| {
            request.completePrepared(.{ .key = k });
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Count records
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        if (self.isDeleted() and !self.transaction.executing_request) return IDBError.InvalidStateError;
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching records
        var cnt: u64 = 0;
        for (self.recordsList().items) |*record| {
            if (query) |q| {
                if (q.includes(record.key)) {
                    cnt += 1;
                }
            } else {
                cnt += 1;
            }
        }

        // Create request
        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);
        request.completePrepared(.{ .count = cnt });

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        if (self.isDeleted()) return IDBError.InvalidStateError;
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        errdefer self.allocator.destroy(cursor);
        cursor.* = try IDBCursor.init(self.allocator, self, query, direction);
        errdefer cursor.deinit();

        // Create request
        const request = try IDBRequest.prepare(self.allocator, self.transaction, .object_store);
        request.completePrepared(.{ .cursor = cursor });

        return request;
    }

    /// Access an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-index
    pub fn index(self: *Self, name: []const u8) IDBError!*IDBIndex {
        if (self.isDeleted()) return IDBError.InvalidStateError;
        // Check transaction state
        if (self.transaction.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Check if we have a handle
        if (self.indexes.get(name)) |idx| {
            return idx;
        }

        if (self.record_data) |records| {
            const data = records.indexes.get(name) orelse return IDBError.NotFoundError;
            const handle = try self.allocator.create(IDBIndex);
            errdefer self.allocator.destroy(handle);
            handle.* = IDBIndex.init(self.allocator, data.name, self);
            try handle.attachData(data);
            errdefer handle.deinit();
            try self.indexes.put(handle.name, handle);
            return handle;
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
        return self.createIndexWithKeyPath(name, .{ .single = key_path }, options);
    }

    pub fn createIndexWithKeyPath(self: *Self, name: []const u8, path: KeyPath, options: IDBIndexParameters) IDBError!*IDBIndex {
        if (self.isDeleted()) return IDBError.InvalidStateError;
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // IDB 4.5 createIndex steps 6-7: duplicate-name check precedes path validation.
        if (self.indexes.contains(name)) return IDBError.ConstraintError;
        if (self.record_data) |records| if (records.indexes.contains(name)) return IDBError.ConstraintError;
        switch (path) {
            .single => |key_path| if (!key_path_mod.isValidKeyPath(key_path)) return IDBError.InvalidKeyPathError,
            .array => |paths| for (paths) |key_path| {
                if (!key_path_mod.isValidKeyPath(key_path)) return IDBError.InvalidKeyPathError;
            },
        }
        // ED 4.5 createIndex step 10.
        if (path == .array and options.multi_entry) return IDBError.InvalidAccessError;
        try self.transaction.ensureRollbackSnapshot();
        try self.preserveSchemaForRollback();
        const visible_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(visible_name);
        const data = try @import("index.zig").IndexData.createWithKeyPath(self.allocator, name, path, options.unique, options.multi_entry);
        errdefer data.release();
        const idx = try self.allocator.create(IDBIndex);
        errdefer self.allocator.destroy(idx);
        idx.* = IDBIndex.init(self.allocator, data.name, self);
        try idx.attachData(data);
        errdefer idx.deinit();
        try self.indexes.ensureUnusedCapacity(1);
        try self.index_names_view.ensureUnusedCapacity(self.allocator, 1);
        if (self.record_data) |records| {
            try records.indexes.ensureUnusedCapacity(self.allocator, 1);
            data.definition_id = records.next_index_id;
            records.next_index_id += 1;
            records.indexes.putAssumeCapacity(data.name, data);
        } else {
            data.definition_id = self.next_index_id;
            self.next_index_id += 1;
            data.release();
        }
        self.indexes.putAssumeCapacity(idx.name, idx);
        self.index_names_view.putAssumeCapacity(visible_name, {});
        return idx;
    }

    /// Delete an index
    /// https://w3c.github.io/IndexedDB/#dom-idbobjectstore-deleteindex
    pub fn deleteIndex(self: *Self, name: []const u8) IDBError!void {
        if (self.isDeleted()) return IDBError.InvalidStateError;
        // Check for versionchange transaction
        if (self.transaction.mode != .versionchange) {
            return IDBError.InvalidStateError;
        }

        // Check transaction is active
        if (self.transaction.state != .active) {
            return IDBError.TransactionInactiveError;
        }

        // A deleted handle remains observable (name/keyPath/flags). Reserve
        // its retirement slot before changing schema or invalidating the handle.
        const cached = self.indexes.get(name);
        if (self.record_data) |records| {
            if (!records.indexes.contains(name)) return IDBError.NotFoundError;
        } else if (cached == null) return IDBError.NotFoundError;
        if (cached != null) try self.retired_indexes.ensureUnusedCapacity(self.allocator, 1);
        try self.preserveSchemaForRollback();
        try self.transaction.ensureRollbackSnapshot();
        if (self.record_data) |records| {
            const removed = records.indexes.fetchRemove(name).?;
            removed.value.release();
        }
        if (self.indexes.fetchRemove(name)) |removed| {
            removed.value.deleted = true;
            self.retired_indexes.appendAssumeCapacity(removed.value);
        }
        if (self.index_names_view.fetchRemove(name)) |removed| self.allocator.free(removed.key);
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

test "IDBObjectStore - auto-increment floors fractional numeric keys" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();
    store.auto_increment = true;

    // Generator steps 3-6: floor the number, then advance past it.
    store.maybeUpdateKeyGenerator(5.5);
    try std.testing.expectEqual(@as(u64, 6), store.getCurrentKeyGeneratorValue());

    // Negative numbers should not update generator
    store.maybeUpdateKeyGenerator(-10);
    try std.testing.expectEqual(@as(u64, 6), store.getCurrentKeyGeneratorValue());
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
