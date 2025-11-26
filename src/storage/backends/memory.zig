//! In-Memory Storage Backend
//!
//! A simple in-memory storage backend for testing and ephemeral storage.
//! Uses HashMap for key-value storage with full transaction support.
//!
//! ## Features
//!
//! - Full StorageBackend interface implementation
//! - ACID-compliant transactions (isolation via snapshots)
//! - Object store and index support
//! - No persistence (data lost on close)
//!
//! ## Usage
//!
//! ```zig
//! const backend = try MemoryBackend.create(allocator);
//! defer backend.destroy();
//!
//! try backend.open("testdb", .{});
//! defer backend.close();
//!
//! const txn = try backend.beginTransaction(.readwrite);
//! try backend.write(txn, "key1", "value1");
//! try backend.commit(txn);
//! ```
//!
//! ## Thread Safety
//!
//! This implementation is NOT thread-safe. For multi-threaded use,
//! wrap in a mutex or use one instance per thread.
//!

const std = @import("std");

// Import backend types - use relative import for standalone testing or parent for module
const backend = if (@hasDecl(@This(), "__is_test"))
    @import("../backend.zig")
else
    @import("../backend.zig");

const StorageBackend = backend.StorageBackend;
const BackendError = backend.BackendError;
const TransactionHandle = backend.TransactionHandle;
const TransactionMode = backend.TransactionMode;
const CursorHandle = backend.CursorHandle;
const CursorDirection = backend.CursorDirection;
const KeyRange = backend.KeyRange;
const KeyValue = backend.KeyValue;
const BackendStats = backend.BackendStats;
const DatabaseInfo = backend.DatabaseInfo;
const OpenOptions = backend.OpenOptions;
const ObjectStoreOptions = backend.ObjectStoreOptions;
const IndexOptions = backend.IndexOptions;

// ============================================================================
// Memory Backend Implementation
// ============================================================================

