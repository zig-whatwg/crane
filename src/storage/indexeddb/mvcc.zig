//! MVCC (Multi-Version Concurrency Control) for IndexedDB
//!
//! Implements MVCC semantics for IndexedDB readonly transactions using
//! SQLite's snapshot isolation capabilities. This allows multiple readonly
//! transactions to see a consistent view of the database even while
//! write transactions are making changes.
//!
//! ## SQLite Snapshot Isolation
//!
//! SQLite WAL mode provides snapshot isolation:
//! - Readers see a consistent snapshot from when the transaction started
//! - Writers don't block readers (concurrent reads)
//! - Readers don't block writers (concurrent writes)
//!
//! ## Implementation Strategy
//!
//! For readonly transactions:
//! 1. Start with `BEGIN DEFERRED` (no locks until first read)
//! 2. First read creates a snapshot of current database state
//! 3. All subsequent reads see the same snapshot
//! 4. Transaction ends with `COMMIT` (releases snapshot)
//!
//! For readwrite/versionchange:
//! 1. Use `BEGIN IMMEDIATE` or `BEGIN EXCLUSIVE`
//! 2. Standard write semantics (no MVCC needed)
//!
//! ## Spec Reference
//!
//! W3C IndexedDB 3.0 requires:
//! - "A readonly transaction must never block other transactions"
//! - "Multiple readonly transactions can be active simultaneously"
//!
//! ## References
//!
//! - SQLite WAL: https://sqlite.org/wal.html
//! - SQLite Isolation: https://sqlite.org/isolation.html

const std = @import("std");
const backend = @import("../backend.zig");
const TransactionMode = backend.TransactionMode;

// ============================================================================
// Snapshot Types
// ============================================================================

/// Snapshot identifier
pub const SnapshotId = u64;

/// Snapshot state for a readonly transaction
pub const Snapshot = struct {
    /// Unique snapshot ID
    id: SnapshotId,
    /// Transaction that owns this snapshot
    transaction_id: u64,
    /// When the snapshot was created
    created_at: i64,
    /// Whether the first read has occurred (snapshot is active)
    is_active: bool,
    /// Reference count (for shared snapshots)
    ref_count: u32,

    const Self = @This();

    pub fn init(id: SnapshotId, transaction_id: u64) Self {
        return Self{
            .id = id,
            .transaction_id = transaction_id,
            .created_at = std.time.milliTimestamp(),
            .is_active = false,
            .ref_count = 1,
        };
    }

    /// Mark snapshot as active (first read occurred)
    pub fn activate(self: *Self) void {
        self.is_active = true;
    }

    /// Increment reference count
    pub fn addRef(self: *Self) void {
        self.ref_count += 1;
    }

    /// Decrement reference count, return true if should be freed
    pub fn release(self: *Self) bool {
        if (self.ref_count > 0) {
            self.ref_count -= 1;
        }
        return self.ref_count == 0;
    }

    /// Get age in milliseconds
    pub fn ageMs(self: Self) i64 {
        return std.time.milliTimestamp() - self.created_at;
    }
};

// ============================================================================
// Version Info
// ============================================================================

/// Version information for a key-value pair
pub const VersionInfo = struct {
    /// Version number (incremented on each write)
    version: u64,
    /// Transaction that created this version
    created_by_txn: u64,
    /// Timestamp of creation
    created_at: i64,
    /// Whether this version is visible to a given snapshot
    pub fn isVisibleTo(self: VersionInfo, snapshot: Snapshot) bool {
        // A version is visible if it was created before the snapshot
        // or by a transaction that started before the snapshot
        return self.created_at <= snapshot.created_at;
    }
};

// ============================================================================
// MVCC Manager
// ============================================================================

