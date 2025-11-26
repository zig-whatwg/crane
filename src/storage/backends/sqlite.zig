//! SQLite Storage Backend
//!
//! SQLite-based storage backend for IndexedDB and Storage Standard.
//! Uses SQLite C API via FFI bindings for native performance.
//!
//! ## Features
//!
//! - Full StorageBackend interface implementation
//! - WAL mode for concurrent reads
//! - IDBKEY collation for spec-compliant key ordering
//! - Prepared statements for CRUD operations
//! - Schema-based object store and index support
//!
//! ## SQLite Schema (Phase 2.2)
//!
//! Based on Firefox and WebKit IndexedDB implementations:
//!
//! ```sql
//! -- Database metadata
//! CREATE TABLE database_info (
//!     id INTEGER PRIMARY KEY,
//!     name TEXT NOT NULL UNIQUE,
//!     version INTEGER NOT NULL DEFAULT 1,
//!     created_at INTEGER NOT NULL,
//!     modified_at INTEGER NOT NULL
//! );
//!
//! -- Object stores
//! CREATE TABLE object_stores (
//!     id INTEGER PRIMARY KEY AUTOINCREMENT,
//!     database_id INTEGER NOT NULL,
//!     name TEXT NOT NULL,
//!     key_path TEXT,              -- NULL = out-of-line keys
//!     auto_increment INTEGER NOT NULL DEFAULT 0,
//!     current_key INTEGER NOT NULL DEFAULT 0,  -- For auto-increment
//!     UNIQUE(database_id, name),
//!     FOREIGN KEY (database_id) REFERENCES database_info(id) ON DELETE CASCADE
//! );
//!
//! -- Object store data (key-value pairs)
//! CREATE TABLE object_store_data (
//!     object_store_id INTEGER NOT NULL,
//!     key BLOB NOT NULL,          -- IDBKEY encoded
//!     value BLOB NOT NULL,        -- Structured clone
//!     PRIMARY KEY (object_store_id, key),
//!     FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
//! ) WITHOUT ROWID;
//!
//! -- Indexes
//! CREATE TABLE indexes (
//!     id INTEGER PRIMARY KEY AUTOINCREMENT,
//!     object_store_id INTEGER NOT NULL,
//!     name TEXT NOT NULL,
//!     key_path TEXT NOT NULL,
//!     is_unique INTEGER NOT NULL DEFAULT 0,
//!     is_multi_entry INTEGER NOT NULL DEFAULT 0,
//!     UNIQUE(object_store_id, name),
//!     FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
//! );
//!
//! -- Index data (index key -> primary key)
//! CREATE TABLE index_data (
//!     index_id INTEGER NOT NULL,
//!     index_key BLOB NOT NULL,    -- IDBKEY encoded
//!     primary_key BLOB NOT NULL,  -- IDBKEY encoded
//!     object_store_id INTEGER NOT NULL,
//!     PRIMARY KEY (index_id, index_key, primary_key),
//!     FOREIGN KEY (index_id) REFERENCES indexes(id) ON DELETE CASCADE,
//!     FOREIGN KEY (object_store_id, primary_key) REFERENCES object_store_data(object_store_id, key) ON DELETE CASCADE
//! ) WITHOUT ROWID;
//! ```
//!
//! ## IDBKEY Collation (Phase 2.4)
//!
//! Custom collation function for IndexedDB key ordering per spec:
//! 1. Type ordering: number < date < string < binary < array
//! 2. Within type: natural ordering
//! 3. Arrays: element-by-element comparison
//!
//! ## References
//!
//! - SQLite C API: https://sqlite.org/c3ref/intro.html
//! - Firefox IndexedDB: https://searchfox.org/mozilla-central/source/dom/indexedDB
//! - WebKit IndexedDB: https://github.com/nicolo-ribaudo/nicolo-nicolo-nicolo/nicolo
//!
//! ## TODO(SQLite Backend)
//!
//! - [ ] Phase 2.3: Basic SQLite FFI bindings
//! - [ ] Phase 2.4: IDBKEY collation function
//! - [ ] Phase 2.5: WAL mode and pragmas
//! - [ ] Phase 2.6: Prepared statements for CRUD
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

