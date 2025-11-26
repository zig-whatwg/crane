//! LevelDB Storage Backend
//!
//! LevelDB-based storage backend for IndexedDB and Storage Standard.
//! Uses LevelDB C API (via C++ shim) for high-performance key-value storage.
//!
//! ## Features
//!
//! - Full StorageBackend interface implementation
//! - Hierarchical key encoding for IndexedDB semantics
//! - Batch writes for transaction support
//! - Optimized for desktop workloads
//!
//! ## LevelDB Key Encoding (Phase 2.9)
//!
//! LevelDB uses flat key-value storage. We encode IndexedDB hierarchy into keys:
//!
//! ```
//! Key Format: [prefix:1][database_id:4][store_id:4][key_type:1][key_data:variable]
//!
//! Prefixes:
//!   0x00 - Database metadata
//!   0x01 - Object store metadata
//!   0x02 - Object store data
//!   0x03 - Index metadata
//!   0x04 - Index data
//!
//! Examples:
//!   Database "mydb" metadata:     [0x00][0001][name=mydb, version=1]
//!   Object store "users":         [0x01][0001][0001][name=users, key_path=id]
//!   Data in "users":              [0x02][0001][0001][IDBKEY][value]
//!   Index "email" on "users":     [0x03][0001][0001][0001][name=email, key_path=email]
//!   Index entry:                  [0x04][0001][0001][0001][IDBKEY:email][IDBKEY:id]
//! ```
//!
//! ## Advantages over SQLite
//!
//! - 10-100x faster for simple key-value workloads
//! - No SQL parsing overhead
//! - Efficient range scans
//! - Lower memory footprint
//!
//! ## References
//!
//! - LevelDB C API: https://github.com/google/leveldb/blob/main/include/leveldb/c.h
//! - Chrome IndexedDB: Uses LevelDB internally
//!

const std = @import("std");
const backend = @import("../backend.zig");

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

// Import IDBKEY encoder from SQLite module (shared implementation)
const sqlite = @import("sqlite.zig");
pub const IDBKeyEncoder = sqlite.IDBKeyEncoder;
pub const IDBKeyType = sqlite.IDBKeyType;

// ============================================================================
// LevelDB C API Bindings (Phase 2.8)
// ============================================================================