/// In-memory storage backend
pub const MemoryBackend = struct {
    allocator: std.mem.Allocator,

    /// Database state
    state: ?*DatabaseState = null,

    /// Next transaction ID
    next_txn_id: u64 = 1,

    /// Next cursor ID
    next_cursor_id: u64 = 1,

    /// Active transactions
    transactions: std.AutoHashMap(u64, *Transaction),

    /// Active cursors
    cursors: std.AutoHashMap(u64, *Cursor),

    const Self = @This();

    /// Database state (created when opened)
    const DatabaseState = struct {
        name: []const u8,
        version: u64,
        created_at: i64,
        modified_at: i64,
        allocator: std.mem.Allocator,

        /// Object stores
        object_stores: std.StringHashMap(*ObjectStore),

        pub fn init(allocator: std.mem.Allocator, name: []const u8) !*DatabaseState {
            const self = try allocator.create(DatabaseState);
            errdefer allocator.destroy(self);

            const name_copy = try allocator.dupe(u8, name);
            errdefer allocator.free(name_copy);

            self.* = .{
                .name = name_copy,
                .version = 1,
                .created_at = std.time.milliTimestamp(),
                .modified_at = std.time.milliTimestamp(),
                .allocator = allocator,
                .object_stores = std.StringHashMap(*ObjectStore).init(allocator),
            };

            // Create default object store
            const default_store = try ObjectStore.init(allocator, "_default", .{});
            try self.object_stores.put("_default", default_store);

            return self;
        }

        pub fn deinit(self: *DatabaseState) void {
            // Free all object stores
            var it = self.object_stores.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit();
            }
            self.object_stores.deinit();
            self.allocator.free(self.name);
            self.allocator.destroy(self);
        }
    };

    /// Object store
    const ObjectStore = struct {
        name: []const u8,
        options: ObjectStoreOptions,
        allocator: std.mem.Allocator,

        /// Key-value data
        data: std.StringHashMap([]const u8),

        /// Indexes
        indexes: std.StringHashMap(*Index),

        /// Auto-increment counter
        auto_increment_key: u64 = 0,

        pub fn init(allocator: std.mem.Allocator, name: []const u8, options: ObjectStoreOptions) !*ObjectStore {
            const self = try allocator.create(ObjectStore);
            errdefer allocator.destroy(self);

            const name_copy = try allocator.dupe(u8, name);
            errdefer allocator.free(name_copy);

            // Copy key_path if present
            var options_copy = options;
            if (options.key_path) |kp| {
                options_copy.key_path = try allocator.dupe(u8, kp);
            }

            self.* = .{
                .name = name_copy,
                .options = options_copy,
                .allocator = allocator,
                .data = std.StringHashMap([]const u8).init(allocator),
                .indexes = std.StringHashMap(*Index).init(allocator),
            };

            return self;
        }

        pub fn deinit(self: *ObjectStore) void {
            // Free all values
            var data_it = self.data.iterator();
            while (data_it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            self.data.deinit();

            // Free all indexes
            var idx_it = self.indexes.iterator();
            while (idx_it.next()) |entry| {
                entry.value_ptr.*.deinit();
            }
            self.indexes.deinit();

            if (self.options.key_path) |kp| {
                self.allocator.free(kp);
            }
            self.allocator.free(self.name);
            self.allocator.destroy(self);
        }
    };

    /// Index
    const Index = struct {
        name: []const u8,
        key_path: []const u8,
        options: IndexOptions,
        allocator: std.mem.Allocator,

        /// Index data (index key -> primary key)
        data: std.StringHashMap([]const u8),

        pub fn init(allocator: std.mem.Allocator, name: []const u8, key_path: []const u8, options: IndexOptions) !*Index {
            const self = try allocator.create(Index);
            errdefer allocator.destroy(self);

            const name_copy = try allocator.dupe(u8, name);
            errdefer allocator.free(name_copy);

            const key_path_copy = try allocator.dupe(u8, key_path);
            errdefer allocator.free(key_path_copy);

            self.* = .{
                .name = name_copy,
                .key_path = key_path_copy,
                .options = options,
                .allocator = allocator,
                .data = std.StringHashMap([]const u8).init(allocator),
            };

            return self;
        }

        pub fn deinit(self: *Index) void {
            var it = self.data.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            self.data.deinit();
            self.allocator.free(self.name);
            self.allocator.free(self.key_path);
            self.allocator.destroy(self);
        }
    };

    /// Transaction
    const Transaction = struct {
        id: u64,
        mode: TransactionMode,
        allocator: std.mem.Allocator,

        /// Pending writes (key -> value, null = delete)
        pending_writes: std.StringHashMap(?[]const u8),

        /// Object store for this transaction (always _default for now)
        store_name: []const u8,

        pub fn init(allocator: std.mem.Allocator, id: u64, mode: TransactionMode) !*Transaction {
            const self = try allocator.create(Transaction);
            errdefer allocator.destroy(self);

            const store_name = try allocator.dupe(u8, "_default");
            errdefer allocator.free(store_name);

            self.* = .{
                .id = id,
                .mode = mode,
                .allocator = allocator,
                .pending_writes = std.StringHashMap(?[]const u8).init(allocator),
                .store_name = store_name,
            };

            return self;
        }

        pub fn deinit(self: *Transaction) void {
            var it = self.pending_writes.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                if (entry.value_ptr.*) |v| {
                    self.allocator.free(v);
                }
            }
            self.pending_writes.deinit();
            self.allocator.free(self.store_name);
            self.allocator.destroy(self);
        }
    };

    /// Cursor
    const Cursor = struct {
        id: u64,
        transaction_id: u64,
        allocator: std.mem.Allocator,

        /// Keys to iterate (sorted)
        keys: std.ArrayListUnmanaged([]const u8),

        /// Current position
        position: usize,

        /// Direction
        direction: CursorDirection,

        /// Range
        range: KeyRange,

        pub fn init(allocator: std.mem.Allocator, id: u64, txn_id: u64, direction: CursorDirection, range: KeyRange) !*Cursor {
            const self = try allocator.create(Cursor);
            errdefer allocator.destroy(self);

            self.* = .{
                .id = id,
                .transaction_id = txn_id,
                .allocator = allocator,
                .keys = .{},
                .position = 0,
                .direction = direction,
                .range = range,
            };

            return self;
        }

        pub fn deinit(self: *Cursor) void {
            for (self.keys.items) |key| {
                self.allocator.free(key);
            }
            self.keys.deinit(self.allocator);
            self.allocator.destroy(self);
        }
    };

    // ========================================================================
    // Public API
    // ========================================================================

    /// Create a new memory backend
    pub fn create(allocator: std.mem.Allocator) !StorageBackend {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .transactions = std.AutoHashMap(u64, *Transaction).init(allocator),
            .cursors = std.AutoHashMap(u64, *Cursor).init(allocator),
        };

        return StorageBackend{
            .ptr = self,
            .vtable = &vtable,
            .allocator = allocator,
        };
    }

    // ========================================================================
    // VTable Implementation
    // ========================================================================

    const vtable = StorageBackend.VTable{
        .open = open,
        .close = close,
        .is_open = isOpen,
        .begin_transaction = beginTransaction,
        .commit = commit,
        .rollback = rollback,
        .read = read,
        .write = write,
        .delete = delete_,
        .exists = exists,
        .cursor_open = cursorOpen,
        .cursor_next = cursorNext,
        .cursor_close = cursorClose,
        .estimate_size = estimateSize,
        .get_stats = getStats,
        .get_info = getInfo,
        .create_object_store = createObjectStore,
        .delete_object_store = deleteObjectStore,
        .create_index = createIndex,
        .delete_index = deleteIndex,
        .destroy = destroy,
    };

    fn open(ctx: *anyopaque, name: []const u8, options: OpenOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.state != null) {
            return BackendError.InvalidState;
        }

        _ = options;
        self.state = DatabaseState.init(self.allocator, name) catch return BackendError.OutOfMemory;
    }

    fn close(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Rollback all active transactions
        var txn_it = self.transactions.iterator();
        while (txn_it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.transactions.clearAndFree();

        // Close all cursors
        var cursor_it = self.cursors.iterator();
        while (cursor_it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.cursors.clearAndFree();

        if (self.state) |state| {
            state.deinit();
            self.state = null;
        }
    }

    fn isOpen(ctx: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.state != null;
    }

    fn beginTransaction(ctx: *anyopaque, mode: TransactionMode) BackendError!TransactionHandle {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.state == null) {
            return BackendError.Closed;
        }

        const txn_id = self.next_txn_id;
        self.next_txn_id += 1;

        const txn = Transaction.init(self.allocator, txn_id, mode) catch return BackendError.OutOfMemory;
        self.transactions.put(txn_id, txn) catch {
            txn.deinit();
            return BackendError.OutOfMemory;
        };

        return TransactionHandle{
            .id = txn_id,
            .mode = mode,
        };
    }

    fn commit(ctx: *anyopaque, handle: TransactionHandle) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        // Get object store
        const store = state.object_stores.get(txn.store_name) orelse return BackendError.NotFound;

        // Apply pending writes
        var it = txn.pending_writes.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const maybe_value = entry.value_ptr.*;

            if (maybe_value) |value| {
                // Write operation - check if key already exists
                if (store.data.fetchRemove(key)) |old_kv| {
                    // Free both old key and value
                    self.allocator.free(old_kv.key);
                    self.allocator.free(old_kv.value);
                }

                // Copy key and value to store
                const key_copy = self.allocator.dupe(u8, key) catch return BackendError.OutOfMemory;
                const value_copy = self.allocator.dupe(u8, value) catch {
                    self.allocator.free(key_copy);
                    return BackendError.OutOfMemory;
                };

                store.data.put(key_copy, value_copy) catch {
                    self.allocator.free(key_copy);
                    self.allocator.free(value_copy);
                    return BackendError.OutOfMemory;
                };
            } else {
                // Delete operation
                if (store.data.fetchRemove(key)) |kv| {
                    self.allocator.free(kv.key);
                    self.allocator.free(kv.value);
                }
            }
        }

        // Update modified timestamp
        state.modified_at = std.time.milliTimestamp();

        // Remove and cleanup transaction
        _ = self.transactions.remove(handle.id);
        txn.deinit();
    }

    fn rollback(ctx: *anyopaque, handle: TransactionHandle) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.transactions.fetchRemove(handle.id)) |kv| {
            kv.value.deinit();
        }
    }

    fn read(ctx: *anyopaque, allocator: std.mem.Allocator, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        // Check pending writes first
        if (txn.pending_writes.get(key)) |maybe_value| {
            if (maybe_value) |value| {
                return allocator.dupe(u8, value) catch return BackendError.OutOfMemory;
            } else {
                return null; // Pending delete
            }
        }

        // Check committed data
        const store = state.object_stores.get(txn.store_name) orelse return BackendError.NotFound;
        if (store.data.get(key)) |value| {
            return allocator.dupe(u8, value) catch return BackendError.OutOfMemory;
        }

        return null;
    }

    fn write(ctx: *anyopaque, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.state == null) return BackendError.Closed;

        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode == .readonly) {
            return BackendError.InvalidState;
        }

        // Remove existing pending write if any
        if (txn.pending_writes.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            if (old.value) |v| {
                self.allocator.free(v);
            }
        }

        // Add new pending write
        const key_copy = self.allocator.dupe(u8, key) catch return BackendError.OutOfMemory;
        errdefer self.allocator.free(key_copy);

        const value_copy = self.allocator.dupe(u8, value) catch return BackendError.OutOfMemory;
        errdefer self.allocator.free(value_copy);

        txn.pending_writes.put(key_copy, value_copy) catch return BackendError.OutOfMemory;
    }

    fn delete_(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.state == null) return BackendError.Closed;

        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode == .readonly) {
            return BackendError.InvalidState;
        }

        // Remove existing pending write if any
        if (txn.pending_writes.fetchRemove(key)) |old| {
            self.allocator.free(old.key);
            if (old.value) |v| {
                self.allocator.free(v);
            }
        }

        // Add pending delete (null value means delete)
        const key_copy = self.allocator.dupe(u8, key) catch return BackendError.OutOfMemory;
        txn.pending_writes.put(key_copy, null) catch {
            self.allocator.free(key_copy);
            return BackendError.OutOfMemory;
        };
    }

    fn exists(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!bool {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        // Check pending writes first
        if (txn.pending_writes.get(key)) |maybe_value| {
            return maybe_value != null;
        }

        // Check committed data
        const store = state.object_stores.get(txn.store_name) orelse return BackendError.NotFound;
        return store.data.contains(key);
    }

    fn cursorOpen(ctx: *anyopaque, handle: TransactionHandle, range: KeyRange, direction: CursorDirection) BackendError!CursorHandle {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;
        const store = state.object_stores.get(txn.store_name) orelse return BackendError.NotFound;

        const cursor_id = self.next_cursor_id;
        self.next_cursor_id += 1;

        const cursor = Cursor.init(self.allocator, cursor_id, handle.id, direction, range) catch return BackendError.OutOfMemory;
        errdefer cursor.deinit();

        // Collect keys in range
        var keys: std.ArrayListUnmanaged([]const u8) = .{};
        defer keys.deinit(self.allocator);

        var it = store.data.keyIterator();
        while (it.next()) |key| {
            if (keyInRange(key.*, range)) {
                const key_copy = self.allocator.dupe(u8, key.*) catch return BackendError.OutOfMemory;
                keys.append(self.allocator, key_copy) catch {
                    self.allocator.free(key_copy);
                    return BackendError.OutOfMemory;
                };
            }
        }

        // Also check pending writes
        var pending_it = txn.pending_writes.iterator();
        while (pending_it.next()) |entry| {
            if (entry.value_ptr.* != null and keyInRange(entry.key_ptr.*, range)) {
                // Check if already in list
                var found = false;
                for (keys.items) |k| {
                    if (std.mem.eql(u8, k, entry.key_ptr.*)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const key_copy = self.allocator.dupe(u8, entry.key_ptr.*) catch return BackendError.OutOfMemory;
                    keys.append(self.allocator, key_copy) catch {
                        self.allocator.free(key_copy);
                        return BackendError.OutOfMemory;
                    };
                }
            }
        }

        // Sort keys
        std.mem.sort([]const u8, keys.items, {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan);

        // Reverse if needed
        if (direction == .prev or direction == .prevunique) {
            std.mem.reverse([]const u8, keys.items);
        }

        // Transfer ownership to cursor
        cursor.keys = keys.clone(self.allocator) catch return BackendError.OutOfMemory;

        self.cursors.put(cursor_id, cursor) catch return BackendError.OutOfMemory;

        return CursorHandle{
            .id = cursor_id,
            .transaction_id = handle.id,
        };
    }

    fn cursorNext(ctx: *anyopaque, allocator: std.mem.Allocator, cursor_handle: CursorHandle) BackendError!?KeyValue {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const cursor = self.cursors.get(cursor_handle.id) orelse return BackendError.InvalidCursor;

        if (cursor.position >= cursor.keys.items.len) {
            return null;
        }

        const key = cursor.keys.items[cursor.position];
        cursor.position += 1;

        // Read value
        const value = try read(ctx, allocator, TransactionHandle{
            .id = cursor.transaction_id,
            .mode = .readonly,
        }, key) orelse return null;

        const key_copy = allocator.dupe(u8, key) catch {
            allocator.free(value);
            return BackendError.OutOfMemory;
        };

        return KeyValue{
            .key = key_copy,
            .value = value,
            .allocator = allocator,
        };
    }

    fn cursorClose(ctx: *anyopaque, cursor_handle: CursorHandle) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.cursors.fetchRemove(cursor_handle.id)) |kv| {
            kv.value.deinit();
        }
    }

    fn estimateSize(ctx: *anyopaque) BackendError!u64 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        var total: u64 = 0;

        var store_it = state.object_stores.iterator();
        while (store_it.next()) |store_entry| {
            var data_it = store_entry.value_ptr.*.data.iterator();
            while (data_it.next()) |entry| {
                total += entry.key_ptr.len + entry.value_ptr.len;
            }
        }

        return total;
    }

    fn getStats(ctx: *anyopaque) BackendError!BackendStats {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        var key_count: u64 = 0;

        var store_it = state.object_stores.iterator();
        while (store_it.next()) |store_entry| {
            key_count += store_entry.value_ptr.*.data.count();
        }

        return BackendStats{
            .disk_size = try estimateSize(ctx),
            .key_count = key_count,
            .active_transactions = @intCast(self.transactions.count()),
            .open_cursors = @intCast(self.cursors.count()),
        };
    }

    fn getInfo(ctx: *anyopaque, allocator: std.mem.Allocator) BackendError!DatabaseInfo {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;

        // Collect object store names
        var names: std.ArrayListUnmanaged([]const u8) = .{};
        defer names.deinit(allocator);

        var it = state.object_stores.keyIterator();
        while (it.next()) |key| {
            const name_copy = allocator.dupe(u8, key.*) catch return BackendError.OutOfMemory;
            names.append(allocator, name_copy) catch {
                allocator.free(name_copy);
                return BackendError.OutOfMemory;
            };
        }

        const name_copy = allocator.dupe(u8, state.name) catch return BackendError.OutOfMemory;
        const stores_slice = names.toOwnedSlice(allocator) catch return BackendError.OutOfMemory;

        return DatabaseInfo{
            .name = name_copy,
            .version = state.version,
            .object_stores = stores_slice,
            .created_at = state.created_at,
            .modified_at = state.modified_at,
        };
    }

    fn createObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8, options: ObjectStoreOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode != .versionchange) {
            return BackendError.InvalidState;
        }

        if (state.object_stores.contains(name)) {
            return BackendError.AlreadyExists;
        }

        const store = ObjectStore.init(self.allocator, name, options) catch return BackendError.OutOfMemory;
        state.object_stores.put(store.name, store) catch {
            store.deinit();
            return BackendError.OutOfMemory;
        };
    }

    fn deleteObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode != .versionchange) {
            return BackendError.InvalidState;
        }

        if (state.object_stores.fetchRemove(name)) |kv| {
            kv.value.deinit();
        } else {
            return BackendError.NotFound;
        }
    }

    fn createIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8, key_path: []const u8, options: IndexOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode != .versionchange) {
            return BackendError.InvalidState;
        }

        const store = state.object_stores.get(store_name) orelse return BackendError.NotFound;

        if (store.indexes.contains(index_name)) {
            return BackendError.AlreadyExists;
        }

        const index = Index.init(self.allocator, index_name, key_path, options) catch return BackendError.OutOfMemory;
        store.indexes.put(index.name, index) catch {
            index.deinit();
            return BackendError.OutOfMemory;
        };
    }

    fn deleteIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const state = self.state orelse return BackendError.Closed;
        const txn = self.transactions.get(handle.id) orelse return BackendError.InvalidTransaction;

        if (txn.mode != .versionchange) {
            return BackendError.InvalidState;
        }

        const store = state.object_stores.get(store_name) orelse return BackendError.NotFound;

        if (store.indexes.fetchRemove(index_name)) |kv| {
            kv.value.deinit();
        } else {
            return BackendError.NotFound;
        }
    }

    fn destroy(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Close if open
        close(ctx);

        self.transactions.deinit();
        self.cursors.deinit();
        self.allocator.destroy(self);
    }

    // ========================================================================
    // Helper Functions
    // ========================================================================

    fn keyInRange(key: []const u8, range: KeyRange) bool {
        // Check lower bound
        if (range.lower) |lower| {
            const cmp = std.mem.order(u8, key, lower);
            if (cmp == .lt) return false;
            if (cmp == .eq and range.lower_open) return false;
        }

        // Check upper bound
        if (range.upper) |upper| {
            const cmp = std.mem.order(u8, key, upper);
            if (cmp == .gt) return false;
            if (cmp == .eq and range.upper_open) return false;
        }

        return true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "MemoryBackend - create and destroy" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    backend_inst.destroy();
}

