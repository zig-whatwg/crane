//! IndexedDB Index Implementation
//!
//! Implements IDBIndex per W3C IndexedDB 3.0 specification.
//! https://w3c.github.io/IndexedDB/#idbindex
//!
//! ## Properties
//!
//! - `name` - Index name
//! - `objectStore` - Associated object store
//! - `keyPath` - Key path for index keys
//! - `multiEntry` - Whether multi-entry is enabled
//! - `unique` - Whether keys must be unique
//!
//! ## Methods
//!
//! - `get(query)` - Get a record by index key
//! - `getKey(query)` - Get a primary key by index key
//! - `getAll(query, count)` - Get all matching records
//! - `getAllKeys(query, count)` - Get all matching primary keys
//! - `count(query)` - Count records
//! - `openCursor(query, direction)` - Open a cursor
//! - `openKeyCursor(query, direction)` - Open a key cursor
//!
//! ## Spec Reference
//!
//! https://w3c.github.io/IndexedDB/#idbindex

const std = @import("std");
const IDBObjectStore = @import("object_store.zig").IDBObjectStore;
const IDBRequest = @import("request.zig").IDBRequest;
const IDBCursor = @import("cursor.zig").IDBCursor;
const IDBCursorDirection = @import("cursor.zig").IDBCursorDirection;
const IDBKey = @import("key.zig").IDBKey;
const IDBKeyRange = @import("key_range.zig").IDBKeyRange;
const IDBError = @import("errors.zig").IDBError;
const key_path_mod = @import("key_path.zig");
const backing_store = @import("backing_store.zig");
const compareKeys = @import("key.zig").compare;

/// The length of 04 db store index: what precedes an entry's keys.
pub const entry_prefix_len = 1 + 8 + 8 + 8;

/// Persistent index definition and records, shared by transaction handles.
pub const IndexData = struct {
    allocator: std.mem.Allocator,
    /// Atomic: handles on several threads hold one index's data.
    references: std.atomic.Value(usize) = .init(1),
    definition_id: u64 = 0,
    name: []u8,
    key_path: ?[]const u8,
    compound_key_path: ?[]const []const u8 = null,
    unique: bool,
    multi_entry: bool,

    pub fn create(allocator: std.mem.Allocator, name: []const u8, path: []const u8, unique: bool, multi_entry: bool) std.mem.Allocator.Error!*IndexData {
        return createWithKeyPath(allocator, name, .{ .single = path }, unique, multi_entry);
    }
    pub fn createWithKeyPath(allocator: std.mem.Allocator, name: []const u8, path: key_path_mod.KeyPath, unique: bool, multi_entry: bool) std.mem.Allocator.Error!*IndexData {
        const data = try allocator.create(IndexData);
        errdefer allocator.destroy(data);
        const copied_name = try allocator.dupe(u8, name);
        errdefer allocator.free(copied_name);
        const copied_path = if (path == .single) try allocator.dupe(u8, path.single) else null;
        errdefer if (copied_path) |value| allocator.free(value);
        const compound = if (path == .array) try key_path_mod.copyPathList(allocator, path.array) else null;
        data.* = .{ .allocator = allocator, .name = copied_name, .key_path = copied_path, .compound_key_path = compound, .unique = unique, .multi_entry = multi_entry };
        return data;
    }
    pub fn clone(self: *const IndexData) std.mem.Allocator.Error!*IndexData {
        const path: key_path_mod.KeyPath = if (self.compound_key_path) |paths| .{ .array = paths } else .{ .single = self.key_path.? };
        const copy = try createWithKeyPath(self.allocator, self.name, path, self.unique, self.multi_entry);
        errdefer copy.release();
        copy.definition_id = self.definition_id;
        return copy;
    }
    pub fn retain(self: *IndexData) void {
        _ = self.references.fetchAdd(1, .monotonic);
    }
    pub fn release(self: *IndexData) void {
        const before = self.references.fetchSub(1, .acq_rel);
        std.debug.assert(before > 0);
        if (before != 1) return;
        self.allocator.free(self.name);
        if (self.key_path) |path| self.allocator.free(path);
        if (self.compound_key_path) |paths| key_path_mod.freePathList(self.allocator, paths);
        self.allocator.destroy(self);
    }
};

