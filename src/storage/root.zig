//! Storage Module
//!
//! Implements storage backends for IndexedDB and the Storage Standard.
//!
//! ## Architecture
//!
//! ```
//! StorageBackend (interface)
//!     ├── MemoryBackend (testing)
//!     ├── SQLiteBackend (iOS/Android, planned)
//!     └── LevelDBBackend (desktop, planned)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const storage = @import("storage");
//!
//! // Create memory backend for testing
//! const backend = try storage.backends.MemoryBackend.create(allocator);
//! defer backend.destroy();
//!
//! // Open database
//! try backend.open("mydb", .{});
//! defer backend.close();
//!
//! // Use transactions
//! const txn = try backend.beginTransaction(.readwrite);
//! try backend.write(txn, "key", "value");
//! try backend.commit(txn);
//! ```
//!
//! ## Specification References
//!
//! - WHATWG Storage Standard: https://storage.spec.whatwg.org/
//! - W3C IndexedDB 3.0: https://w3c.github.io/IndexedDB/

// Re-export backend interface
const backend_mod = @import("backend.zig");
pub const StorageBackend = backend_mod.StorageBackend;
pub const BackendError = backend_mod.BackendError;
pub const BackendType = backend_mod.BackendType;
pub const TransactionHandle = backend_mod.TransactionHandle;
pub const TransactionMode = backend_mod.TransactionMode;
pub const CursorHandle = backend_mod.CursorHandle;
pub const CursorDirection = backend_mod.CursorDirection;
pub const KeyRange = backend_mod.KeyRange;
pub const KeyValue = backend_mod.KeyValue;
pub const BackendStats = backend_mod.BackendStats;
pub const DatabaseInfo = backend_mod.DatabaseInfo;
pub const OpenOptions = backend_mod.OpenOptions;
pub const ObjectStoreOptions = backend_mod.ObjectStoreOptions;
pub const IndexOptions = backend_mod.IndexOptions;
pub const createBackend = backend_mod.createBackend;

// Backend selection and configuration
pub const Platform = backend_mod.Platform;
pub const BackendConfig = backend_mod.BackendConfig;
pub const createBackendWithConfig = backend_mod.createBackendWithConfig;
pub const getDefaultBackendType = backend_mod.getDefaultBackendType;
pub const isBackendAvailable = backend_mod.isBackendAvailable;

// Backend implementations
pub const backends = @import("backends/root.zig");

test {
    _ = @import("backend.zig");
    _ = backends;
}