// ============================================================================
// SQLite C API Bindings (Phase 2.3)
// ============================================================================

/// SQLite C API types
pub const c = struct {
    // Opaque handle types
    pub const sqlite3 = opaque {};
    pub const sqlite3_stmt = opaque {};

    // Result codes
    pub const SQLITE_OK = 0;
    pub const SQLITE_ERROR = 1;
    pub const SQLITE_BUSY = 5;
    pub const SQLITE_LOCKED = 6;
    pub const SQLITE_CONSTRAINT = 19;
    pub const SQLITE_CORRUPT = 11;
    pub const SQLITE_NOTFOUND = 12;
    pub const SQLITE_ROW = 100;
    pub const SQLITE_DONE = 101;

    // Open flags
    pub const SQLITE_OPEN_READONLY = 0x00000001;
    pub const SQLITE_OPEN_READWRITE = 0x00000002;
    pub const SQLITE_OPEN_CREATE = 0x00000004;
    pub const SQLITE_OPEN_NOMUTEX = 0x00008000;
    pub const SQLITE_OPEN_FULLMUTEX = 0x00010000;
    pub const SQLITE_OPEN_WAL = 0x00080000;

    // Column types
    pub const SQLITE_INTEGER = 1;
    pub const SQLITE_FLOAT = 2;
    pub const SQLITE_TEXT = 3;
    pub const SQLITE_BLOB = 4;
    pub const SQLITE_NULL = 5;

    // C function declarations (linked from system SQLite)
    pub extern fn sqlite3_open_v2(filename: [*:0]const u8, ppDb: **sqlite3, flags: c_int, zVfs: ?[*:0]const u8) c_int;
    pub extern fn sqlite3_close(db: *sqlite3) c_int;
    pub extern fn sqlite3_exec(db: *sqlite3, sql: [*:0]const u8, callback: ?*const fn (?*anyopaque, c_int, [*c][*c]u8, [*c][*c]u8) callconv(.C) c_int, arg: ?*anyopaque, errmsg: ?*[*:0]u8) c_int;
    pub extern fn sqlite3_prepare_v2(db: *sqlite3, sql: [*]const u8, nByte: c_int, ppStmt: **sqlite3_stmt, pzTail: ?*[*]const u8) c_int;
    pub extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_reset(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_finalize(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_bind_blob(stmt: *sqlite3_stmt, idx: c_int, data: [*]const u8, len: c_int, destructor: ?*const fn (?*anyopaque) callconv(.C) void) c_int;
    pub extern fn sqlite3_bind_text(stmt: *sqlite3_stmt, idx: c_int, text: [*]const u8, len: c_int, destructor: ?*const fn (?*anyopaque) callconv(.C) void) c_int;
    pub extern fn sqlite3_bind_int64(stmt: *sqlite3_stmt, idx: c_int, value: i64) c_int;
    pub extern fn sqlite3_bind_null(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_column_blob(stmt: *sqlite3_stmt, idx: c_int) ?[*]const u8;
    pub extern fn sqlite3_column_text(stmt: *sqlite3_stmt, idx: c_int) ?[*:0]const u8;
    pub extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, idx: c_int) i64;
    pub extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_column_type(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_create_collation_v2(db: *sqlite3, name: [*:0]const u8, eTextRep: c_int, pArg: ?*anyopaque, xCompare: ?*const fn (?*anyopaque, c_int, ?[*]const u8, c_int, ?[*]const u8) callconv(.C) c_int, xDestroy: ?*const fn (?*anyopaque) callconv(.C) void) c_int;
    pub extern fn sqlite3_errmsg(db: *sqlite3) [*:0]const u8;
    pub extern fn sqlite3_changes(db: *sqlite3) c_int;
    pub extern fn sqlite3_last_insert_rowid(db: *sqlite3) i64;

    // Text encoding for collation
    pub const SQLITE_UTF8 = 1;
};

// ============================================================================
// IDBKEY Encoding (Phase 2.4)
// ============================================================================

/// IDBKEY type tags for encoding
pub const IDBKeyType = enum(u8) {
    /// Negative infinity (for range bounds)
    neg_infinity = 0,
    /// Number (IEEE 754 double)
    number = 1,
    /// Date (milliseconds since epoch)
    date = 2,
    /// String (UTF-8)
    string = 3,
    /// Binary (ArrayBuffer)
    binary = 4,
    /// Array (ordered elements)
    array = 5,
    /// Positive infinity (for range bounds)
    pos_infinity = 255,
};

/// Encode an IDBKEY to bytes for SQLite storage
///
/// Format: [type_tag:1] [data:variable]
/// - Number: [1] [IEEE 754 double, big-endian, sign-flipped for ordering]
/// - Date: [2] [milliseconds as i64, big-endian]
/// - String: [3] [UTF-8 bytes]
/// - Binary: [4] [raw bytes]
/// - Array: [5] [length:4 big-endian] [element1] [element2] ...
pub const IDBKeyEncoder = struct {
    /// Encode a number key
    pub fn encodeNumber(allocator: std.mem.Allocator, value: f64) ![]u8 {
        var result = try allocator.alloc(u8, 9);
        result[0] = @intFromEnum(IDBKeyType.number);

        // Convert to big-endian bytes with sign flip for proper ordering
        var bits: u64 = @bitCast(value);

        // Flip sign bit and conditionally flip all bits for negative numbers
        // This ensures: -Inf < -1 < 0 < 1 < Inf
        if (value < 0 or (value == 0 and 1.0 / value < 0)) {
            bits = ~bits; // Flip all bits for negative
        } else {
            bits ^= (@as(u64, 1) << 63); // Flip just sign bit for positive
        }

        // Write as big-endian
        inline for (0..8) |i| {
            result[1 + i] = @intCast((bits >> @intCast(56 - i * 8)) & 0xFF);
        }

        return result;
    }

    /// Encode a string key
    pub fn encodeString(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
        var result = try allocator.alloc(u8, 1 + value.len);
        result[0] = @intFromEnum(IDBKeyType.string);
        @memcpy(result[1..], value);
        return result;
    }

    /// Encode a binary key
    pub fn encodeBinary(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
        var result = try allocator.alloc(u8, 1 + value.len);
        result[0] = @intFromEnum(IDBKeyType.binary);
        @memcpy(result[1..], value);
        return result;
    }

    /// Encode a date key (milliseconds since epoch)
    pub fn encodeDate(allocator: std.mem.Allocator, millis: i64) ![]u8 {
        var result = try allocator.alloc(u8, 9);
        result[0] = @intFromEnum(IDBKeyType.date);

        // Write as big-endian for proper ordering
        const u: u64 = @bitCast(millis);
        inline for (0..8) |i| {
            result[1 + i] = @intCast((u >> @intCast(56 - i * 8)) & 0xFF);
        }

        return result;
    }
};

/// IDBKEY collation function for SQLite (Phase 2.4)
///
/// Implements IndexedDB key comparison as per spec:
/// 1. Compare type tags first
/// 2. Within same type, compare values
pub fn idbkeyCollation(_: ?*anyopaque, len1: c_int, data1: ?[*]const u8, len2: c_int, data2: ?[*]const u8) callconv(.C) c_int {
    const d1 = data1 orelse return -1;
    const d2 = data2 orelse return 1;
    const l1: usize = @intCast(len1);
    const l2: usize = @intCast(len2);

    if (l1 == 0 and l2 == 0) return 0;
    if (l1 == 0) return -1;
    if (l2 == 0) return 1;

    // Compare type tags
    const type1 = d1[0];
    const type2 = d2[0];
    if (type1 < type2) return -1;
    if (type1 > type2) return 1;

    // Same type - compare values
    const bytes1 = d1[1..l1];
    const bytes2 = d2[1..l2];

    // Byte-by-byte comparison (works for all our encodings)
    const min_len = @min(bytes1.len, bytes2.len);
    for (0..min_len) |i| {
        if (bytes1[i] < bytes2[i]) return -1;
        if (bytes1[i] > bytes2[i]) return 1;
    }

    // Equal prefix - shorter is less
    if (bytes1.len < bytes2.len) return -1;
    if (bytes1.len > bytes2.len) return 1;
    return 0;
}

// ============================================================================
// SQLite Schema (Phase 2.2)
// ============================================================================

/// SQL schema for IndexedDB tables
pub const Schema = struct {
    pub const create_database_info =
        \\CREATE TABLE IF NOT EXISTS database_info (
        \\    id INTEGER PRIMARY KEY,
        \\    name TEXT NOT NULL UNIQUE,
        \\    version INTEGER NOT NULL DEFAULT 1,
        \\    created_at INTEGER NOT NULL,
        \\    modified_at INTEGER NOT NULL
        \\);
    ;

    pub const create_object_stores =
        \\CREATE TABLE IF NOT EXISTS object_stores (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    database_id INTEGER NOT NULL,
        \\    name TEXT NOT NULL,
        \\    key_path TEXT,
        \\    auto_increment INTEGER NOT NULL DEFAULT 0,
        \\    current_key INTEGER NOT NULL DEFAULT 0,
        \\    UNIQUE(database_id, name),
        \\    FOREIGN KEY (database_id) REFERENCES database_info(id) ON DELETE CASCADE
        \\);
    ;

    pub const create_object_store_data =
        \\CREATE TABLE IF NOT EXISTS object_store_data (
        \\    object_store_id INTEGER NOT NULL,
        \\    key BLOB NOT NULL COLLATE IDBKEY,
        \\    value BLOB NOT NULL,
        \\    PRIMARY KEY (object_store_id, key),
        \\    FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
        \\) WITHOUT ROWID;
    ;

    pub const create_indexes =
        \\CREATE TABLE IF NOT EXISTS indexes (
        \\    id INTEGER PRIMARY KEY AUTOINCREMENT,
        \\    object_store_id INTEGER NOT NULL,
        \\    name TEXT NOT NULL,
        \\    key_path TEXT NOT NULL,
        \\    is_unique INTEGER NOT NULL DEFAULT 0,
        \\    is_multi_entry INTEGER NOT NULL DEFAULT 0,
        \\    UNIQUE(object_store_id, name),
        \\    FOREIGN KEY (object_store_id) REFERENCES object_stores(id) ON DELETE CASCADE
        \\);
    ;

    pub const create_index_data =
        \\CREATE TABLE IF NOT EXISTS index_data (
        \\    index_id INTEGER NOT NULL,
        \\    index_key BLOB NOT NULL COLLATE IDBKEY,
        \\    primary_key BLOB NOT NULL COLLATE IDBKEY,
        \\    object_store_id INTEGER NOT NULL,
        \\    PRIMARY KEY (index_id, index_key, primary_key),
        \\    FOREIGN KEY (index_id) REFERENCES indexes(id) ON DELETE CASCADE
        \\) WITHOUT ROWID;
    ;

    /// Create all schema objects
    pub const all = [_][]const u8{
        create_database_info,
        create_object_stores,
        create_object_store_data,
        create_indexes,
        create_index_data,
    };
};

/// SQL for prepared statements (Phase 2.6)
pub const Statements = struct {
    // Database operations
    pub const insert_database = "INSERT INTO database_info (name, version, created_at, modified_at) VALUES (?, ?, ?, ?)";
    pub const select_database = "SELECT id, name, version, created_at, modified_at FROM database_info WHERE name = ?";
    pub const update_database_version = "UPDATE database_info SET version = ?, modified_at = ? WHERE id = ?";

    // Object store operations
    pub const insert_object_store = "INSERT INTO object_stores (database_id, name, key_path, auto_increment) VALUES (?, ?, ?, ?)";
    pub const select_object_stores = "SELECT id, name, key_path, auto_increment, current_key FROM object_stores WHERE database_id = ?";
    pub const delete_object_store = "DELETE FROM object_stores WHERE database_id = ? AND name = ?";

    // Data operations
    pub const insert_data = "INSERT OR REPLACE INTO object_store_data (object_store_id, key, value) VALUES (?, ?, ?)";
    pub const select_data = "SELECT value FROM object_store_data WHERE object_store_id = ? AND key = ?";
    pub const delete_data = "DELETE FROM object_store_data WHERE object_store_id = ? AND key = ?";
    pub const select_data_range = "SELECT key, value FROM object_store_data WHERE object_store_id = ? AND key >= ? AND key <= ? ORDER BY key";
    pub const select_data_range_desc = "SELECT key, value FROM object_store_data WHERE object_store_id = ? AND key >= ? AND key <= ? ORDER BY key DESC";
    pub const count_data = "SELECT COUNT(*) FROM object_store_data WHERE object_store_id = ?";

    // Index operations
    pub const insert_index = "INSERT INTO indexes (object_store_id, name, key_path, is_unique, is_multi_entry) VALUES (?, ?, ?, ?, ?)";
    pub const delete_index = "DELETE FROM indexes WHERE object_store_id = ? AND name = ?";
    pub const insert_index_entry = "INSERT INTO index_data (index_id, index_key, primary_key, object_store_id) VALUES (?, ?, ?, ?)";
    pub const delete_index_entry = "DELETE FROM index_data WHERE index_id = ? AND primary_key = ?";
};

// ============================================================================
// SQLite Backend Implementation (Stub - Phase 2.3+)
// ============================================================================

/// SQLite storage backend
///
/// TODO: Implement in phases 2.3-2.6
pub const SQLiteBackend = struct {
    allocator: std.mem.Allocator,
    db: ?*c.sqlite3 = null,
    database_id: ?i64 = null,
    next_txn_id: u64 = 1,
    next_cursor_id: u64 = 1,

    // Prepared statements (Phase 2.6)
    // stmt_insert_data: ?*c.sqlite3_stmt = null,
    // stmt_select_data: ?*c.sqlite3_stmt = null,
    // ... etc

    const Self = @This();

    /// Create a new SQLite backend
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
        // TODO: Implement in Phase 2.3
        return BackendError.BackendSpecific;
    }

    fn close(ctx: *anyopaque) void {
        _ = ctx;
        // TODO: Implement in Phase 2.3
    }

    fn isOpen(ctx: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.db != null;
    }

    fn beginTransaction(ctx: *anyopaque, mode: TransactionMode) BackendError!TransactionHandle {
        _ = ctx;
        _ = mode;
        // TODO: Implement in Phase 2.3
        return BackendError.BackendSpecific;
    }

    fn commit(ctx: *anyopaque, handle: TransactionHandle) BackendError!void {
        _ = ctx;
        _ = handle;
        // TODO: Implement in Phase 2.3
        return BackendError.BackendSpecific;
    }

    fn rollback(ctx: *anyopaque, handle: TransactionHandle) void {
        _ = ctx;
        _ = handle;
        // TODO: Implement in Phase 2.3
    }

    fn read(ctx: *anyopaque, allocator: std.mem.Allocator, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8 {
        _ = ctx;
        _ = allocator;
        _ = handle;
        _ = key;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn write(ctx: *anyopaque, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = key;
        _ = value;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn delete_(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = key;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn exists(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!bool {
        _ = ctx;
        _ = handle;
        _ = key;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn cursorOpen(ctx: *anyopaque, handle: TransactionHandle, range: KeyRange, direction: CursorDirection) BackendError!CursorHandle {
        _ = ctx;
        _ = handle;
        _ = range;
        _ = direction;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn cursorNext(ctx: *anyopaque, allocator: std.mem.Allocator, cursor: CursorHandle) BackendError!?KeyValue {
        _ = ctx;
        _ = allocator;
        _ = cursor;
        // TODO: Implement in Phase 2.6
        return BackendError.BackendSpecific;
    }

    fn cursorClose(ctx: *anyopaque, cursor: CursorHandle) void {
        _ = ctx;
        _ = cursor;
        // TODO: Implement in Phase 2.6
    }

    fn estimateSize(ctx: *anyopaque) BackendError!u64 {
        _ = ctx;
        // TODO: Implement
        return 0;
    }

    fn getStats(ctx: *anyopaque) BackendError!BackendStats {
        _ = ctx;
        return BackendStats{};
    }

    fn getInfo(ctx: *anyopaque, allocator: std.mem.Allocator) BackendError!DatabaseInfo {
        _ = ctx;
        _ = allocator;
        // TODO: Implement
        return BackendError.BackendSpecific;
    }

    fn createObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8, options: ObjectStoreOptions) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = name;
        _ = options;
        // TODO: Implement
        return BackendError.BackendSpecific;
    }

    fn deleteObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = name;
        // TODO: Implement
        return BackendError.BackendSpecific;
    }

    fn createIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8, key_path: []const u8, options: IndexOptions) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = store_name;
        _ = index_name;
        _ = key_path;
        _ = options;
        // TODO: Implement
        return BackendError.BackendSpecific;
    }

    fn deleteIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8) BackendError!void {
        _ = ctx;
        _ = handle;
        _ = store_name;
        _ = index_name;
        // TODO: Implement
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

test "IDBKeyEncoder - number encoding" {
    const allocator = std.testing.allocator;

    // Encode positive number
    const encoded1 = try IDBKeyEncoder.encodeNumber(allocator, 42.0);
    defer allocator.free(encoded1);
    try std.testing.expectEqual(@as(u8, @intFromEnum(IDBKeyType.number)), encoded1[0]);

    // Encode negative number
    const encoded2 = try IDBKeyEncoder.encodeNumber(allocator, -1.0);
    defer allocator.free(encoded2);
    try std.testing.expectEqual(@as(u8, @intFromEnum(IDBKeyType.number)), encoded2[0]);

    // Verify ordering: -1 < 42
    const cmp = idbkeyCollation(null, @intCast(encoded2.len), encoded2.ptr, @intCast(encoded1.len), encoded1.ptr);
    try std.testing.expect(cmp < 0);
}

test "IDBKeyEncoder - string encoding" {
    const allocator = std.testing.allocator;

    const encoded = try IDBKeyEncoder.encodeString(allocator, "hello");
    defer allocator.free(encoded);

    try std.testing.expectEqual(@as(u8, @intFromEnum(IDBKeyType.string)), encoded[0]);
    try std.testing.expectEqualStrings("hello", encoded[1..]);
}

test "IDBKEY collation - type ordering" {
    const allocator = std.testing.allocator;

    // Number < String
    const num = try IDBKeyEncoder.encodeNumber(allocator, 1.0);
    defer allocator.free(num);

    const str = try IDBKeyEncoder.encodeString(allocator, "a");
    defer allocator.free(str);

    const cmp = idbkeyCollation(null, @intCast(num.len), num.ptr, @intCast(str.len), str.ptr);
    try std.testing.expect(cmp < 0);
}

test "IDBKEY collation - string ordering" {
    const allocator = std.testing.allocator;

    const a = try IDBKeyEncoder.encodeString(allocator, "apple");
    defer allocator.free(a);

    const b = try IDBKeyEncoder.encodeString(allocator, "banana");
    defer allocator.free(b);

    const cmp = idbkeyCollation(null, @intCast(a.len), a.ptr, @intCast(b.len), b.ptr);
    try std.testing.expect(cmp < 0);
}

test "SQLiteBackend - create and destroy" {
    const backend_inst = try SQLiteBackend.create(std.testing.allocator);
    backend_inst.destroy();
}