/// IDBIndex interface
/// https://w3c.github.io/IndexedDB/#idbindex
///
/// Represents a secondary index on an object store.
pub const IDBIndex = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Index name
    name: []const u8,
    owned_name: ?[]u8 = null,
    rollback_name: ?[]u8 = null,

    /// Associated object store
    object_store: *IDBObjectStore,

    /// Key path for extracting index keys
    key_path: ?[]const u8,
    compound_key_path: ?[]const []const u8 = null,

    /// Whether keys must be unique
    unique: bool,

    /// Whether multi-entry is enabled
    /// (array values create multiple index entries)
    multi_entry: bool,

    /// The definition whose entries this handle reads and writes (in the
    /// backing store under (database, store, definition_id); lane prof1).
    data: ?*IndexData = null,
    deleted: bool = false,
    /// The entry `entryAt` read last, held until the next read or the
    /// handle's end.
    peeked: ?Entry = null,

    /// Initialize a new index handle
    pub fn init(allocator: std.mem.Allocator, name: []const u8, object_store: *IDBObjectStore) Self {
        return Self{
            .allocator = allocator,
            .name = name,
            .object_store = object_store,
            .key_path = null,
            .unique = false,
            .multi_entry = false,
        };
    }

    pub fn attachData(self: *Self, data: *IndexData) std.mem.Allocator.Error!void {
        std.debug.assert(self.data == null);
        if (self.owned_name == null) self.owned_name = try self.allocator.dupe(u8, data.name);
        data.retain();
        self.data = data;
        self.name = self.owned_name.?;
        self.key_path = data.key_path;
        self.compound_key_path = data.compound_key_path;
        self.unique = data.unique;
        self.multi_entry = data.multi_entry;
    }
    /// The definition, made for a standalone handle (a native caller's)
    /// on first use, its id the store's next.
    pub fn indexData(self: *Self) IDBError!*IndexData {
        if (self.data) |existing| return existing;
        const records = try self.object_store.recordData();
        const path: key_path_mod.KeyPath = if (self.compound_key_path) |paths| .{ .array = paths } else .{ .single = self.key_path orelse "" };
        const made = try IndexData.createWithKeyPath(self.allocator, self.name, path, self.unique, self.multi_entry);
        made.definition_id = records.next_index_id;
        records.next_index_id += 1;
        self.data = made;
        return made;
    }

    /// 04 db store index, in the transaction's buffer `slot`.
    pub fn entryPrefixIn(self: *Self, txn: *backing_store.Transaction, slot: backing_store.Transaction.Slot) IDBError![]const u8 {
        const store_id = (try self.object_store.recordData()).definition_id;
        const index_id = (try self.indexData()).definition_id;
        const out = txn.buffer(slot);
        try backing_store.indexPrefix(out, txn.gpa(), self.object_store.databaseId(), store_id, index_id);
        return out.items;
    }

    /// The bounds of the entries whose index key is in `range` (null: all).
    pub fn entryBoundsIn(self: *Self, txn: *backing_store.Transaction, range: ?IDBKeyRange) IDBError!backing_store.Bounds {
        const prefix = try self.entryPrefixIn(txn, .prefix);
        const r = range orelse IDBKeyRange.unbounded();
        return backing_store.keyRangeBounds(txn.gpa(), prefix, r.lower, r.lower_open, r.upper, r.upper_open, txn.buffer(.lower), txn.buffer(.upper));
    }

    /// An entry key's index key and primary key, decoded. OWNED.
    pub fn decodeEntry(allocator: std.mem.Allocator, entry_key: []const u8) IDBError!struct { index_key: IDBKey, primary_key: IDBKey } {
        var reader: backing_store.Reader = .{ .bytes = entry_key, .at = entry_prefix_len };
        var index_key = reader.key(allocator) catch |err| return backing_store.idbError(err);
        errdefer index_key.deinit();
        const primary_key = reader.key(allocator) catch |err| return backing_store.idbError(err);
        return .{ .index_key = index_key, .primary_key = primary_key };
    }

    /// The first entry whose index key is in `range`. OWNED.
    pub fn firstEntry(self: *Self, allocator: std.mem.Allocator, range: ?IDBKeyRange) IDBError!?struct { index_key: IDBKey, primary_key: IDBKey } {
        const txn = try self.object_store.backing();
        const bounds = try self.entryBoundsIn(txn, range);
        const entry = (txn.first(allocator, bounds, .forward) catch |err| return backing_store.idbError(err)) orelse return null;
        defer entry.deinit(allocator);
        const decoded = try decodeEntry(allocator, entry.key);
        return .{ .index_key = decoded.index_key, .primary_key = decoded.primary_key };
    }

    /// One entry: its index key and primary key. OWNED.
    pub const Entry = struct {
        index_key: IDBKey,
        primary_key: IDBKey,

        pub fn deinit(self: *Entry) void {
            self.index_key.deinit();
            self.primary_key.deinit();
        }
    };

    /// Every entry of the index, in order (index key, then primary key).
    /// OWNED; free with `freeEntries`.
    pub fn collectEntries(self: *Self, allocator: std.mem.Allocator) IDBError![]Entry {
        const txn = try self.object_store.backing();
        const bounds = try self.entryBoundsIn(txn, null);
        var list: std.ArrayListUnmanaged(Entry) = .empty;
        errdefer freeEntries(allocator, list.items);
        var walk = txn.iterate(bounds, .forward) catch |err| return backing_store.idbError(err);
        defer walk.close();
        while (walk.next(allocator) catch |err| return backing_store.idbError(err)) |raw| {
            defer raw.deinit(allocator);
            const decoded = try decodeEntry(allocator, raw.key);
            list.append(allocator, .{ .index_key = decoded.index_key, .primary_key = decoded.primary_key }) catch |err| {
                var lost: Entry = .{ .index_key = decoded.index_key, .primary_key = decoded.primary_key };
                lost.deinit();
                return err;
            };
        }
        return list.toOwnedSlice(allocator);
    }

    /// The `n`th entry in order, if any: held by the handle until the next
    /// read (a native caller's look at one entry).
    pub fn entryAt(self: *Self, n: usize) IDBError!?*const Entry {
        const entries = try self.collectEntries(self.allocator);
        defer self.allocator.free(entries);
        var chosen: ?Entry = null;
        for (entries, 0..) |*entry, i| {
            if (i == n) chosen = entry.* else entry.deinit();
        }
        if (self.peeked) |*old| old.deinit();
        self.peeked = chosen;
        return if (self.peeked) |*entry| entry else null;
    }

    pub fn freeEntries(allocator: std.mem.Allocator, entries: []Entry) void {
        for (entries) |*entry| entry.deinit();
        allocator.free(entries);
    }

    /// How many entries have an index key in `range` (null: all).
    pub fn entryCount(self: *Self, range: ?IDBKeyRange) IDBError!u64 {
        const txn = try self.object_store.backing();
        const bounds = try self.entryBoundsIn(txn, range);
        var walk = txn.iterate(bounds, .forward) catch |err| return backing_store.idbError(err);
        defer walk.close();
        var counted: u64 = 0;
        while (walk.next(txn.gpa()) catch |err| return backing_store.idbError(err)) |entry| {
            entry.deinit(txn.gpa());
            counted += 1;
        }
        return counted;
    }
    pub fn effectiveKeyPath(self: *const Self) ?key_path_mod.KeyPath {
        if (self.compound_key_path) |paths| return .{ .array = paths };
        if (self.key_path) |path| return .{ .single = path };
        return null;
    }
    /// Clean up resources; the database retains the persistent definition.
    pub fn deinit(self: *Self) void {
        if (self.owned_name) |name| self.allocator.free(name);
        if (self.rollback_name) |name| self.allocator.free(name);
        if (self.data) |data| data.release();
        if (self.peeked) |*entry| entry.deinit();
    }

    pub fn rename(self: *Self, name: []const u8) IDBError!void {
        const store = self.object_store;
        // ED 4.6 name setter steps 4-8: state precedes deletion for indexes.
        if (store.transaction.mode != .versionchange) return IDBError.InvalidStateError;
        if (store.transaction.state != .active) return IDBError.TransactionInactiveError;
        if (self.deleted or store.isDeleted()) return IDBError.InvalidStateError;
        if (std.mem.eql(u8, self.name, name)) return;
        if (store.index_names_view.contains(name)) return IDBError.ConstraintError;
        const data = self.data orelse return IDBError.InvalidStateError;
        try store.transaction.ensureRollbackSnapshot();
        try store.preserveSchemaForRollback();
        const definition_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(definition_name);
        const handle_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(handle_name);
        const view_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(view_name);
        if (self.rollback_name == null) self.rollback_name = try self.allocator.dupe(u8, self.name);
        // Steps 9-10: no allocation follows any map/name replacement.
        if (store.record_data) |records| _ = records.indexes.remove(data.name);
        _ = store.indexes.remove(self.name);
        const old_view = store.index_names_view.fetchRemove(self.name).?;
        self.allocator.free(old_view.key);
        self.allocator.free(data.name);
        data.name = definition_name;
        if (self.owned_name) |old| self.allocator.free(old);
        self.owned_name = handle_name;
        self.name = handle_name;
        if (store.record_data) |records| records.indexes.putAssumeCapacity(definition_name, data);
        store.indexes.putAssumeCapacity(handle_name, self);
        store.index_names_view.putAssumeCapacity(view_name, {});
    }

    pub fn rollbackSchema(self: *Self, original_store: ?*const @import("object_store.zig").RecordData) void {
        var existed = false;
        if (original_store) |store| if (self.data) |data| {
            var definitions = store.indexes.valueIterator();
            while (definitions.next()) |definition| {
                if (definition.*.definition_id == data.definition_id) {
                    existed = true;
                    break;
                }
            }
        };
        self.deleted = !existed;
        // ED 5.8.6: newly created indexes retain their last name on abort.
        if (existed and self.rollback_name != null) {
            std.mem.swap(?[]u8, &self.owned_name, &self.rollback_name);
            self.name = self.owned_name.?;
        }
    }

    /// Get a record by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-get
    pub fn get(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if ((self.deleted or self.object_store.isDeleted()) and !self.object_store.transaction.executing_request) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // The first entry in range, and its record's value.
        var found = try self.firstEntry(self.allocator, query);
        defer if (found) |*entry| {
            entry.index_key.deinit();
            entry.primary_key.deinit();
        };
        const kept = txn.allocator;
        const found_value: ?[]u8 = if (found) |entry| try self.object_store.recordValue(kept, entry.primary_key) else null;
        errdefer if (found_value) |value| kept.free(value);

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);

        if (found_value) |v| {
            request.completeOwnedValue(v);
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Get a primary key by index key
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-getkey
    pub fn getKey(self: *Self, query: IDBKeyRange) IDBError!*IDBRequest {
        if ((self.deleted or self.object_store.isDeleted()) and !self.object_store.transaction.executing_request) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // The first entry in range: its primary key (the transaction keeps
        // it, made with its allocator).
        var found = try self.firstEntry(txn.allocator, query);
        if (found) |*entry| entry.index_key.deinit();
        errdefer if (found) |*entry| entry.primary_key.deinit();

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);

        if (found) |entry| {
            request.completeOwnedKey(entry.primary_key);
        } else {
            request.completePrepared(.{ .undefined = {} });
        }

        return request;
    }

    /// Count matching entries
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-count
    pub fn count(self: *Self, query: ?IDBKeyRange) IDBError!*IDBRequest {
        if ((self.deleted or self.object_store.isDeleted()) and !self.object_store.transaction.executing_request) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Count matching entries
        const cnt = try self.entryCount(query);

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .count = cnt });

        return request;
    }

    /// Open a cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-opencursor
    pub fn openCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor
        const cursor = try self.allocator.create(IDBCursor);
        errdefer self.allocator.destroy(cursor);
        cursor.* = try IDBCursor.initForIndex(self.allocator, self, query, direction);
        errdefer cursor.deinit();

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .cursor = cursor });

        return request;
    }

    /// Open a key cursor
    /// https://w3c.github.io/IndexedDB/#dom-idbindex-openkeycursor
    pub fn openKeyCursor(
        self: *Self,
        query: ?IDBKeyRange,
        direction: IDBCursorDirection,
    ) IDBError!*IDBRequest {
        if (self.deleted) return IDBError.InvalidStateError;
        const txn = self.object_store.transaction;

        // Check transaction state
        if (txn.state == .finished) {
            return IDBError.InvalidStateError;
        }

        // Create cursor (key-only mode)
        const cursor = try self.allocator.create(IDBCursor);
        errdefer self.allocator.destroy(cursor);
        cursor.* = try IDBCursor.initForIndex(self.allocator, self, query, direction);
        errdefer cursor.deinit();
        cursor.key_only = true;

        // Create request
        const request = try IDBRequest.prepare(self.allocator, txn, .index);
        request.completePrepared(.{ .cursor = cursor });

        return request;
    }

    /// Native operation staging: no entry is written before every
    /// constraint is checked (IDB 2.7 request atomicity). The index keys of
    /// one record, copied; `commit` writes them to the transaction's batch.
    pub const PreparedEntries = struct {
        allocator: std.mem.Allocator,
        keys: std.ArrayListUnmanaged(IDBKey) = .empty,
        primary_key: ?IDBKey = null,
        pub fn deinit(self: *PreparedEntries) void {
            for (self.keys.items) |*key| key.deinit();
            self.keys.deinit(self.allocator);
            if (self.primary_key) |*key| key.deinit();
            self.primary_key = null;
        }
        /// IDB 6.1 steps 5.5-5.6: an entry per index key (04), and the
        /// record's reverse row (05) listing them, in the transaction's
        /// batch.
        pub fn commit(self: *PreparedEntries, index: *Self) IDBError!void {
            const primary = self.primary_key orelse return;
            if (self.keys.items.len == 0) return;
            const txn = try index.object_store.backing();
            const alloc = txn.gpa();
            const index_id = (try index.indexData()).definition_id;
            var row_value: std.ArrayListUnmanaged(u8) = .empty;
            defer row_value.deinit(alloc);
            for (self.keys.items) |key| {
                const entry = try index.entryPrefixIn(txn, .aux_key);
                const out = &txn.scratch[@backingInt(backing_store.Transaction.Slot.aux_key)];
                try backing_store.appendKey(out, alloc, key);
                try backing_store.appendKey(out, alloc, primary);
                _ = entry;
                try txn.put(out.items, "");
                try backing_store.appendKey(&row_value, alloc, key);
            }
            // A record filed under the index already (a second commit for
            // it, with no removal between): its row lists both.
            const row = try alloc.dupe(u8, try index.reverseRowIn(txn, primary, index_id));
            defer alloc.free(row);
            if (txn.get(alloc, row) catch |err| return backing_store.idbError(err)) |existing| {
                defer alloc.free(existing);
                try row_value.insertSlice(alloc, 0, existing);
            }
            try txn.put(row, row_value.items);
        }
    };

    /// The reverse row of (`primary`, index `index_id`): 05 db store
    /// key(primary) index, in the transaction's aux_lower buffer.
    fn reverseRowIn(self: *Self, txn: *backing_store.Transaction, primary: IDBKey, index_id: u64) IDBError![]const u8 {
        _ = try self.object_store.reversePrefixIn(txn, .aux_lower);
        const out = &txn.scratch[@backingInt(backing_store.Transaction.Slot.aux_lower)];
        try backing_store.appendKey(out, txn.gpa(), primary);
        try backing_store.appendU64(out, txn.gpa(), index_id);
        return out.items;
    }

    pub fn prepareEntries(self: *Self, keys: []const IDBKey, primary_key: IDBKey) IDBError!PreparedEntries {
        return self.prepareEntriesForWrite(keys, primary_key, false);
    }
    pub fn prepareReplacementEntries(self: *Self, keys: []const IDBKey, primary_key: IDBKey) IDBError!PreparedEntries {
        return self.prepareEntriesForWrite(keys, primary_key, true);
    }
    fn prepareEntriesForWrite(self: *Self, keys: []const IDBKey, primary_key: IDBKey, replacement: bool) IDBError!PreparedEntries {
        // IDB 6.1 steps 5.3-5.4: validate ALL subkeys before inserting any.
        if (self.unique) for (keys, 0..) |key, i| {
            if (try self.uniqueKeyTaken(key, primary_key, replacement)) return IDBError.ConstraintError;
            for (keys[0..i]) |previous| {
                if (compareKeys(previous, key) == 0) return IDBError.ConstraintError;
            }
        };
        var prepared = PreparedEntries{ .allocator = self.allocator };
        errdefer prepared.deinit();
        try prepared.keys.ensureTotalCapacity(self.allocator, keys.len);
        for (keys) |key| prepared.keys.appendAssumeCapacity(try key.clone(self.allocator));
        prepared.primary_key = try primary_key.clone(self.allocator);
        return prepared;
    }

    /// Whether an entry with index key `key` belongs to a record other than
    /// `primary_key` - or, unless `replacement`, to any record. 6.1 step 3
    /// removes the record's own old entries before the check; a replacement
    /// skips them.
    pub fn uniqueKeyTaken(self: *Self, key: IDBKey, primary_key: IDBKey, replacement: bool) IDBError!bool {
        const txn = try self.object_store.backing();
        const alloc = txn.gpa();
        const range = IDBKeyRange.only(key);
        const bounds = try self.entryBoundsIn(txn, range);
        var walk = txn.iterate(bounds, .forward) catch |err| return backing_store.idbError(err);
        defer walk.close();
        while (walk.next(alloc) catch |err| return backing_store.idbError(err)) |entry| {
            defer entry.deinit(alloc);
            if (!replacement) return true;
            var decoded = try decodeEntry(alloc, entry.key);
            defer decoded.index_key.deinit();
            defer decoded.primary_key.deinit();
            if (compareKeys(decoded.primary_key, primary_key) != 0) return true;
        }
        return false;
    }

    /// Add a single entry, retaining neither borrowed input key.
    pub fn addEntry(self: *Self, index_key: IDBKey, primary_key: IDBKey) IDBError!void {
        var prepared = try self.prepareEntries(&.{index_key}, primary_key);
        defer prepared.deinit();
        try prepared.commit(self);
    }

    /// Add entries for a value, handling multiEntry indexes
    /// https://w3c.github.io/IndexedDB/#store-a-record-into-an-object-store
    ///
    /// For multiEntry indexes:
    /// - If the extracted value is an array, creates an index entry for each element
    /// - Duplicate keys within the array are skipped
    /// - Nested array subkeys remain keys; only the outer array is unpacked
    ///
    /// For regular indexes:
    /// - Creates a single index entry for the extracted key
    pub fn addEntriesForValue(
        self: *Self,
        allocator: std.mem.Allocator,
        value: @import("key_path.zig").ExtractedValue,
        primary_key: IDBKey,
    ) IDBError!void {
        // Get the key path
        const kp = self.effectiveKeyPath() orelse return;

        // Extract key using the key path
        const result = try key_path_mod.extractKeyOwned(
            allocator,
            value,
            kp,
            self.multi_entry,
        );

        switch (result) {
            .failure, .invalid => {
                // Per spec step 5.2: If extraction fails or is invalid, skip this index
                return;
            },
            .key => |extracted_key| {
                defer {
                    var k = extracted_key;
                    k.deinit();
                }

                const keys: []const IDBKey = if (self.multi_entry and extracted_key.key_type == .array)
                    extracted_key.value.array
                else
                    &.{extracted_key};
                var prepared = try self.prepareEntries(keys, primary_key);
                defer prepared.deinit();
                try prepared.commit(self);
            },
        }
    }

    /// IDB 6.1 step 3: the record `primary_key`'s entries in this index go -
    /// the ones its reverse row lists - and the row with them.
    pub fn removeEntriesForPrimaryKey(self: *Self, primary_key: IDBKey) IDBError!void {
        const txn = try self.object_store.backing();
        const alloc = txn.gpa();
        const index_id = (try self.indexData()).definition_id;
        const row_key = try alloc.dupe(u8, try self.reverseRowIn(txn, primary_key, index_id));
        defer alloc.free(row_key);
        const row = (txn.get(alloc, row_key) catch |err| return backing_store.idbError(err)) orelse return;
        defer alloc.free(row);
        var doomed: std.ArrayListUnmanaged([]u8) = .empty;
        defer {
            for (doomed.items) |key| alloc.free(key);
            doomed.deinit(alloc);
        }
        try IDBObjectStore.collectIndexEntries(alloc, row_key, row, 1 + 8 + 8, &doomed);
        for (doomed.items) |key| try txn.delete(key);
        try txn.delete(row_key);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "IDBIndex - init" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "idx1", &store);
    defer idx.deinit();

    try std.testing.expectEqualStrings("idx1", idx.name);
    try std.testing.expect(!idx.unique);
    try std.testing.expect(!idx.multi_entry);
}