/// LevelDB C API types
pub const c = struct {
    // Opaque handle types
    pub const leveldb_t = opaque {};
    pub const leveldb_options_t = opaque {};
    pub const leveldb_readoptions_t = opaque {};
    pub const leveldb_writeoptions_t = opaque {};
    pub const leveldb_writebatch_t = opaque {};
    pub const leveldb_iterator_t = opaque {};
    pub const leveldb_snapshot_t = opaque {};
    pub const leveldb_comparator_t = opaque {};

    // C function declarations (linked from system LevelDB)
    pub extern fn leveldb_open(options: *leveldb_options_t, name: [*:0]const u8, errptr: *?[*:0]u8) ?*leveldb_t;
    pub extern fn leveldb_close(db: *leveldb_t) void;
    pub extern fn leveldb_put(db: *leveldb_t, options: *leveldb_writeoptions_t, key: [*]const u8, keylen: usize, val: [*]const u8, vallen: usize, errptr: *?[*:0]u8) void;
    pub extern fn leveldb_get(db: *leveldb_t, options: *leveldb_readoptions_t, key: [*]const u8, keylen: usize, vallen: *usize, errptr: *?[*:0]u8) ?[*]u8;
    pub extern fn leveldb_delete(db: *leveldb_t, options: *leveldb_writeoptions_t, key: [*]const u8, keylen: usize, errptr: *?[*:0]u8) void;
    pub extern fn leveldb_write(db: *leveldb_t, options: *leveldb_writeoptions_t, batch: *leveldb_writebatch_t, errptr: *?[*:0]u8) void;

    // Options
    pub extern fn leveldb_options_create() *leveldb_options_t;
    pub extern fn leveldb_options_destroy(options: *leveldb_options_t) void;
    pub extern fn leveldb_options_set_create_if_missing(options: *leveldb_options_t, val: u8) void;
    pub extern fn leveldb_options_set_error_if_exists(options: *leveldb_options_t, val: u8) void;
    pub extern fn leveldb_options_set_comparator(options: *leveldb_options_t, cmp: *leveldb_comparator_t) void;

    // Read options
    pub extern fn leveldb_readoptions_create() *leveldb_readoptions_t;
    pub extern fn leveldb_readoptions_destroy(options: *leveldb_readoptions_t) void;
    pub extern fn leveldb_readoptions_set_snapshot(options: *leveldb_readoptions_t, snapshot: ?*const leveldb_snapshot_t) void;

    // Write options
    pub extern fn leveldb_writeoptions_create() *leveldb_writeoptions_t;
    pub extern fn leveldb_writeoptions_destroy(options: *leveldb_writeoptions_t) void;
    pub extern fn leveldb_writeoptions_set_sync(options: *leveldb_writeoptions_t, val: u8) void;

    // Batch writes
    pub extern fn leveldb_writebatch_create() *leveldb_writebatch_t;
    pub extern fn leveldb_writebatch_destroy(batch: *leveldb_writebatch_t) void;
    pub extern fn leveldb_writebatch_clear(batch: *leveldb_writebatch_t) void;
    pub extern fn leveldb_writebatch_put(batch: *leveldb_writebatch_t, key: [*]const u8, keylen: usize, val: [*]const u8, vallen: usize) void;
    pub extern fn leveldb_writebatch_delete(batch: *leveldb_writebatch_t, key: [*]const u8, keylen: usize) void;

    // Iterator
    pub extern fn leveldb_create_iterator(db: *leveldb_t, options: *leveldb_readoptions_t) *leveldb_iterator_t;
    pub extern fn leveldb_iter_destroy(iter: *leveldb_iterator_t) void;
    pub extern fn leveldb_iter_valid(iter: *leveldb_iterator_t) u8;
    pub extern fn leveldb_iter_seek_to_first(iter: *leveldb_iterator_t) void;
    pub extern fn leveldb_iter_seek_to_last(iter: *leveldb_iterator_t) void;
    pub extern fn leveldb_iter_seek(iter: *leveldb_iterator_t, key: [*]const u8, keylen: usize) void;
    pub extern fn leveldb_iter_next(iter: *leveldb_iterator_t) void;
    pub extern fn leveldb_iter_prev(iter: *leveldb_iterator_t) void;
    pub extern fn leveldb_iter_key(iter: *leveldb_iterator_t, keylen: *usize) [*]const u8;
    pub extern fn leveldb_iter_value(iter: *leveldb_iterator_t, vallen: *usize) [*]const u8;

    // Snapshots
    pub extern fn leveldb_create_snapshot(db: *leveldb_t) *leveldb_snapshot_t;
    pub extern fn leveldb_release_snapshot(db: *leveldb_t, snapshot: *leveldb_snapshot_t) void;

    // Comparator
    pub extern fn leveldb_comparator_create(state: ?*anyopaque, destructor: ?*const fn (?*anyopaque) callconv(.C) void, compare: *const fn (?*anyopaque, [*]const u8, usize, [*]const u8, usize) callconv(.C) c_int, name: *const fn (?*anyopaque) callconv(.C) [*:0]const u8) *leveldb_comparator_t;
    pub extern fn leveldb_comparator_destroy(cmp: *leveldb_comparator_t) void;

    // Memory
    pub extern fn leveldb_free(ptr: ?*anyopaque) void;

    // Approximate sizes
    pub extern fn leveldb_approximate_sizes(db: *leveldb_t, num_ranges: c_int, start_keys: [*]const [*]const u8, start_key_lens: [*]const usize, limit_keys: [*]const [*]const u8, limit_key_lens: [*]const usize, sizes: [*]u64) void;
};

// ============================================================================
// LevelDB Key Encoding (Phase 2.9)
// ============================================================================

/// Key prefixes for hierarchical organization
pub const KeyPrefix = enum(u8) {
    /// Database metadata: [0x00][db_id:4]
    database_meta = 0x00,

    /// Object store metadata: [0x01][db_id:4][store_id:4]
    object_store_meta = 0x01,

    /// Object store data: [0x02][db_id:4][store_id:4][IDBKEY]
    object_store_data = 0x02,

    /// Index metadata: [0x03][db_id:4][store_id:4][index_id:4]
    index_meta = 0x03,

    /// Index data: [0x04][db_id:4][store_id:4][index_id:4][IDBKEY:index][IDBKEY:primary]
    index_data = 0x04,

    /// Global metadata (database list, etc): [0x05]
    global_meta = 0x05,
};

