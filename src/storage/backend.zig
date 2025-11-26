//! Storage Backend Interface
//!
//! This module defines the unified storage backend abstraction that supports
//! SQLite, LevelDB, and Memory backends for IndexedDB and Storage Standard implementations.
//!
//! ## Design Principles
//!
//! 1. **Platform Agnostic**: Interface doesn't expose backend-specific details
//! 2. **Transaction-Based**: All operations occur within transactions
//! 3. **Async-Ready**: Interface designed for event loop integration
//! 4. **Memory Ownership**: Clear rules about who owns allocated memory
//!
//! ## Backend Implementations
//!
//! - **SQLite**: Default for iOS/Android (system-provided, zero cost)
//! - **LevelDB**: Default for desktop (best performance)
//! - **Memory**: For testing and ephemeral storage
//!
//! ## Usage Example
//!
//! ```zig
//! const backend: StorageBackend = getBackend(); // From runtime context
//!
//! // Open database
//! try backend.open("mydb", .{ .create_if_missing = true });
//! defer backend.close();
//!
//! // Start transaction
//! const txn = try backend.beginTransaction(.readwrite);
//! errdefer backend.rollback(txn);
//!
//! // Write data
//! try backend.write(txn, "key1", "value1");
//!
//! // Commit
//! try backend.commit(txn);
//! ```
//!
//! ## Specification References
//!
//! - WHATWG Storage Standard: https://storage.spec.whatwg.org/
//! - W3C IndexedDB 3.0: https://w3c.github.io/IndexedDB/
//!
//! ## TODO(Storage Backend)
//!
//! - Implement SQLite backend
//! - Implement LevelDB backend
//! - Implement Memory backend
//! - Add quota management
//! - Add encryption support
//!

const std = @import("std");

// ============================================================================
// Error Types
// ============================================================================

/// Storage backend errors
///
/// These map to IndexedDB DOMException types where applicable.
pub const BackendError = error{
    /// Database not found and create_if_missing is false
    NotFound,

    /// Database already exists and fail_if_exists is true
    AlreadyExists,

    /// Database is locked by another process/thread
    Locked,

    /// Transaction conflict (e.g., write conflict in concurrent transactions)
    Conflict,

    /// Key not found in store
    KeyNotFound,

    /// Constraint violation (e.g., unique key already exists)
    ConstraintViolation,

    /// Data corruption detected
    Corruption,

    /// I/O error (disk full, permissions, etc.)
    IoError,

    /// Transaction has been invalidated (e.g., due to timeout)
    InvalidTransaction,

    /// Cursor has been invalidated
    InvalidCursor,

    /// Operation not permitted in current state
    InvalidState,

    /// Quota exceeded (storage limit reached)
    QuotaExceeded,

    /// Version mismatch (upgrade needed)
    VersionMismatch,

    /// Backend-specific error (check backend_error_code)
    BackendSpecific,

    /// Memory allocation failed
    OutOfMemory,

    /// Operation timed out
    Timeout,

    /// Backend is closed
    Closed,
};

// ============================================================================
// Handle Types
// ============================================================================

/// Opaque handle for a transaction
///
/// Transactions must be committed or rolled back. Uncommitted transactions
/// are automatically rolled back on deinit.
pub const TransactionHandle = struct {
    id: u64,
    mode: TransactionMode,
    _reserved: [6]u8 = undefined, // Padding for future use
};

/// Opaque handle for a cursor
///
/// Cursors iterate over key-value pairs in a range.
/// Must be closed when done to release resources.
pub const CursorHandle = struct {
    id: u64,
    transaction_id: u64, // Parent transaction
    _reserved: [8]u8 = undefined,
};

// ============================================================================
// Configuration Types
// ============================================================================

/// Transaction mode
pub const TransactionMode = enum(u8) {
    /// Read-only transaction (can run concurrently with other readers)
    readonly = 0,

    /// Read-write transaction (exclusive access)
    readwrite = 1,

    /// Version change transaction (for schema upgrades)
    versionchange = 2,
};