test "IDBIndex - count empty" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "idx1", &store);
    defer idx.deinit();

    const request = try idx.count(null);
    defer allocator.destroy(request);

    try std.testing.expect(request.done_flag);
    try std.testing.expectEqual(@as(u64, 0), request.result.?.count);
}

test "IDBIndex - multiEntry creates multiple entries" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = true;

    // Create value with tags array
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
        .{ .string = "green" },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "id", .value = .{ .number = 1 } },
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    // Add entries for the value
    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 3 entries (one per tag)
    try std.testing.expectEqual(@as(usize, 3), (try idx.entryCount(null)));

    // Verify index keys
    try std.testing.expectEqualStrings("blue", (try idx.entryAt(0)).?.index_key.value.string);
    try std.testing.expectEqualStrings("green", (try idx.entryAt(1)).?.index_key.value.string);
    try std.testing.expectEqualStrings("red", (try idx.entryAt(2)).?.index_key.value.string);

    // All should point to same primary key
    try std.testing.expectEqual(@as(f64, 1), (try idx.entryAt(0)).?.primary_key.value.number);
    try std.testing.expectEqual(@as(f64, 1), (try idx.entryAt(1)).?.primary_key.value.number);
    try std.testing.expectEqual(@as(f64, 1), (try idx.entryAt(2)).?.primary_key.value.number);
}