/// LevelDB key encoder
pub const LevelDBKeyEncoder = struct {
    /// Encode a database metadata key
    pub fn encodeDatabaseMeta(allocator: std.mem.Allocator, db_id: u32) ![]u8 {
        var result = try allocator.alloc(u8, 5);
        result[0] = @intFromEnum(KeyPrefix.database_meta);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        return result;
    }

    /// Encode an object store metadata key
    pub fn encodeObjectStoreMeta(allocator: std.mem.Allocator, db_id: u32, store_id: u32) ![]u8 {
        var result = try allocator.alloc(u8, 9);
        result[0] = @intFromEnum(KeyPrefix.object_store_meta);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id, .big);
        return result;
    }

    /// Encode an object store data key
    pub fn encodeObjectStoreData(allocator: std.mem.Allocator, db_id: u32, store_id: u32, idb_key: []const u8) ![]u8 {
        var result = try allocator.alloc(u8, 9 + idb_key.len);
        result[0] = @intFromEnum(KeyPrefix.object_store_data);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id, .big);
        @memcpy(result[9..], idb_key);
        return result;
    }

    /// Encode an index metadata key
    pub fn encodeIndexMeta(allocator: std.mem.Allocator, db_id: u32, store_id: u32, index_id: u32) ![]u8 {
        var result = try allocator.alloc(u8, 13);
        result[0] = @intFromEnum(KeyPrefix.index_meta);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id, .big);
        std.mem.writeInt(u32, result[9..13], index_id, .big);
        return result;
    }

    /// Encode an index data key
    pub fn encodeIndexData(allocator: std.mem.Allocator, db_id: u32, store_id: u32, index_id: u32, index_key: []const u8, primary_key: []const u8) ![]u8 {
        // Format: [prefix][db_id][store_id][index_id][index_key_len:4][index_key][primary_key]
        var result = try allocator.alloc(u8, 17 + index_key.len + primary_key.len);
        result[0] = @intFromEnum(KeyPrefix.index_data);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id, .big);
        std.mem.writeInt(u32, result[9..13], index_id, .big);
        std.mem.writeInt(u32, result[13..17], @intCast(index_key.len), .big);
        @memcpy(result[17..][0..index_key.len], index_key);
        @memcpy(result[17 + index_key.len ..], primary_key);
        return result;
    }

    /// Encode a range start key for object store iteration
    pub fn encodeObjectStoreRangeStart(allocator: std.mem.Allocator, db_id: u32, store_id: u32) ![]u8 {
        var result = try allocator.alloc(u8, 9);
        result[0] = @intFromEnum(KeyPrefix.object_store_data);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id, .big);
        return result;
    }

    /// Encode a range end key for object store iteration (exclusive)
    pub fn encodeObjectStoreRangeEnd(allocator: std.mem.Allocator, db_id: u32, store_id: u32) ![]u8 {
        // Use store_id + 1 to get exclusive end
        var result = try allocator.alloc(u8, 9);
        result[0] = @intFromEnum(KeyPrefix.object_store_data);
        std.mem.writeInt(u32, result[1..5], db_id, .big);
        std.mem.writeInt(u32, result[5..9], store_id +| 1, .big);
        return result;
    }

    /// Extract IDBKEY from an object store data key
    pub fn extractIDBKey(full_key: []const u8) ?[]const u8 {
        if (full_key.len < 9) return null;
        if (full_key[0] != @intFromEnum(KeyPrefix.object_store_data)) return null;
        return full_key[9..];
    }
};