/// Options for opening a database
pub const OpenOptions = struct {
    /// Create the database if it doesn't exist
    create_if_missing: bool = true,

    /// Fail if database already exists
    fail_if_exists: bool = false,

    /// Enable write-ahead logging (better concurrency, requires more disk space)
    enable_wal: bool = true,

    /// Maximum size in bytes (0 = unlimited)
    max_size: u64 = 0,

    /// Expected database version (for upgrade detection)
    expected_version: ?u64 = null,

    /// Custom data path override (null = use backend default)
    data_path_override: ?[]const u8 = null,
};

/// Key range for cursor iteration
///
/// Supports all IndexedDB key range patterns:
/// - IDBKeyRange.only(key)
/// - IDBKeyRange.lowerBound(key, open?)
/// - IDBKeyRange.upperBound(key, open?)
/// - IDBKeyRange.bound(lower, upper, lowerOpen?, upperOpen?)
pub const KeyRange = struct {
    /// Lower bound (null = unbounded)
    lower: ?[]const u8 = null,

    /// Upper bound (null = unbounded)
    upper: ?[]const u8 = null,

    /// Exclude lower bound from range
    lower_open: bool = false,

    /// Exclude upper bound from range
    upper_open: bool = false,

    /// Create a range matching exactly one key
    pub fn only(key: []const u8) KeyRange {
        return .{
            .lower = key,
            .upper = key,
            .lower_open = false,
            .upper_open = false,
        };
    }

    /// Create a range with only a lower bound
    pub fn lowerBound(key: []const u8, open: bool) KeyRange {
        return .{
            .lower = key,
            .lower_open = open,
        };
    }

    /// Create a range with only an upper bound
    pub fn upperBound(key: []const u8, open: bool) KeyRange {
        return .{
            .upper = key,
            .upper_open = open,
        };
    }

    /// Create a range with both bounds
    pub fn bound(lower: []const u8, upper: []const u8, lower_open: bool, upper_open: bool) KeyRange {
        return .{
            .lower = lower,
            .upper = upper,
            .lower_open = lower_open,
            .upper_open = upper_open,
        };
    }

    /// Check if this range is unbounded (matches all keys)
    pub fn isUnbounded(self: KeyRange) bool {
        return self.lower == null and self.upper == null;
    }
};

/// Cursor direction
pub const CursorDirection = enum(u8) {
    /// Iterate forward (ascending key order)
    next = 0,

    /// Iterate forward, skip duplicates (for indexes with non-unique keys)
    nextunique = 1,

    /// Iterate backward (descending key order)
    prev = 2,

    /// Iterate backward, skip duplicates
    prevunique = 3,
};

// ============================================================================
// Result Types
// ============================================================================

/// Key-value pair returned by cursor
pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,

    /// The allocator used to allocate key and value
    /// Caller must free both key and value when done
    allocator: std.mem.Allocator,

    pub fn deinit(self: *KeyValue) void {
        self.allocator.free(self.key);
        self.allocator.free(self.value);
    }
};

/// Backend statistics
pub const BackendStats = struct {
    /// Total size of database on disk (bytes)
    disk_size: u64 = 0,

    /// Estimated number of keys
    key_count: u64 = 0,

    /// Number of active transactions
    active_transactions: u32 = 0,

    /// Number of open cursors
    open_cursors: u32 = 0,

    /// Backend-specific stats (JSON or null)
    extra_json: ?[]const u8 = null,
};

/// Database metadata
pub const DatabaseInfo = struct {
    /// Database name
    name: []const u8,

    /// Current version
    version: u64,

    /// List of object store names
    object_stores: []const []const u8,

    /// Creation timestamp (Unix milliseconds)
    created_at: i64,

    /// Last modified timestamp (Unix milliseconds)
    modified_at: i64,
};

// ============================================================================
// Storage Backend Interface
// ============================================================================

