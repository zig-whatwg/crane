//! Storage Backends: the legacy StorageBackend interface's one
//! implementation, the in-memory MemoryBackend.
//!
//! Every store a Browser keeps - IndexedDB, localStorage, cookies, the HTTP
//! cache, Cache Storage - goes through the platform protocol's storage
//! engine (docs/platform-protocol.md 6.6): kit/memory_store with no profile
//! directory, kit/sqlite with one (the user's ruling D6, 2026-11-21). The
//! SQLite and LevelDB backends that sat here, linked by build.zig's
//! configureStorageBackends, were retired with it (lane prof1, D6 step 6).

pub const memory = @import("memory.zig");
pub const MemoryBackend = memory.MemoryBackend;

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
}