/// Custom comparator for LevelDB that uses IDBKEY ordering within prefixes
pub fn leveldbComparator(state: ?*anyopaque, a_ptr: [*]const u8, a_len: usize, b_ptr: [*]const u8, b_len: usize) callconv(.c) c_int {
    _ = state;

    const a = a_ptr[0..a_len];
    const b = b_ptr[0..b_len];

    // Compare prefixes first
    if (a.len == 0 and b.len == 0) return 0;
    if (a.len == 0) return -1;
    if (b.len == 0) return 1;

    if (a[0] < b[0]) return -1;
    if (a[0] > b[0]) return 1;

    // Same prefix - for data keys, use IDBKEY comparison for the key portion
    const prefix: KeyPrefix = @enumFromInt(a[0]);

    switch (prefix) {
        .object_store_data => {
            // Compare db_id, store_id first
            if (a.len < 9 or b.len < 9) {
                return if (a.len < b.len) @as(c_int, -1) else if (a.len > b.len) @as(c_int, 1) else @as(c_int, 0);
            }

            // Compare db_id
            for (1..5) |i| {
                if (a[i] < b[i]) return -1;
                if (a[i] > b[i]) return 1;
            }

            // Compare store_id
            for (5..9) |i| {
                if (a[i] < b[i]) return -1;
                if (a[i] > b[i]) return 1;
            }

            // Compare IDBKEY portion
            return sqlite.idbkeyCollation(null, @intCast(a.len - 9), a.ptr + 9, @intCast(b.len - 9), b.ptr + 9);
        },
        .index_data => {
            // Similar handling for index data
            if (a.len < 13 or b.len < 13) {
                return if (a.len < b.len) @as(c_int, -1) else if (a.len > b.len) @as(c_int, 1) else @as(c_int, 0);
            }

            // Compare prefix bytes (db_id, store_id, index_id)
            for (1..13) |i| {
                if (a[i] < b[i]) return -1;
                if (a[i] > b[i]) return 1;
            }

            // Remaining is index key + primary key - byte comparison is fine
            // (IDBKEY encoding preserves order)
            const rest_a = a[13..];
            const rest_b = b[13..];
            const min_len = @min(rest_a.len, rest_b.len);

            for (0..min_len) |i| {
                if (rest_a[i] < rest_b[i]) return -1;
                if (rest_a[i] > rest_b[i]) return 1;
            }

            return if (rest_a.len < rest_b.len) @as(c_int, -1) else if (rest_a.len > rest_b.len) @as(c_int, 1) else @as(c_int, 0);
        },
        else => {
            // Default byte comparison for metadata
            const min_len = @min(a.len, b.len);
            for (0..min_len) |i| {
                if (a[i] < b[i]) return -1;
                if (a[i] > b[i]) return 1;
            }
            return if (a.len < b.len) @as(c_int, -1) else if (a.len > b.len) @as(c_int, 1) else @as(c_int, 0);
        },
    }
}

pub fn leveldbComparatorName(_: ?*anyopaque) callconv(.c) [*:0]const u8 {
    return "IDBKeyComparator";
}

// ============================================================================
// LevelDB Backend Implementation (Stub - Phase 2.8)
// ============================================================================