/// MVCC manager for IndexedDB
pub const MVCCManager = struct {
    /// Active snapshots by ID
    snapshots: std.AutoHashMap(SnapshotId, Snapshot),
    /// Next snapshot ID
    next_snapshot_id: SnapshotId,
    /// Global version counter
    global_version: u64,
    /// Maximum snapshot age before warning (milliseconds)
    max_snapshot_age_ms: i64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Default max snapshot age: 30 seconds
    pub const DEFAULT_MAX_SNAPSHOT_AGE_MS: i64 = 30_000;

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .snapshots = std.AutoHashMap(SnapshotId, Snapshot).init(allocator),
            .next_snapshot_id = 1,
            .global_version = 0,
            .max_snapshot_age_ms = DEFAULT_MAX_SNAPSHOT_AGE_MS,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.snapshots.deinit();
    }

    /// Create a new snapshot for a readonly transaction
    pub fn createSnapshot(self: *Self, transaction_id: u64) !*Snapshot {
        const snapshot_id = self.next_snapshot_id;
        self.next_snapshot_id += 1;

        const snapshot = Snapshot.init(snapshot_id, transaction_id);
        try self.snapshots.put(snapshot_id, snapshot);

        return self.snapshots.getPtr(snapshot_id).?;
    }

    /// Get an existing snapshot
    pub fn getSnapshot(self: *Self, id: SnapshotId) ?*Snapshot {
        return self.snapshots.getPtr(id);
    }

    /// Release a snapshot
    pub fn releaseSnapshot(self: *Self, id: SnapshotId) void {
        if (self.snapshots.getPtr(id)) |snapshot| {
            if (snapshot.release()) {
                _ = self.snapshots.remove(id);
            }
        }
    }

    /// Get current global version
    pub fn getCurrentVersion(self: Self) u64 {
        return self.global_version;
    }

    /// Increment global version (call after each write)
    pub fn incrementVersion(self: *Self) u64 {
        self.global_version += 1;
        return self.global_version;
    }

    /// Get count of active snapshots
    pub fn activeSnapshotCount(self: Self) usize {
        return self.snapshots.count();
    }

    /// Check for stale snapshots (older than max age)
    pub fn hasStaleSnapshots(self: Self) bool {
        var iter = self.snapshots.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.ageMs() > self.max_snapshot_age_ms) {
                return true;
            }
        }
        return false;
    }

    /// Get oldest snapshot age in milliseconds
    pub fn oldestSnapshotAgeMs(self: Self) ?i64 {
        var oldest: ?i64 = null;
        var iter = self.snapshots.iterator();
        while (iter.next()) |entry| {
            const age = entry.value_ptr.ageMs();
            if (oldest == null or age > oldest.?) {
                oldest = age;
            }
        }
        return oldest;
    }

    /// Clean up stale snapshots (force release)
    pub fn cleanupStaleSnapshots(self: *Self) usize {
        var to_remove = std.ArrayList(SnapshotId).init(self.allocator);
        defer to_remove.deinit();

        var iter = self.snapshots.iterator();
        while (iter.next()) |entry| {
            if (entry.value_ptr.ageMs() > self.max_snapshot_age_ms) {
                to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (to_remove.items) |id| {
            _ = self.snapshots.remove(id);
        }

        return to_remove.items.len;
    }
};

// ============================================================================
// Read Consistency Checker
// ============================================================================

/// Ensures reads within a transaction see consistent data
pub const ReadConsistencyChecker = struct {
    /// Snapshot for this checker
    snapshot: *Snapshot,
    /// Keys read in this transaction (for consistency verification)
    read_keys: std.StringHashMap(u64), // key -> version read
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, snapshot: *Snapshot) Self {
        return Self{
            .snapshot = snapshot,
            .read_keys = std.StringHashMap(u64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        // Free all copied keys
        var iter = self.read_keys.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.read_keys.deinit();
    }

    /// Record a read for consistency tracking
    pub fn recordRead(self: *Self, key: []const u8, version: u64) !void {
        // First read activates the snapshot
        if (!self.snapshot.is_active) {
            self.snapshot.activate();
        }

        // Check if we already read this key
        if (self.read_keys.get(key)) |prev_version| {
            // Must see same version for consistency
            if (prev_version != version) {
                return error.ConsistencyViolation;
            }
        } else {
            // Record new read
            const key_copy = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(key_copy);
            try self.read_keys.put(key_copy, version);
        }
    }

    /// Check if a version is visible to our snapshot
    pub fn isVersionVisible(self: Self, version_info: VersionInfo) bool {
        return version_info.isVisibleTo(self.snapshot.*);
    }

    /// Get count of keys read
    pub fn readCount(self: Self) usize {
        return self.read_keys.count();
    }
};

// ============================================================================
// Concurrent Read Tracker
// ============================================================================

/// Tracks concurrent readonly transactions for debugging/monitoring
pub const ConcurrentReadTracker = struct {
    /// Active readonly transactions
    active_readers: std.AutoHashMap(u64, ReaderInfo),
    /// Peak concurrent readers
    peak_readers: usize,
    /// Total readers started
    total_readers: u64,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    pub const ReaderInfo = struct {
        transaction_id: u64,
        started_at: i64,
        store_names: std.ArrayList([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .active_readers = std.AutoHashMap(u64, ReaderInfo).init(allocator),
            .peak_readers = 0,
            .total_readers = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var iter = self.active_readers.iterator();
        while (iter.next()) |entry| {
            for (entry.value_ptr.store_names.items) |name| {
                self.allocator.free(name);
            }
            entry.value_ptr.store_names.deinit();
        }
        self.active_readers.deinit();
    }

    /// Register a new reader
    pub fn registerReader(self: *Self, transaction_id: u64) !void {
        const info = ReaderInfo{
            .transaction_id = transaction_id,
            .started_at = std.time.milliTimestamp(),
            .store_names = std.ArrayList([]const u8).init(self.allocator),
        };

        try self.active_readers.put(transaction_id, info);

        self.total_readers += 1;
        const current = self.active_readers.count();
        if (current > self.peak_readers) {
            self.peak_readers = current;
        }
    }

    /// Unregister a reader
    pub fn unregisterReader(self: *Self, transaction_id: u64) void {
        if (self.active_readers.fetchRemove(transaction_id)) |kv| {
            for (kv.value.store_names.items) |name| {
                self.allocator.free(name);
            }
            var copy = kv.value;
            copy.store_names.deinit();
        }
    }

    /// Get active reader count
    pub fn activeCount(self: Self) usize {
        return self.active_readers.count();
    }

    /// Get statistics
    pub fn getStats(self: Self) struct { active: usize, peak: usize, total: u64 } {
        return .{
            .active = self.active_readers.count(),
            .peak = self.peak_readers,
            .total = self.total_readers,
        };
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Snapshot - init and lifecycle" {
    var snapshot = Snapshot.init(1, 100);

    try std.testing.expectEqual(@as(SnapshotId, 1), snapshot.id);
    try std.testing.expectEqual(@as(u64, 100), snapshot.transaction_id);
    try std.testing.expect(!snapshot.is_active);

    snapshot.activate();
    try std.testing.expect(snapshot.is_active);
}

test "Snapshot - reference counting" {
    var snapshot = Snapshot.init(1, 100);

    try std.testing.expectEqual(@as(u32, 1), snapshot.ref_count);

    snapshot.addRef();
    try std.testing.expectEqual(@as(u32, 2), snapshot.ref_count);

    try std.testing.expect(!snapshot.release()); // Still has refs
    try std.testing.expectEqual(@as(u32, 1), snapshot.ref_count);

    try std.testing.expect(snapshot.release()); // Should be freed
}

test "VersionInfo - visibility" {
    const snapshot = Snapshot{
        .id = 1,
        .transaction_id = 100,
        .created_at = 1000,
        .is_active = true,
        .ref_count = 1,
    };

    const visible_version = VersionInfo{
        .version = 1,
        .created_by_txn = 50,
        .created_at = 500, // Before snapshot
    };

    const invisible_version = VersionInfo{
        .version = 2,
        .created_by_txn = 150,
        .created_at = 1500, // After snapshot
    };

    try std.testing.expect(visible_version.isVisibleTo(snapshot));
    try std.testing.expect(!invisible_version.isVisibleTo(snapshot));
}

test "MVCCManager - snapshot lifecycle" {
    const allocator = std.testing.allocator;

    var mgr = MVCCManager.init(allocator);
    defer mgr.deinit();

    const snapshot = try mgr.createSnapshot(100);

    try std.testing.expectEqual(@as(usize, 1), mgr.activeSnapshotCount());
    try std.testing.expect(!snapshot.is_active);

    snapshot.activate();
    try std.testing.expect(snapshot.is_active);

    mgr.releaseSnapshot(snapshot.id);
    try std.testing.expectEqual(@as(usize, 0), mgr.activeSnapshotCount());
}

test "MVCCManager - version tracking" {
    const allocator = std.testing.allocator;

    var mgr = MVCCManager.init(allocator);
    defer mgr.deinit();

    try std.testing.expectEqual(@as(u64, 0), mgr.getCurrentVersion());

    const v1 = mgr.incrementVersion();
    try std.testing.expectEqual(@as(u64, 1), v1);

    const v2 = mgr.incrementVersion();
    try std.testing.expectEqual(@as(u64, 2), v2);

    try std.testing.expectEqual(@as(u64, 2), mgr.getCurrentVersion());
}

test "ReadConsistencyChecker - consistency tracking" {
    const allocator = std.testing.allocator;

    var mgr = MVCCManager.init(allocator);
    defer mgr.deinit();

    const snapshot = try mgr.createSnapshot(100);

    var checker = ReadConsistencyChecker.init(allocator, snapshot);
    defer checker.deinit();

    // First read activates snapshot
    try checker.recordRead("key1", 1);
    try std.testing.expect(snapshot.is_active);

    // Same key, same version - OK
    try checker.recordRead("key1", 1);

    // Same key, different version - should fail
    const result = checker.recordRead("key1", 2);
    try std.testing.expectError(error.ConsistencyViolation, result);
}

test "ConcurrentReadTracker - tracking" {
    const allocator = std.testing.allocator;

    var tracker = ConcurrentReadTracker.init(allocator);
    defer tracker.deinit();

    try tracker.registerReader(1);
    try tracker.registerReader(2);

    try std.testing.expectEqual(@as(usize, 2), tracker.activeCount());

    const stats = tracker.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats.active);
    try std.testing.expectEqual(@as(usize, 2), stats.peak);
    try std.testing.expectEqual(@as(u64, 2), stats.total);

    tracker.unregisterReader(1);
    try std.testing.expectEqual(@as(usize, 1), tracker.activeCount());

    // Peak should remain at 2
    const stats2 = tracker.getStats();
    try std.testing.expectEqual(@as(usize, 2), stats2.peak);
}