/// Unified storage backend interface
///
/// This vtable-based interface allows runtime backend selection while maintaining
/// type safety and performance. All backends (SQLite, LevelDB, Memory) implement
/// this interface.
///
/// ## Threading Model
///
/// - Read-only transactions can run concurrently
/// - Read-write transactions are serialized
/// - All operations on a transaction must be from the same thread
/// - Backends may use internal locking for thread safety
///
/// ## Memory Ownership
///
/// - **Input data**: Backend copies data; caller retains ownership
/// - **Output data**: Allocated by backend; caller must free using provided allocator
/// - **Handles**: Managed by backend; caller must close/commit/rollback
///
/// ## Error Handling
///
/// All operations return `BackendError` for storage-specific errors.
/// Use `errdefer` for cleanup patterns.
///
pub const StorageBackend = struct {
    /// Opaque pointer to backend implementation
    ptr: *anyopaque,

    /// Virtual function table
    vtable: *const VTable,

    /// Allocator for result data
    allocator: std.mem.Allocator,

    /// Virtual function table for backend operations
    pub const VTable = struct {
        // ====================================================================
        // Lifecycle
        // ====================================================================

        /// Open a database
        ///
        /// Opens or creates a database at the specified path.
        /// Backend-specific path handling:
        /// - SQLite: Creates .sqlite file at path
        /// - LevelDB: Creates directory at path
        /// - Memory: Path is used as key in global map
        ///
        /// Returns: void on success, BackendError on failure
        open: *const fn (ctx: *anyopaque, name: []const u8, options: OpenOptions) BackendError!void,

        /// Close the database
        ///
        /// Commits pending transactions and releases resources.
        /// After close(), the backend cannot be used until open() is called again.
        close: *const fn (ctx: *anyopaque) void,

        /// Check if database is open
        is_open: *const fn (ctx: *anyopaque) bool,

        // ====================================================================
        // Transactions
        // ====================================================================

        /// Begin a new transaction
        ///
        /// - `readonly`: Multiple concurrent readers allowed
        /// - `readwrite`: Exclusive access, blocks other writers
        /// - `versionchange`: Exclusive access for schema changes
        ///
        /// Returns: TransactionHandle on success
        begin_transaction: *const fn (ctx: *anyopaque, mode: TransactionMode) BackendError!TransactionHandle,

        /// Commit a transaction
        ///
        /// Atomically applies all writes in the transaction.
        /// Transaction handle is invalidated after commit.
        commit: *const fn (ctx: *anyopaque, handle: TransactionHandle) BackendError!void,

        /// Rollback a transaction
        ///
        /// Discards all writes in the transaction.
        /// Transaction handle is invalidated after rollback.
        rollback: *const fn (ctx: *anyopaque, handle: TransactionHandle) void,

        // ====================================================================
        // CRUD Operations
        // ====================================================================

        /// Read a value by key
        ///
        /// Returns: Allocated copy of value (caller must free), or null if not found
        /// Note: Returns null for non-existent keys; use get_or_error for strict semantics
        read: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8,

        /// Write a key-value pair
        ///
        /// Overwrites existing value if key exists.
        /// Data is copied; caller retains ownership of input.
        write: *const fn (ctx: *anyopaque, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void,

        /// Delete a key-value pair
        ///
        /// No error if key doesn't exist.
        delete: *const fn (ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!void,

        /// Check if a key exists
        ///
        /// More efficient than read() when you don't need the value.
        exists: *const fn (ctx: *anyopaque, handle: TransactionHandle, key: []const u8) BackendError!bool,

        // ====================================================================
        // Cursor Operations
        // ====================================================================

        /// Open a cursor for range iteration
        ///
        /// Cursor iterates over keys in the specified range.
        /// Must be closed when done.
        cursor_open: *const fn (
            ctx: *anyopaque,
            handle: TransactionHandle,
            range: KeyRange,
            direction: CursorDirection,
        ) BackendError!CursorHandle,

        /// Advance cursor and get next key-value pair
        ///
        /// Returns: KeyValue (caller must call deinit), or null at end
        cursor_next: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, cursor: CursorHandle) BackendError!?KeyValue,

        /// Close a cursor
        ///
        /// Releases cursor resources. Cursor handle is invalidated.
        cursor_close: *const fn (ctx: *anyopaque, cursor: CursorHandle) void,

        // ====================================================================
        // Metadata
        // ====================================================================

        /// Estimate total storage size
        ///
        /// Returns approximate size in bytes. May not be exact.
        estimate_size: *const fn (ctx: *anyopaque) BackendError!u64,

        /// Get backend statistics
        ///
        /// Returns various metrics about the database.
        get_stats: *const fn (ctx: *anyopaque) BackendError!BackendStats,

        /// Get database info (name, version, object stores)
        get_info: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator) BackendError!DatabaseInfo,

        // ====================================================================
        // Schema Operations (for IndexedDB)
        // ====================================================================

        /// Create an object store
        ///
        /// Only valid in versionchange transaction.
        create_object_store: *const fn (
            ctx: *anyopaque,
            handle: TransactionHandle,
            name: []const u8,
            options: ObjectStoreOptions,
        ) BackendError!void,

        /// Delete an object store
        ///
        /// Only valid in versionchange transaction.
        delete_object_store: *const fn (
            ctx: *anyopaque,
            handle: TransactionHandle,
            name: []const u8,
        ) BackendError!void,

        /// Create an index on an object store
        ///
        /// Only valid in versionchange transaction.
        create_index: *const fn (
            ctx: *anyopaque,
            handle: TransactionHandle,
            store_name: []const u8,
            index_name: []const u8,
            key_path: []const u8,
            options: IndexOptions,
        ) BackendError!void,

        /// Delete an index
        ///
        /// Only valid in versionchange transaction.
        delete_index: *const fn (
            ctx: *anyopaque,
            handle: TransactionHandle,
            store_name: []const u8,
            index_name: []const u8,
        ) BackendError!void,

        // ====================================================================
        // Cleanup
        // ====================================================================

        /// Destroy backend and free all resources
        destroy: *const fn (ctx: *anyopaque) void,
    };

    // ========================================================================
    // Convenience Methods (delegate to vtable)
    // ========================================================================

    pub fn open(self: StorageBackend, name: []const u8, options: OpenOptions) BackendError!void {
        return self.vtable.open(self.ptr, name, options);
    }

    pub fn close(self: StorageBackend) void {
        return self.vtable.close(self.ptr);
    }

    pub fn isOpen(self: StorageBackend) bool {
        return self.vtable.is_open(self.ptr);
    }

    pub fn beginTransaction(self: StorageBackend, mode: TransactionMode) BackendError!TransactionHandle {
        return self.vtable.begin_transaction(self.ptr, mode);
    }

    pub fn commit(self: StorageBackend, handle: TransactionHandle) BackendError!void {
        return self.vtable.commit(self.ptr, handle);
    }

    pub fn rollback(self: StorageBackend, handle: TransactionHandle) void {
        return self.vtable.rollback(self.ptr, handle);
    }

    pub fn read(self: StorageBackend, handle: TransactionHandle, key: []const u8) BackendError!?[]const u8 {
        return self.vtable.read(self.ptr, self.allocator, handle, key);
    }

    pub fn write(self: StorageBackend, handle: TransactionHandle, key: []const u8, value: []const u8) BackendError!void {
        return self.vtable.write(self.ptr, handle, key, value);
    }

    pub fn delete(self: StorageBackend, handle: TransactionHandle, key: []const u8) BackendError!void {
        return self.vtable.delete(self.ptr, handle, key);
    }

    pub fn exists(self: StorageBackend, handle: TransactionHandle, key: []const u8) BackendError!bool {
        return self.vtable.exists(self.ptr, handle, key);
    }

    pub fn cursorOpen(self: StorageBackend, handle: TransactionHandle, range: KeyRange, direction: CursorDirection) BackendError!CursorHandle {
        return self.vtable.cursor_open(self.ptr, handle, range, direction);
    }

    pub fn cursorNext(self: StorageBackend, cursor: CursorHandle) BackendError!?KeyValue {
        return self.vtable.cursor_next(self.ptr, self.allocator, cursor);
    }

    pub fn cursorClose(self: StorageBackend, cursor: CursorHandle) void {
        return self.vtable.cursor_close(self.ptr, cursor);
    }

    pub fn estimateSize(self: StorageBackend) BackendError!u64 {
        return self.vtable.estimate_size(self.ptr);
    }

    pub fn getStats(self: StorageBackend) BackendError!BackendStats {
        return self.vtable.get_stats(self.ptr);
    }

    pub fn getInfo(self: StorageBackend) BackendError!DatabaseInfo {
        return self.vtable.get_info(self.ptr, self.allocator);
    }

    pub fn createObjectStore(self: StorageBackend, handle: TransactionHandle, name: []const u8, options: ObjectStoreOptions) BackendError!void {
        return self.vtable.create_object_store(self.ptr, handle, name, options);
    }

    pub fn deleteObjectStore(self: StorageBackend, handle: TransactionHandle, name: []const u8) BackendError!void {
        return self.vtable.delete_object_store(self.ptr, handle, name);
    }

    pub fn createIndex(self: StorageBackend, handle: TransactionHandle, store_name: []const u8, index_name: []const u8, key_path: []const u8, options: IndexOptions) BackendError!void {
        return self.vtable.create_index(self.ptr, handle, store_name, index_name, key_path, options);
    }

    pub fn deleteIndex(self: StorageBackend, handle: TransactionHandle, store_name: []const u8, index_name: []const u8) BackendError!void {
        return self.vtable.delete_index(self.ptr, handle, store_name, index_name);
    }

    pub fn destroy(self: StorageBackend) void {
        return self.vtable.destroy(self.ptr);
    }
};