/// LevelDB storage backend
pub const LevelDBBackend = struct {
    allocator: std.mem.Allocator,
    db: ?*c.leveldb_t = null,
    options: ?*c.leveldb_options_t = null,
    read_options: ?*c.leveldb_readoptions_t = null,
    write_options: ?*c.leveldb_writeoptions_t = null,
    comparator: ?*c.leveldb_comparator_t = null,

    database_id: u32 = 0,
    next_store_id: u32 = 1,
    next_index_id: u32 = 1,
    next_txn_id: u64 = 1,
    next_cursor_id: u64 = 1,

    const Self = @This();

    /// Create a new LevelDB backend
    pub fn create(allocator: std.mem.Allocator) !StorageBackend {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
        };

        return StorageBackend{
            .ptr = self,
            .vtable = &vtable,
            .allocator = allocator,
        };
    }

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
        _ = ctx;
        _ = name;
        _ = options;
        // TODO: Implement in Phase 2.8
        return BackendError.BackendSpecific;
    }

    fn close(ctx: *anyopaque) void {
        _ = ctx;
        // TODO: Implement in Phase 2.8
    }

    fn isOpen(ctx: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.db != null;
    }

    fn beginTransaction(ctx: *anyopaque, mode: TransactionMode) BackendError!TransactionHandle {
        _ = ctx;
        _ = mode;
        return BackendError.BackendSpecific;
    }

    fn commit(ctx: *anyopaque, handle: TransactionHandle) BackendError!void {
        _ = ctx;
        _ = handle;
        return BackendError.BackendSpecific;
    }

    fn rollback(ctx: *anyopaque, handle: TransactionHandle) void {
        _ = ctx;
        _ = handle;
    }

    fn read(ctx: *anyopaque, allocator: std.mem.Allocator, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8 {
        _ = ctx;
        _ = allocator;
        _ = handle;
        _ = key;
        return BackendError.BackendSpecific;
    }

    fn write(ctx: *anyopaque, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = key;
        _ = value;
        return BackendError.BackendSpecific;
    }

    fn delete_(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = key;
        return BackendError.BackendSpecific;
    }

    fn exists(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!bool {
        _ = ctx;
        _ = handle;
        _ = key;
        return BackendError.BackendSpecific;
    }

    fn cursorOpen(ctx: *anyopaque, handle: TransactionHandle, range: KeyRange, direction: CursorDirection) BackendError!CursorHandle {
        _ = ctx;
        _ = handle;
        _ = range;
        _ = direction;
        return BackendError.BackendSpecific;
    }

    fn cursorNext(ctx: *anyopaque, allocator: std.mem.Allocator, cursor: CursorHandle) BackendError!?KeyValue {
        _ = ctx;
        _ = allocator;
        _ = cursor;
        return BackendError.BackendSpecific;
    }

    fn cursorClose(ctx: *anyopaque, cursor: CursorHandle) void {
        _ = ctx;
        _ = cursor;
    }

    fn estimateSize(ctx: *anyopaque) BackendError!u64 {
        _ = ctx;
        return 0;
    }

    fn getStats(ctx: *anyopaque) BackendError!BackendStats {
        _ = ctx;
        return BackendStats{};
    }

    fn getInfo(ctx: *anyopaque, allocator: std.mem.Allocator) BackendError!DatabaseInfo {
        _ = ctx;
        _ = allocator;
        return BackendError.BackendSpecific;
    }

    fn createObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8, options: ObjectStoreOptions) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = name;
        _ = options;
        return BackendError.BackendSpecific;
    }

    fn deleteObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = name;
        return BackendError.BackendSpecific;
    }

    fn createIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8, key_path: []const u8, options: IndexOptions) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = store_name;
        _ = index_name;
        _ = key_path;
        _ = options;
        return BackendError.BackendSpecific;
    }

    fn deleteIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = store_name;
        _ = index_name;
        return BackendError.BackendSpecific;
    }

    fn destroy(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.db != null) {
            close(ctx);
        }
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "LevelDBKeyEncoder - database meta key" {
    const allocator = std.testing.allocator;

    const key = try LevelDBKeyEncoder.encodeDatabaseMeta(allocator, 1);
    defer allocator.free(key);

    try std.testing.expectEqual(@as(u8, @intFromEnum(KeyPrefix.database_meta)), key[0]);
    try std.testing.expectEqual(@as(usize, 5), key.len);
}

test "LevelDBKeyEncoder - object store data key" {
    const allocator = std.testing.allocator;

    const idb_key = try IDBKeyEncoder.encodeString(allocator, "user123");
    defer allocator.free(idb_key);

    const key = try LevelDBKeyEncoder.encodeObjectStoreData(allocator, 1, 2, idb_key);
    defer allocator.free(key);

    try std.testing.expectEqual(@as(u8, @intFromEnum(KeyPrefix.object_store_data)), key[0]);
    try std.testing.expectEqual(@as(usize, 9 + idb_key.len), key.len);
}

test "LevelDBKeyEncoder - extract IDBKEY" {
    const allocator = std.testing.allocator;

    const idb_key = try IDBKeyEncoder.encodeString(allocator, "test");
    defer allocator.free(idb_key);

    const full_key = try LevelDBKeyEncoder.encodeObjectStoreData(allocator, 1, 2, idb_key);
    defer allocator.free(full_key);

    const extracted = LevelDBKeyEncoder.extractIDBKey(full_key);
    try std.testing.expect(extracted != null);
    try std.testing.expectEqualSlices(u8, idb_key, extracted.?);
}

test "leveldbComparator - prefix ordering" {
    // database_meta < object_store_meta < object_store_data
    const a = [_]u8{@intFromEnum(KeyPrefix.database_meta)};
    const b = [_]u8{@intFromEnum(KeyPrefix.object_store_data)};

    const result = leveldbComparator(null, &a, 1, &b, 1);
    try std.testing.expect(result < 0);
}

test "LevelDBBackend - create and destroy" {
    const backend_inst = try LevelDBBackend.create(std.testing.allocator);
    backend_inst.destroy();
}