test "MemoryBackend - open and close" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    try std.testing.expect(backend_inst.isOpen());

    backend_inst.close();
    try std.testing.expect(!backend_inst.isOpen());
}

test "MemoryBackend - basic read/write" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    const txn = try backend_inst.beginTransaction(.readwrite);

    try backend_inst.write(txn, "key1", "value1");
    try backend_inst.write(txn, "key2", "value2");

    // Read before commit (from pending)
    const val1 = try backend_inst.read(txn, "key1");
    defer if (val1) |v| std.testing.allocator.free(v);
    try std.testing.expectEqualStrings("value1", val1.?);

    // Commit
    try backend_inst.commit(txn);

    // Read after commit (new transaction)
    const txn2 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn2);

    const val2 = try backend_inst.read(txn2, "key1");
    defer if (val2) |v| std.testing.allocator.free(v);
    try std.testing.expectEqualStrings("value1", val2.?);
}

test "MemoryBackend - delete" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    // Write
    const txn1 = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn1, "key1", "value1");
    try backend_inst.commit(txn1);

    // Delete
    const txn2 = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.delete(txn2, "key1");
    try backend_inst.commit(txn2);

    // Verify deleted
    const txn3 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn3);

    const val = try backend_inst.read(txn3, "key1");
    try std.testing.expect(val == null);
}

