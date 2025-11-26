//! Storage Backends
//!
//! This module provides various storage backend implementations for IndexedDB
//! and the Storage Standard.
//!
//! ## Available Backends
//!
//! - **Memory**: In-memory storage for testing (no persistence)
//! - **SQLite**: SQLite-based storage (planned)
//! - **LevelDB**: LevelDB-based storage (planned)
//!
//! ## Usage
//!
//! ```zig
//! const backends = @import("backends");
//! const backend = try backends.memory.MemoryBackend.create(allocator);
//! defer backend.destroy();
//! ```

pub const memory = @import("memory.zig");
pub const MemoryBackend = memory.MemoryBackend;

pub const sqlite = @import("sqlite.zig");
pub const SQLiteBackend = sqlite.SQLiteBackend;
pub const IDBKeyEncoder = sqlite.IDBKeyEncoder;
pub const IDBKeyType = sqlite.IDBKeyType;
pub const Schema = sqlite.Schema;
pub const Statements = sqlite.Statements;

pub const leveldb = @import("leveldb.zig");
pub const LevelDBBackend = leveldb.LevelDBBackend;
pub const LevelDBKeyEncoder = leveldb.LevelDBKeyEncoder;
pub const KeyPrefix = leveldb.KeyPrefix;

// Re-export parent types for convenience
const parent = @import("../backend.zig");
pub const StorageBackend = parent.StorageBackend;
pub const BackendError = parent.BackendError;
pub const BackendType = parent.BackendType;
pub const TransactionHandle = parent.TransactionHandle;
pub const TransactionMode = parent.TransactionMode;
pub const CursorHandle = parent.CursorHandle;
pub const CursorDirection = parent.CursorDirection;
pub const KeyRange = parent.KeyRange;
pub const KeyValue = parent.KeyValue;
pub const BackendStats = parent.BackendStats;
pub const DatabaseInfo = parent.DatabaseInfo;
pub const OpenOptions = parent.OpenOptions;
pub const ObjectStoreOptions = parent.ObjectStoreOptions;
pub const IndexOptions = parent.IndexOptions;

test {
    _ = memory;
    _ = sqlite;
    _ = leveldb;
}