// ============================================================================
// IndexedDB Schema Types
// ============================================================================

/// Options for creating an object store
pub const ObjectStoreOptions = struct {
    /// Key path for inline keys (null = out-of-line keys)
    key_path: ?[]const u8 = null,

    /// Auto-generate keys
    auto_increment: bool = false,
};

/// Options for creating an index
pub const IndexOptions = struct {
    /// Index keys must be unique
    unique: bool = false,

    /// If key path evaluates to array, index each element
    multi_entry: bool = false,
};

// ============================================================================
// Backend Factory
// ============================================================================

/// Backend type selector
pub const BackendType = enum {
    /// SQLite backend (best for iOS/Android, ACID, widely compatible)
    sqlite,

    /// LevelDB backend (best for desktop, fastest for simple key-value)
    leveldb,

    /// In-memory backend (for testing, no persistence)
    memory,
};

/// Create a storage backend of the specified type
///
/// Usage:
/// ```zig
/// const backend = try createBackend(allocator, .sqlite);
/// defer backend.destroy();
/// ```
pub fn createBackend(allocator: std.mem.Allocator, backend_type: BackendType) BackendError!StorageBackend {
    _ = allocator;
    return switch (backend_type) {
        .sqlite => {
            // TODO(SQLite Backend): Implement SQLite backend
            // return sqlite.createBackend(allocator);
            return BackendError.BackendSpecific;
        },
        .leveldb => {
            // TODO(LevelDB Backend): Implement LevelDB backend
            // return leveldb.createBackend(allocator);
            return BackendError.BackendSpecific;
        },
        .memory => {
            // TODO(Memory Backend): Implement Memory backend
            // return memory.createBackend(allocator);
            return BackendError.BackendSpecific;
        },
    };
}