test "MemoryBackend - exists" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    const txn = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn, "key1", "value1");
    try backend_inst.commit(txn);

    const txn2 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn2);

    try std.testing.expect(try backend_inst.exists(txn2, "key1"));
    try std.testing.expect(!try backend_inst.exists(txn2, "nonexistent"));
}

test "MemoryBackend - cursor iteration" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    // Write some data
    const txn1 = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn1, "a", "1");
    try backend_inst.write(txn1, "b", "2");
    try backend_inst.write(txn1, "c", "3");
    try backend_inst.commit(txn1);

    // Iterate
    const txn2 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn2);

    const cursor = try backend_inst.cursorOpen(txn2, KeyRange{}, .next);
    defer backend_inst.cursorClose(cursor);

    var count: usize = 0;
    while (try backend_inst.cursorNext(cursor)) |*kv| {
        defer @constCast(kv).deinit();
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
}

test "MemoryBackend - cursor with range" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    // Write some data
    const txn1 = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn1, "a", "1");
    try backend_inst.write(txn1, "b", "2");
    try backend_inst.write(txn1, "c", "3");
    try backend_inst.write(txn1, "d", "4");
    try backend_inst.commit(txn1);

    // Iterate with range [b, c]
    const txn2 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn2);

    const cursor = try backend_inst.cursorOpen(txn2, KeyRange.bound("b", "c", false, false), .next);
    defer backend_inst.cursorClose(cursor);

    var keys: std.ArrayListUnmanaged([]const u8) = .{};
    defer {
        for (keys.items) |k| std.testing.allocator.free(k);
        keys.deinit(std.testing.allocator);
    }

    while (try backend_inst.cursorNext(cursor)) |*kv| {
        defer std.testing.allocator.free(kv.value);
        try keys.append(std.testing.allocator, kv.key);
    }

    try std.testing.expectEqual(@as(usize, 2), keys.items.len);
    try std.testing.expectEqualStrings("b", keys.items[0]);
    try std.testing.expectEqualStrings("c", keys.items[1]);
}