test "IDBIndex - multiEntry deduplicates array elements" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = true;

    // Create value with duplicate tags
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
        .{ .string = "red" }, // duplicate
        .{ .string = "green" },
        .{ .string = "blue" }, // duplicate
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 3 entries (duplicates skipped)
    try std.testing.expectEqual(@as(usize, 3), (try idx.entryCount(null)));
}

test "IDBIndex - multiEntry retains nested arrays" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "data_idx", &store);
    defer idx.deinit();
    idx.key_path = "data";
    idx.multi_entry = true;

    // Create value with mixed array (includes a valid nested array)
    const nested = [_]key_path_mod.ExtractedValue{
        .{ .number = 99 },
    };
    const data = [_]key_path_mod.ExtractedValue{
        .{ .string = "valid" },
        .{ .array = &nested }, // nested array - one valid array subkey
        .{ .number = 42 },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "data", .value = .{ .array = &data } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // All three valid subkeys are included.
    try std.testing.expectEqual(@as(usize, 3), (try idx.entryCount(null)));
}

test "IDBIndex - non-multiEntry with array creates single entry" {
    const allocator = std.testing.allocator;

    var db = @import("database.zig").IDBDatabase.init(allocator, "testdb", 1);
    defer db.deinit();

    const scope = [_][]const u8{"store1"};
    var txn = @import("transaction.zig").IDBTransaction.init(allocator, &db, &scope, .readwrite);
    defer txn.deinit();

    var store = IDBObjectStore.init(allocator, "store1", &txn);
    defer store.deinit();

    var idx = IDBIndex.init(allocator, "tags_idx", &store);
    defer idx.deinit();
    idx.key_path = "tags";
    idx.multi_entry = false; // NOT multiEntry

    // Create value with tags array
    const tags = [_]key_path_mod.ExtractedValue{
        .{ .string = "red" },
        .{ .string = "blue" },
    };
    const props = [_]key_path_mod.ExtractedValue.Property{
        .{ .key = "tags", .value = .{ .array = &tags } },
    };
    const value = key_path_mod.ExtractedValue{ .object = &props };

    try idx.addEntriesForValue(allocator, value, IDBKey.number(1));

    // Should have 1 entry (the whole array as key)
    try std.testing.expectEqual(@as(usize, 1), (try idx.entryCount(null)));
    try std.testing.expectEqual(@import("key.zig").IDBKeyType.array, (try idx.entryAt(0)).?.index_key.key_type);
}