// ============================================================================
// Tests
// ============================================================================

test "KeyRange.only" {
    const range = KeyRange.only("test");
    try std.testing.expectEqualStrings("test", range.lower.?);
    try std.testing.expectEqualStrings("test", range.upper.?);
    try std.testing.expect(!range.lower_open);
    try std.testing.expect(!range.upper_open);
}

test "KeyRange.lowerBound" {
    const range = KeyRange.lowerBound("start", true);
    try std.testing.expectEqualStrings("start", range.lower.?);
    try std.testing.expect(range.upper == null);
    try std.testing.expect(range.lower_open);
}

test "KeyRange.upperBound" {
    const range = KeyRange.upperBound("end", false);
    try std.testing.expect(range.lower == null);
    try std.testing.expectEqualStrings("end", range.upper.?);
    try std.testing.expect(!range.upper_open);
}

test "KeyRange.bound" {
    const range = KeyRange.bound("a", "z", false, true);
    try std.testing.expectEqualStrings("a", range.lower.?);
    try std.testing.expectEqualStrings("z", range.upper.?);
    try std.testing.expect(!range.lower_open);
    try std.testing.expect(range.upper_open);
}

test "KeyRange.isUnbounded" {
    const unbounded = KeyRange{};
    try std.testing.expect(unbounded.isUnbounded());

    const bounded = KeyRange.only("test");
    try std.testing.expect(!bounded.isUnbounded());
}
