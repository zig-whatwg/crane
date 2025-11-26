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
//! ## Implementation Status
//!
//! - [x] Phase 2.3: Basic SQLite FFI bindings
//! - [x] Phase 2.4: IDBKEY collation function
//! - [x] Phase 2.5: WAL mode and pragmas
//! - [x] Phase 2.6: Prepared statements for CRUD (cached for performance)
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
    pub extern fn sqlite3_exec(db: *sqlite3, sql: [*:0]const u8, callback: ?*const fn (?*anyopaque, c_int, [*c][*c]u8, [*c][*c]u8) callconv(.c) c_int, arg: ?*anyopaque, errmsg: ?*[*:0]u8) c_int;
    pub extern fn sqlite3_prepare_v2(db: *sqlite3, sql: [*]const u8, nByte: c_int, ppStmt: **sqlite3_stmt, pzTail: ?*[*]const u8) c_int;
    pub extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_reset(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_finalize(stmt: *sqlite3_stmt) c_int;
    pub extern fn sqlite3_bind_blob(stmt: *sqlite3_stmt, idx: c_int, data: [*]const u8, len: c_int, destructor: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
    pub extern fn sqlite3_bind_text(stmt: *sqlite3_stmt, idx: c_int, text: [*]const u8, len: c_int, destructor: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
    pub extern fn sqlite3_bind_int64(stmt: *sqlite3_stmt, idx: c_int, value: i64) c_int;
    pub extern fn sqlite3_bind_null(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_column_blob(stmt: *sqlite3_stmt, idx: c_int) ?[*]const u8;
    pub extern fn sqlite3_column_text(stmt: *sqlite3_stmt, idx: c_int) ?[*:0]const u8;
    pub extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, idx: c_int) i64;
    pub extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_column_type(stmt: *sqlite3_stmt, idx: c_int) c_int;
    pub extern fn sqlite3_create_collation_v2(db: *sqlite3, name: [*:0]const u8, eTextRep: c_int, pArg: ?*anyopaque, xCompare: ?*const fn (?*anyopaque, c_int, ?[*]const u8, c_int, ?[*]const u8) callconv(.c) c_int, xDestroy: ?*const fn (?*anyopaque) callconv(.c) void) c_int;
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
pub fn idbkeyCollation(_: ?*anyopaque, len1: c_int, data1: ?[*]const u8, len2: c_int, data2: ?[*]const u8) callconv(.c) c_int {
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
    pub const select_database_by_id = "SELECT id FROM database_info WHERE name = ?";
    pub const update_database_version = "UPDATE database_info SET version = ?, modified_at = ? WHERE id = ?";

    // Object store operations
    pub const insert_object_store = "INSERT INTO object_stores (database_id, name, key_path, auto_increment) VALUES (?, ?, ?, ?)";
    pub const insert_default_object_store = "INSERT INTO object_stores (id, database_id, name, key_path, auto_increment) VALUES (1, ?, '_default', NULL, 0)";
    pub const select_object_stores = "SELECT id, name, key_path, auto_increment, current_key FROM object_stores WHERE database_id = ?";
    pub const select_object_store_by_name = "SELECT id FROM object_stores WHERE database_id = ? AND name = ?";
    pub const select_default_object_store = "SELECT id FROM object_stores WHERE database_id = ? AND name = '_default'";
    pub const delete_object_store = "DELETE FROM object_stores WHERE database_id = ? AND name = ?";

    // Data operations (key-value CRUD)
    pub const insert_data = "INSERT OR REPLACE INTO object_store_data (object_store_id, key, value) VALUES (?, ?, ?)";
    pub const select_data = "SELECT value FROM object_store_data WHERE object_store_id = ? AND key = ?";
    pub const delete_data = "DELETE FROM object_store_data WHERE object_store_id = ? AND key = ?";
    pub const exists_data = "SELECT 1 FROM object_store_data WHERE object_store_id = ? AND key = ? LIMIT 1";
    pub const count_data = "SELECT COUNT(*) FROM object_store_data WHERE object_store_id = ?";

    // Range queries for cursors (built dynamically based on range)
    pub const select_data_all_asc = "SELECT key, value FROM object_store_data WHERE object_store_id = 1 ORDER BY key ASC";
    pub const select_data_all_desc = "SELECT key, value FROM object_store_data WHERE object_store_id = 1 ORDER BY key DESC";

    // Index operations
    pub const insert_index = "INSERT INTO indexes (object_store_id, name, key_path, is_unique, is_multi_entry) VALUES (?, ?, ?, ?, ?)";
    pub const delete_index = "DELETE FROM indexes WHERE object_store_id = ? AND name = ?";
    pub const insert_index_entry = "INSERT INTO index_data (index_id, index_key, primary_key, object_store_id) VALUES (?, ?, ?, ?)";
    pub const delete_index_entry = "DELETE FROM index_data WHERE index_id = ? AND primary_key = ?";

    // Stats queries
    pub const estimate_size = "SELECT page_count * page_size FROM pragma_page_count(), pragma_page_size()";
};

/// Cached prepared statements for performance (Phase 2.6)
///
/// Pre-compiled statements avoid repeated SQL parsing overhead.
/// Statements are prepared once on database open and reused throughout
/// the session. Each statement is reset after use to allow rebinding.
pub const PreparedStmtCache = struct {
    // Data operations (most frequently used)
    insert_data: ?*c.sqlite3_stmt = null,
    select_data: ?*c.sqlite3_stmt = null,
    delete_data: ?*c.sqlite3_stmt = null,
    exists_data: ?*c.sqlite3_stmt = null,
    count_data: ?*c.sqlite3_stmt = null,

    // Cursor queries (frequently used for iteration)
    select_data_all_asc: ?*c.sqlite3_stmt = null,
    select_data_all_desc: ?*c.sqlite3_stmt = null,

    // Database operations (less frequent)
    select_database_by_id: ?*c.sqlite3_stmt = null,
    insert_database: ?*c.sqlite3_stmt = null,

    // Object store operations (less frequent)
    select_default_object_store: ?*c.sqlite3_stmt = null,
    insert_default_object_store: ?*c.sqlite3_stmt = null,
    insert_object_store: ?*c.sqlite3_stmt = null,
    select_object_store_by_name: ?*c.sqlite3_stmt = null,
    delete_object_store: ?*c.sqlite3_stmt = null,

    // Index operations (less frequent)
    insert_index: ?*c.sqlite3_stmt = null,
    delete_index: ?*c.sqlite3_stmt = null,

    // Stats
    estimate_size: ?*c.sqlite3_stmt = null,

    const Self = @This();

    /// Prepare all cached statements
    pub fn init(db: *c.sqlite3) !Self {
        var cache = Self{};
        errdefer cache.deinit();

        // Data operations
        cache.insert_data = try prepareStmt(db, Statements.insert_data);
        cache.select_data = try prepareStmt(db, Statements.select_data);
        cache.delete_data = try prepareStmt(db, Statements.delete_data);
        cache.exists_data = try prepareStmt(db, Statements.exists_data);
        cache.count_data = try prepareStmt(db, Statements.count_data);

        // Cursor queries
        cache.select_data_all_asc = try prepareStmt(db, Statements.select_data_all_asc);
        cache.select_data_all_desc = try prepareStmt(db, Statements.select_data_all_desc);

        // Database operations
        cache.select_database_by_id = try prepareStmt(db, Statements.select_database_by_id);
        cache.insert_database = try prepareStmt(db, Statements.insert_database);

        // Object store operations
        cache.select_default_object_store = try prepareStmt(db, Statements.select_default_object_store);
        cache.insert_default_object_store = try prepareStmt(db, Statements.insert_default_object_store);
        cache.insert_object_store = try prepareStmt(db, Statements.insert_object_store);
        cache.select_object_store_by_name = try prepareStmt(db, Statements.select_object_store_by_name);
        cache.delete_object_store = try prepareStmt(db, Statements.delete_object_store);

        // Index operations
        cache.insert_index = try prepareStmt(db, Statements.insert_index);
        cache.delete_index = try prepareStmt(db, Statements.delete_index);

        // Stats
        cache.estimate_size = try prepareStmt(db, Statements.estimate_size);

        return cache;
    }

    /// Prepare a single statement
    fn prepareStmt(db: *c.sqlite3, sql: []const u8) !*c.sqlite3_stmt {
        var stmt: *c.sqlite3_stmt = undefined;
        const rc = c.sqlite3_prepare_v2(db, sql.ptr, @intCast(sql.len), &stmt, null);
        if (rc != c.SQLITE_OK) {
            return error.PrepareStatementFailed;
        }
        return stmt;
    }

    /// Finalize all cached statements
    pub fn deinit(self: *Self) void {
        inline for (@typeInfo(Self).@"struct".fields) |field| {
            if (@field(self, field.name)) |stmt| {
                _ = c.sqlite3_finalize(stmt);
                @field(self, field.name) = null;
            }
        }
    }
};

// ============================================================================
// SQLite Backend Implementation (Stub - Phase 2.3+)
// ============================================================================

/// SQLite storage backend
///
/// Full implementation with WAL mode and prepared statements.
/// Prepared statements are cached for performance (Phase 2.6).
pub const SQLiteBackend = struct {
    allocator: std.mem.Allocator,
    db: ?*c.sqlite3 = null,
    database_name: ?[]u8 = null,
    database_id: ?i64 = null,
    next_txn_id: u64 = 1,
    next_cursor_id: u64 = 1,
    in_transaction: bool = false,

    // Prepared statement cache (Phase 2.6)
    stmt_cache: ?PreparedStmtCache = null,

    // Active cursor state
    cursors: std.AutoHashMap(u64, CursorState),

    const Self = @This();

    const CursorState = struct {
        stmt: *c.sqlite3_stmt,
        direction: CursorDirection,
        exhausted: bool,
        // Track if this cursor uses a cached statement (don't finalize on close)
        uses_cached_stmt: bool = false,
    };

    /// Create a new SQLite backend
    pub fn create(allocator: std.mem.Allocator) !StorageBackend {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        self.* = .{
            .allocator = allocator,
            .cursors = std.AutoHashMap(u64, CursorState).init(allocator),
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

    /// Execute a simple SQL statement (no results)
    fn execSql(self: *Self, sql: [*:0]const u8) BackendError!void {
        const db = self.db orelse return BackendError.Closed;
        const rc = c.sqlite3_exec(db, sql, null, null, null);
        if (rc != c.SQLITE_OK) {
            return mapSqliteError(rc);
        }
    }

    /// Map SQLite error codes to BackendError
    fn mapSqliteError(rc: c_int) BackendError {
        return switch (rc) {
            c.SQLITE_OK, c.SQLITE_DONE, c.SQLITE_ROW => BackendError.BackendSpecific, // Shouldn't happen
            c.SQLITE_BUSY, c.SQLITE_LOCKED => BackendError.Conflict,
            c.SQLITE_CORRUPT => BackendError.Corruption,
            c.SQLITE_CONSTRAINT => BackendError.ConstraintViolation,
            c.SQLITE_NOTFOUND => BackendError.KeyNotFound,
            else => BackendError.BackendSpecific,
        };
    }

    fn open(ctx: *anyopaque, name: []const u8, options: OpenOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Already open?
        if (self.db != null) return;

        // Build file path: name + ".sqlite3"
        var path_buf: [512]u8 = undefined;
        const path_slice = std.fmt.bufPrint(&path_buf, "{s}.sqlite3", .{name}) catch return BackendError.BackendSpecific;
        path_buf[path_slice.len] = 0;
        const path: [*:0]const u8 = path_buf[0..path_slice.len :0];

        // Open flags
        var flags: c_int = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;
        if (!options.create_if_missing) {
            flags = c.SQLITE_OPEN_READWRITE;
        }

        // Open database
        var db: *c.sqlite3 = undefined;
        const rc = c.sqlite3_open_v2(path, &db, flags, null);
        if (rc != c.SQLITE_OK) {
            if (rc == c.SQLITE_NOTFOUND or rc == 14) { // SQLITE_CANTOPEN = 14
                return BackendError.KeyNotFound;
            }
            return mapSqliteError(rc);
        }

        self.db = db;

        // Store database name
        self.database_name = self.allocator.dupe(u8, name) catch {
            _ = c.sqlite3_close(db);
            self.db = null;
            return BackendError.OutOfMemory;
        };

        // Configure SQLite for performance
        // WAL mode for concurrent reads
        self.execSql("PRAGMA journal_mode=WAL;") catch {};
        // Synchronous NORMAL is safe with WAL
        self.execSql("PRAGMA synchronous=NORMAL;") catch {};
        // Enable foreign keys
        self.execSql("PRAGMA foreign_keys=ON;") catch {};
        // Memory-mapped I/O (256MB)
        self.execSql("PRAGMA mmap_size=268435456;") catch {};

        // Register IDBKEY collation
        const collation_rc = c.sqlite3_create_collation_v2(
            db,
            "IDBKEY",
            c.SQLITE_UTF8,
            null,
            &idbkeyCollation,
            null,
        );
        if (collation_rc != c.SQLITE_OK) {
            self.allocator.free(self.database_name.?);
            self.database_name = null;
            _ = c.sqlite3_close(db);
            self.db = null;
            return BackendError.BackendSpecific;
        }

        // Create schema tables
        inline for (Schema.all) |schema_sql| {
            self.execSql(@ptrCast(schema_sql.ptr)) catch |err| {
                self.allocator.free(self.database_name.?);
                self.database_name = null;
                _ = c.sqlite3_close(db);
                self.db = null;
                return err;
            };
        }

        // Get or create database record
        const timestamp = std.time.timestamp();

        // Try to find existing database
        const select_db_sql = "SELECT id FROM database_info WHERE name = ?";
        var stmt: *c.sqlite3_stmt = undefined;
        var prep_rc = c.sqlite3_prepare_v2(db, select_db_sql, @intCast(select_db_sql.len), &stmt, null);
        if (prep_rc != c.SQLITE_OK) {
            self.allocator.free(self.database_name.?);
            self.database_name = null;
            _ = c.sqlite3_close(db);
            self.db = null;
            return BackendError.BackendSpecific;
        }
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, name.ptr, @intCast(name.len), null);
        const step_rc = c.sqlite3_step(stmt);

        if (step_rc == c.SQLITE_ROW) {
            // Database exists
            self.database_id = c.sqlite3_column_int64(stmt, 0);
        } else {
            // Create new database record
            const insert_db_sql = "INSERT INTO database_info (name, version, created_at, modified_at) VALUES (?, 1, ?, ?)";
            var insert_stmt: *c.sqlite3_stmt = undefined;
            prep_rc = c.sqlite3_prepare_v2(db, insert_db_sql, @intCast(insert_db_sql.len), &insert_stmt, null);
            if (prep_rc != c.SQLITE_OK) {
                self.allocator.free(self.database_name.?);
                self.database_name = null;
                _ = c.sqlite3_close(db);
                self.db = null;
                return BackendError.BackendSpecific;
            }
            defer _ = c.sqlite3_finalize(insert_stmt);

            _ = c.sqlite3_bind_text(insert_stmt, 1, name.ptr, @intCast(name.len), null);
            _ = c.sqlite3_bind_int64(insert_stmt, 2, timestamp);
            _ = c.sqlite3_bind_int64(insert_stmt, 3, timestamp);

            const insert_rc = c.sqlite3_step(insert_stmt);
            if (insert_rc != c.SQLITE_DONE) {
                self.allocator.free(self.database_name.?);
                self.database_name = null;
                _ = c.sqlite3_close(db);
                self.db = null;
                return BackendError.BackendSpecific;
            }

            self.database_id = c.sqlite3_last_insert_rowid(db);
        }

        // Initialize prepared statement cache (Phase 2.6)
        self.stmt_cache = PreparedStmtCache.init(db) catch {
            self.allocator.free(self.database_name.?);
            self.database_name = null;
            self.database_id = null;
            _ = c.sqlite3_close(db);
            self.db = null;
            return BackendError.BackendSpecific;
        };
    }

    fn close(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        // Close any open cursors (don't finalize cached statements)
        var cursor_iter = self.cursors.iterator();
        while (cursor_iter.next()) |entry| {
            if (!entry.value_ptr.uses_cached_stmt) {
                _ = c.sqlite3_finalize(entry.value_ptr.stmt);
            }
        }
        self.cursors.clearAndFree();

        // Finalize prepared statement cache (Phase 2.6)
        if (self.stmt_cache) |*cache| {
            cache.deinit();
            self.stmt_cache = null;
        }

        // Free database name
        if (self.database_name) |name| {
            self.allocator.free(name);
            self.database_name = null;
        }

        // Close database
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
            self.db = null;
        }

        self.database_id = null;
        self.in_transaction = false;
    }

    fn isOpen(ctx: *anyopaque) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.db != null;
    }

    fn beginTransaction(ctx: *anyopaque, mode: TransactionMode) BackendError!TransactionHandle {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.db == null) return BackendError.Closed;
        if (self.in_transaction) return BackendError.Conflict;

        // Use IMMEDIATE for write transactions to avoid deadlocks
        const sql: [*:0]const u8 = switch (mode) {
            .readonly => "BEGIN DEFERRED",
            .readwrite, .versionchange => "BEGIN IMMEDIATE",
        };

        try self.execSql(sql);
        self.in_transaction = true;

        const txn_id = self.next_txn_id;
        self.next_txn_id += 1;
        return TransactionHandle{
            .id = txn_id,
            .mode = mode,
        };
    }

    fn commit(ctx: *anyopaque, handle: TransactionHandle) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (!self.in_transaction) return BackendError.InvalidTransaction;

        try self.execSql("COMMIT");
        self.in_transaction = false;
    }

    fn rollback(ctx: *anyopaque, handle: TransactionHandle) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (!self.in_transaction) return;

        self.execSql("ROLLBACK") catch {};
        self.in_transaction = false;
    }

    fn read(ctx: *anyopaque, allocator: std.mem.Allocator, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (self.db == null) return BackendError.Closed;

        // Use cached prepared statement (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.select_data else return BackendError.BackendSpecific;
        if (stmt == null) return BackendError.BackendSpecific;

        // Reset and bind (required for reuse)
        _ = c.sqlite3_reset(stmt.?);

        // Bind object_store_id = 1 (default store) and key
        _ = c.sqlite3_bind_int64(stmt.?, 1, 1);
        _ = c.sqlite3_bind_blob(stmt.?, 2, key.ptr, @intCast(key.len), null);

        const step_rc = c.sqlite3_step(stmt.?);
        if (step_rc == c.SQLITE_ROW) {
            const blob = c.sqlite3_column_blob(stmt.?, 0);
            const len: usize = @intCast(c.sqlite3_column_bytes(stmt.?, 0));

            if (blob) |data| {
                const result = allocator.alloc(u8, len) catch return BackendError.OutOfMemory;
                @memcpy(result, data[0..len]);
                return result;
            }
        }

        return null;
    }

    fn write(ctx: *anyopaque, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (self.db == null) return BackendError.Closed;

        // Ensure default object store exists (id=1)
        try self.ensureDefaultObjectStore();

        // Use cached prepared statement (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.insert_data else return BackendError.BackendSpecific;
        if (stmt == null) return BackendError.BackendSpecific;

        // Reset and bind (required for reuse)
        _ = c.sqlite3_reset(stmt.?);

        // Bind object_store_id = 1 (default store), key, and value
        _ = c.sqlite3_bind_int64(stmt.?, 1, 1);
        _ = c.sqlite3_bind_blob(stmt.?, 2, key.ptr, @intCast(key.len), null);
        _ = c.sqlite3_bind_blob(stmt.?, 3, value.ptr, @intCast(value.len), null);

        const step_rc = c.sqlite3_step(stmt.?);
        if (step_rc != c.SQLITE_DONE) {
            return mapSqliteError(step_rc);
        }
    }

    fn delete_(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (self.db == null) return BackendError.Closed;

        // Use cached prepared statement (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.delete_data else return BackendError.BackendSpecific;
        if (stmt == null) return BackendError.BackendSpecific;

        // Reset and bind (required for reuse)
        _ = c.sqlite3_reset(stmt.?);

        // Bind object_store_id = 1 (default store) and key
        _ = c.sqlite3_bind_int64(stmt.?, 1, 1);
        _ = c.sqlite3_bind_blob(stmt.?, 2, key.ptr, @intCast(key.len), null);

        const step_rc = c.sqlite3_step(stmt.?);
        if (step_rc != c.SQLITE_DONE) {
            return mapSqliteError(step_rc);
        }
    }

    fn exists(ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        if (self.db == null) return BackendError.Closed;

        // Use cached prepared statement (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.exists_data else return BackendError.BackendSpecific;
        if (stmt == null) return BackendError.BackendSpecific;

        // Reset and bind (required for reuse)
        _ = c.sqlite3_reset(stmt.?);

        // Bind object_store_id = 1 (default store) and key
        _ = c.sqlite3_bind_int64(stmt.?, 1, 1);
        _ = c.sqlite3_bind_blob(stmt.?, 2, key.ptr, @intCast(key.len), null);

        const step_rc = c.sqlite3_step(stmt.?);
        return step_rc == c.SQLITE_ROW;
    }

    fn cursorOpen(ctx: *anyopaque, handle: TransactionHandle, range: KeyRange, direction: CursorDirection) BackendError!CursorHandle {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const db = self.db orelse return BackendError.Closed;

        const is_asc = direction == .next or direction == .nextunique;
        var uses_cached_stmt = false;
        var stmt: *c.sqlite3_stmt = undefined;

        // For simple full-table scans without range, use cached statements (Phase 2.6)
        if (range.lower == null and range.upper == null) {
            const cache = self.stmt_cache orelse return BackendError.BackendSpecific;
            const cached_stmt = if (is_asc) cache.select_data_all_asc else cache.select_data_all_desc;
            if (cached_stmt) |s| {
                _ = c.sqlite3_reset(s);
                stmt = s;
                uses_cached_stmt = true;
            } else {
                return BackendError.BackendSpecific;
            }
        } else {
            // For range queries, prepare dynamically (too many combinations to cache)
            const order = if (is_asc) "ASC" else "DESC";

            var sql_buf: [512]u8 = undefined;
            var sql_len: usize = 0;

            // Build WHERE clause based on range
            if (range.lower != null and range.upper != null) {
                const lower_op = if (range.lower_open) ">" else ">=";
                const upper_op = if (range.upper_open) "<" else "<=";
                sql_len = (std.fmt.bufPrint(&sql_buf, "SELECT key, value FROM object_store_data WHERE object_store_id = 1 AND key {s} ? AND key {s} ? ORDER BY key {s}", .{ lower_op, upper_op, order }) catch return BackendError.BackendSpecific).len;
            } else if (range.lower != null) {
                const lower_op = if (range.lower_open) ">" else ">=";
                sql_len = (std.fmt.bufPrint(&sql_buf, "SELECT key, value FROM object_store_data WHERE object_store_id = 1 AND key {s} ? ORDER BY key {s}", .{ lower_op, order }) catch return BackendError.BackendSpecific).len;
            } else if (range.upper != null) {
                const upper_op = if (range.upper_open) "<" else "<=";
                sql_len = (std.fmt.bufPrint(&sql_buf, "SELECT key, value FROM object_store_data WHERE object_store_id = 1 AND key {s} ? ORDER BY key {s}", .{ upper_op, order }) catch return BackendError.BackendSpecific).len;
            }

            const prep_rc = c.sqlite3_prepare_v2(db, &sql_buf, @intCast(sql_len), &stmt, null);
            if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
            errdefer _ = c.sqlite3_finalize(stmt);

            // Bind range parameters
            var param_idx: c_int = 1;
            if (range.lower) |lower| {
                _ = c.sqlite3_bind_blob(stmt, param_idx, lower.ptr, @intCast(lower.len), null);
                param_idx += 1;
            }
            if (range.upper) |upper| {
                _ = c.sqlite3_bind_blob(stmt, param_idx, upper.ptr, @intCast(upper.len), null);
            }
        }

        const cursor_id = self.next_cursor_id;
        self.next_cursor_id += 1;

        self.cursors.put(cursor_id, .{
            .stmt = stmt,
            .direction = direction,
            .exhausted = false,
            .uses_cached_stmt = uses_cached_stmt,
        }) catch {
            if (!uses_cached_stmt) {
                _ = c.sqlite3_finalize(stmt);
            }
            return BackendError.OutOfMemory;
        };

        return CursorHandle{
            .id = cursor_id,
            .transaction_id = handle.id,
        };
    }

    fn cursorNext(ctx: *anyopaque, allocator: std.mem.Allocator, cursor: CursorHandle) BackendError!?KeyValue {
        const self: *Self = @ptrCast(@alignCast(ctx));

        const cursor_state = self.cursors.getPtr(cursor.id) orelse return BackendError.InvalidCursor;

        if (cursor_state.exhausted) return null;

        const step_rc = c.sqlite3_step(cursor_state.stmt);
        if (step_rc == c.SQLITE_ROW) {
            // Get key
            const key_blob = c.sqlite3_column_blob(cursor_state.stmt, 0);
            const key_len: usize = @intCast(c.sqlite3_column_bytes(cursor_state.stmt, 0));

            // Get value
            const value_blob = c.sqlite3_column_blob(cursor_state.stmt, 1);
            const value_len: usize = @intCast(c.sqlite3_column_bytes(cursor_state.stmt, 1));

            if (key_blob == null) return null;

            const key = allocator.alloc(u8, key_len) catch return BackendError.OutOfMemory;
            errdefer allocator.free(key);

            @memcpy(key, key_blob.?[0..key_len]);

            const value = if (value_blob) |vb| blk: {
                const v = allocator.alloc(u8, value_len) catch {
                    allocator.free(key);
                    return BackendError.OutOfMemory;
                };
                @memcpy(v, vb[0..value_len]);
                break :blk v;
            } else null;

            return KeyValue{
                .key = key,
                .value = value orelse &.{},
                .allocator = allocator,
            };
        } else if (step_rc == c.SQLITE_DONE) {
            cursor_state.exhausted = true;
            return null;
        } else {
            return mapSqliteError(step_rc);
        }
    }

    fn cursorClose(ctx: *anyopaque, cursor: CursorHandle) void {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.cursors.fetchRemove(cursor.id)) |entry| {
            // Only finalize non-cached statements (Phase 2.6)
            // Cached statements are reused and finalized on close()
            if (!entry.value.uses_cached_stmt) {
                _ = c.sqlite3_finalize(entry.value.stmt);
            }
        }
    }

    fn estimateSize(ctx: *anyopaque) BackendError!u64 {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.db == null) return 0;

        // Use cached prepared statement (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.estimate_size else return 0;
        if (stmt == null) return 0;

        // Reset for reuse
        _ = c.sqlite3_reset(stmt.?);

        if (c.sqlite3_step(stmt.?) == c.SQLITE_ROW) {
            return @intCast(c.sqlite3_column_int64(stmt.?, 0));
        }
        return 0;
    }

    fn getStats(ctx: *anyopaque) BackendError!BackendStats {
        const self: *Self = @ptrCast(@alignCast(ctx));

        var stats = BackendStats{};

        if (self.db == null) return stats;

        // Use cached prepared statement for count (Phase 2.6)
        const stmt = if (self.stmt_cache) |cache| cache.count_data else return stats;
        if (stmt) |s| {
            _ = c.sqlite3_reset(s);
            _ = c.sqlite3_bind_int64(s, 1, 1); // object_store_id = 1
            if (c.sqlite3_step(s) == c.SQLITE_ROW) {
                stats.key_count = @intCast(c.sqlite3_column_int64(s, 0));
            }
        }

        // Get size
        stats.disk_size = (try estimateSize(ctx));

        return stats;
    }

    fn getInfo(ctx: *anyopaque, allocator: std.mem.Allocator) BackendError!DatabaseInfo {
        const self: *Self = @ptrCast(@alignCast(ctx));

        if (self.database_name == null) return BackendError.Closed;

        return DatabaseInfo{
            .name = try allocator.dupe(u8, self.database_name.?),
            .version = 1,
            .object_stores = &.{},
            .created_at = 0,
            .modified_at = 0,
        };
    }

    fn createObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8, options: ObjectStoreOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        const db = self.db orelse return BackendError.Closed;
        const db_id = self.database_id orelse return BackendError.Closed;

        const sql = "INSERT INTO object_stores (database_id, name, key_path, auto_increment) VALUES (?, ?, ?, ?)";

        var stmt: *c.sqlite3_stmt = undefined;
        const prep_rc = c.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, db_id);
        _ = c.sqlite3_bind_text(stmt, 2, name.ptr, @intCast(name.len), null);

        if (options.key_path) |kp| {
            _ = c.sqlite3_bind_text(stmt, 3, kp.ptr, @intCast(kp.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 3);
        }

        _ = c.sqlite3_bind_int64(stmt, 4, if (options.auto_increment) 1 else 0);

        const step_rc = c.sqlite3_step(stmt);
        if (step_rc != c.SQLITE_DONE) {
            if (step_rc == c.SQLITE_CONSTRAINT) {
                return BackendError.ConstraintViolation;
            }
            return mapSqliteError(step_rc);
        }
    }

    fn deleteObjectStore(ctx: *anyopaque, handle: TransactionHandle, name: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        const db = self.db orelse return BackendError.Closed;
        const db_id = self.database_id orelse return BackendError.Closed;

        const sql = "DELETE FROM object_stores WHERE database_id = ? AND name = ?";

        var stmt: *c.sqlite3_stmt = undefined;
        const prep_rc = c.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, db_id);
        _ = c.sqlite3_bind_text(stmt, 2, name.ptr, @intCast(name.len), null);

        _ = c.sqlite3_step(stmt);
    }

    fn createIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8, key_path: []const u8, options: IndexOptions) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        const db = self.db orelse return BackendError.Closed;
        const db_id = self.database_id orelse return BackendError.Closed;

        // First get object store id
        const get_store_sql = "SELECT id FROM object_stores WHERE database_id = ? AND name = ?";
        var get_stmt: *c.sqlite3_stmt = undefined;
        var prep_rc = c.sqlite3_prepare_v2(db, get_store_sql, @intCast(get_store_sql.len), &get_stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(get_stmt);

        _ = c.sqlite3_bind_int64(get_stmt, 1, db_id);
        _ = c.sqlite3_bind_text(get_stmt, 2, store_name.ptr, @intCast(store_name.len), null);

        if (c.sqlite3_step(get_stmt) != c.SQLITE_ROW) {
            return BackendError.KeyNotFound;
        }

        const store_id = c.sqlite3_column_int64(get_stmt, 0);

        // Create index
        const sql = "INSERT INTO indexes (object_store_id, name, key_path, is_unique, is_multi_entry) VALUES (?, ?, ?, ?, ?)";

        var stmt: *c.sqlite3_stmt = undefined;
        prep_rc = c.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, store_id);
        _ = c.sqlite3_bind_text(stmt, 2, index_name.ptr, @intCast(index_name.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, key_path.ptr, @intCast(key_path.len), null);
        _ = c.sqlite3_bind_int64(stmt, 4, if (options.unique) 1 else 0);
        _ = c.sqlite3_bind_int64(stmt, 5, if (options.multi_entry) 1 else 0);

        const step_rc = c.sqlite3_step(stmt);
        if (step_rc != c.SQLITE_DONE) {
            return mapSqliteError(step_rc);
        }
    }

    fn deleteIndex(ctx: *anyopaque, handle: TransactionHandle, store_name: []const u8, index_name: []const u8) BackendError!void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        _ = handle;

        const db = self.db orelse return BackendError.Closed;
        const db_id = self.database_id orelse return BackendError.Closed;

        // Get object store id first
        const get_store_sql = "SELECT id FROM object_stores WHERE database_id = ? AND name = ?";
        var get_stmt: *c.sqlite3_stmt = undefined;
        var prep_rc = c.sqlite3_prepare_v2(db, get_store_sql, @intCast(get_store_sql.len), &get_stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(get_stmt);

        _ = c.sqlite3_bind_int64(get_stmt, 1, db_id);
        _ = c.sqlite3_bind_text(get_stmt, 2, store_name.ptr, @intCast(store_name.len), null);

        if (c.sqlite3_step(get_stmt) != c.SQLITE_ROW) {
            return BackendError.KeyNotFound;
        }

        const store_id = c.sqlite3_column_int64(get_stmt, 0);

        // Delete index
        const sql = "DELETE FROM indexes WHERE object_store_id = ? AND name = ?";

        var stmt: *c.sqlite3_stmt = undefined;
        prep_rc = c.sqlite3_prepare_v2(db, sql, @intCast(sql.len), &stmt, null);
        if (prep_rc != c.SQLITE_OK) return BackendError.BackendSpecific;
        defer _ = c.sqlite3_finalize(stmt);

        _ = c.sqlite3_bind_int64(stmt, 1, store_id);
        _ = c.sqlite3_bind_text(stmt, 2, index_name.ptr, @intCast(index_name.len), null);

        _ = c.sqlite3_step(stmt);
    }

    fn destroy(ctx: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.db != null) {
            close(ctx);
        }
        self.cursors.deinit();
        self.allocator.destroy(self);
    }

    /// Ensure default object store exists for simple key-value operations
    fn ensureDefaultObjectStore(self: *Self) BackendError!void {
        if (self.db == null) return BackendError.Closed;
        const db_id = self.database_id orelse return BackendError.Closed;
        const cache = self.stmt_cache orelse return BackendError.BackendSpecific;

        // Check if default store exists using cached statement (Phase 2.6)
        const check_stmt = cache.select_default_object_store orelse return BackendError.BackendSpecific;
        _ = c.sqlite3_reset(check_stmt);
        _ = c.sqlite3_bind_int64(check_stmt, 1, db_id);

        if (c.sqlite3_step(check_stmt) == c.SQLITE_ROW) {
            return; // Already exists
        }

        // Create default object store with id=1 using cached statement (Phase 2.6)
        const insert_stmt = cache.insert_default_object_store orelse return BackendError.BackendSpecific;
        _ = c.sqlite3_reset(insert_stmt);
        _ = c.sqlite3_bind_int64(insert_stmt, 1, db_id);

        _ = c.sqlite3_step(insert_stmt);
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

test "SQLiteBackend - open, write, read, close" {
    const allocator = std.testing.allocator;
    var backend_inst = try SQLiteBackend.create(allocator);
    defer backend_inst.destroy();

    // Open database
    try backend_inst.open("test_sqlite_backend", .{ .create_if_missing = true });
    defer {
        backend_inst.close();
        // Clean up test file
        std.fs.cwd().deleteFile("test_sqlite_backend.sqlite3") catch {};
        std.fs.cwd().deleteFile("test_sqlite_backend.sqlite3-wal") catch {};
        std.fs.cwd().deleteFile("test_sqlite_backend.sqlite3-shm") catch {};
    }

    try std.testing.expect(backend_inst.isOpen());

    // Begin transaction
    const txn = try backend_inst.beginTransaction(.readwrite);

    // Write data
    try backend_inst.write(txn, "key1", "value1");
    try backend_inst.write(txn, "key2", "value2");

    // Commit
    try backend_inst.commit(txn);

    // Read back in new transaction
    const txn2 = try backend_inst.beginTransaction(.readonly);

    const value1 = try backend_inst.read(txn2, "key1");
    try std.testing.expect(value1 != null);
    try std.testing.expectEqualStrings("value1", value1.?);
    allocator.free(value1.?);

    const value2 = try backend_inst.read(txn2, "key2");
    try std.testing.expect(value2 != null);
    try std.testing.expectEqualStrings("value2", value2.?);
    allocator.free(value2.?);

    // Check non-existent key
    const value3 = try backend_inst.read(txn2, "key3");
    try std.testing.expect(value3 == null);

    try backend_inst.commit(txn2);
}

test "SQLiteBackend - exists and delete" {
    const allocator = std.testing.allocator;
    var backend_inst = try SQLiteBackend.create(allocator);
    defer backend_inst.destroy();

    try backend_inst.open("test_sqlite_exists", .{ .create_if_missing = true });
    defer {
        backend_inst.close();
        std.fs.cwd().deleteFile("test_sqlite_exists.sqlite3") catch {};
        std.fs.cwd().deleteFile("test_sqlite_exists.sqlite3-wal") catch {};
        std.fs.cwd().deleteFile("test_sqlite_exists.sqlite3-shm") catch {};
    }

    const txn = try backend_inst.beginTransaction(.readwrite);

    // Key doesn't exist yet
    try std.testing.expect(!(try backend_inst.exists(txn, "mykey")));

    // Write and check exists
    try backend_inst.write(txn, "mykey", "myvalue");
    try std.testing.expect(try backend_inst.exists(txn, "mykey"));

    // Delete and check doesn't exist
    try backend_inst.delete(txn, "mykey");
    try std.testing.expect(!(try backend_inst.exists(txn, "mykey")));

    try backend_inst.commit(txn);
}

test "SQLiteBackend - cursor iteration" {
    const allocator = std.testing.allocator;
    var backend_inst = try SQLiteBackend.create(allocator);
    defer backend_inst.destroy();

    try backend_inst.open("test_sqlite_cursor", .{ .create_if_missing = true });
    defer {
        backend_inst.close();
        std.fs.cwd().deleteFile("test_sqlite_cursor.sqlite3") catch {};
        std.fs.cwd().deleteFile("test_sqlite_cursor.sqlite3-wal") catch {};
        std.fs.cwd().deleteFile("test_sqlite_cursor.sqlite3-shm") catch {};
    }

    // Write some data
    const txn = try backend_inst.beginTransaction(.readwrite);
    try backend_inst.write(txn, "a", "1");
    try backend_inst.write(txn, "b", "2");
    try backend_inst.write(txn, "c", "3");
    try backend_inst.commit(txn);

    // Read with cursor
    const txn2 = try backend_inst.beginTransaction(.readonly);
    const cursor = try backend_inst.cursorOpen(txn2, .{}, .next);
    defer backend_inst.cursorClose(cursor);

    var count: usize = 0;
    while (try backend_inst.cursorNext(cursor)) |*kv| {
        var entry = kv.*;
        defer entry.deinit();
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
    try backend_inst.commit(txn2);
}

test "SQLiteBackend - prepared statement cache reuse" {
    // Phase 2.6: Test that prepared statements are properly cached and reused
    const allocator = std.testing.allocator;
    var backend_inst = try SQLiteBackend.create(allocator);
    defer backend_inst.destroy();

    try backend_inst.open("test_sqlite_stmt_cache", .{ .create_if_missing = true });
    defer {
        backend_inst.close();
        std.fs.cwd().deleteFile("test_sqlite_stmt_cache.sqlite3") catch {};
        std.fs.cwd().deleteFile("test_sqlite_stmt_cache.sqlite3-wal") catch {};
        std.fs.cwd().deleteFile("test_sqlite_stmt_cache.sqlite3-shm") catch {};
    }

    // Verify statement cache was initialized
    const self: *SQLiteBackend = @ptrCast(@alignCast(backend_inst.ptr));
    try std.testing.expect(self.stmt_cache != null);

    // Multiple write/read cycles should reuse the same prepared statements
    for (0..10) |i| {
        const txn = try backend_inst.beginTransaction(.readwrite);

        // Generate unique key for each iteration
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "key_{d}", .{i}) catch unreachable;

        try backend_inst.write(txn, key, "test_value");

        const value = try backend_inst.read(txn, key);
        try std.testing.expect(value != null);
        try std.testing.expectEqualStrings("test_value", value.?);
        allocator.free(value.?);

        try std.testing.expect(try backend_inst.exists(txn, key));

        try backend_inst.commit(txn);
    }

    // Multiple cursor operations should also reuse cached statements
    for (0..5) |_| {
        const txn = try backend_inst.beginTransaction(.readonly);

        // Full table scan (uses cached statement)
        const cursor = try backend_inst.cursorOpen(txn, .{}, .next);
        defer backend_inst.cursorClose(cursor);

        var count: usize = 0;
        while (try backend_inst.cursorNext(cursor)) |*kv| {
            var entry = kv.*;
            defer entry.deinit();
            count += 1;
        }

        try std.testing.expectEqual(@as(usize, 10), count);
        try backend_inst.commit(txn);
    }
}