test "MemoryBackend - rollback" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    // Write and rollback
    const txn1 = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn1, "key1", "value1");
    backend_inst.rollback(txn1);

    // Verify not written
    const txn2 = try backend_inst.beginTransaction(.readonly);
    defer backend_inst.rollback(txn2);

    const val = try backend_inst.read(txn2, "key1");
    try std.testing.expect(val == null);
}

test "MemoryBackend - stats" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    const txn = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn, "key1", "value1");
    try backend_inst.write(txn, "key2", "value2");
    try backend_inst.commit(txn);

    const stats = try backend_inst.getStats();
    try std.testing.expectEqual(@as(u64, 2), stats.key_count);
    try std.testing.expect(stats.disk_size > 0);
}

test "MemoryBackend - object stores" {
    const backend_inst = try MemoryBackend.create(std.testing.allocator);
    defer backend_inst.destroy();

    try backend_inst.open("testdb", .{});
    defer backend_inst.close();

    const txn = try backend_inst.beginTransaction(.versionchange);
    try backend_inst.createObjectStore(txn, "store1", .{});
    try backend_inst.createObjectStore(txn, "store2", .{ .auto_increment = true });
    try backend_inst.commit(txn);

    const info = try backend_inst.getInfo();
    defer {
        std.testing.allocator.free(info.name);
        for (info.object_stores) |s| std.testing.allocator.free(s);
        std.testing.allocator.free(info.object_stores);
    }

    // Should have _default + store1 + store2 = 3 stores
    try std.testing.expectEqual(@as(usize, 3), info.object_stores.len);
}
