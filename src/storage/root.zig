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

// Migration utilities
pub const migration = @import("migration.zig");
pub const MigrationOptions = migration.MigrationOptions;
pub const MigrationStats = migration.MigrationStats;
pub const MigrationProgress = migration.MigrationProgress;
pub const MigrationError = migration.MigrationError;
pub const migrate = migration.migrate;
pub const exportToBuffer = migration.exportToBuffer;
pub const importFromBuffer = migration.importFromBuffer;

// WHATWG Storage Standard (Phase 3)
pub const standard = @import("standard.zig");
pub const StorageShed = standard.StorageShed;
pub const StorageShelf = standard.StorageShelf;
pub const StorageBucket = standard.StorageBucket;
pub const StorageBottle = standard.StorageBottle;
pub const StorageKey = standard.StorageKey;
pub const StorageProxyMap = standard.StorageProxyMap;
pub const StorageType = standard.StorageType;
pub const BucketMode = standard.BucketMode;
pub const StorageIdentifier = standard.StorageIdentifier;
pub const StorageEndpoint = standard.StorageEndpoint;
pub const StorageEstimate = standard.StorageEstimate;
pub const registered_storage_endpoints = standard.registered_storage_endpoints;
pub const getEndpoint = standard.getEndpoint;
pub const obtainStorageKey = standard.obtainStorageKey;
pub const obtainLocalStorageShelf = standard.obtainLocalStorageShelf;
pub const obtainStorageBottleMap = standard.obtainStorageBottleMap;
pub const obtainLocalStorageBottleMap = standard.obtainLocalStorageBottleMap;
pub const obtainSessionStorageBottleMap = standard.obtainSessionStorageBottleMap;
pub const getStorageEstimate = standard.getStorageEstimate;
pub const initGlobalStorageShed = standard.initGlobalStorageShed;
pub const getGlobalStorageShed = standard.getGlobalStorageShed;
pub const deinitGlobalStorageShed = standard.deinitGlobalStorageShed;

// StorageManager interface (Phase 3.10)
pub const storage_manager = @import("storage_manager.zig");
pub const StorageManager = storage_manager.StorageManager;

// Quota management (Phase 3.12)
pub const quota = @import("quota.zig");
pub const QuotaManager = quota.QuotaManager;
pub const QuotaConfig = quota.QuotaConfig;
pub const QuotaCheckResult = quota.QuotaCheckResult;
pub const PressureCallback = quota.PressureCallback;
pub const DEFAULT_ORIGIN_QUOTA = quota.DEFAULT_ORIGIN_QUOTA;
pub const MINIMUM_QUOTA = quota.MINIMUM_QUOTA;
pub const MAXIMUM_ORIGIN_QUOTA = quota.MAXIMUM_ORIGIN_QUOTA;
pub const formatBytes = quota.formatBytes;

test {
    _ = @import("backend.zig");
    _ = backends;
    _ = migration;
    _ = standard;
    _ = storage_manager;
    _ = quota;
}
