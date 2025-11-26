//! Cross-Backend Migration Tool
//!
//! Provides utilities for migrating data between different storage backends
//! (Memory, SQLite, LevelDB) while preserving data integrity.
//!
//! ## Use Cases
//!
//! - **Testing to Production**: Migrate from Memory backend to SQLite/LevelDB
//! - **Backend Upgrade**: Switch from SQLite to LevelDB for performance
//! - **Data Export/Import**: Backup and restore database contents
//! - **Platform Migration**: Move data when changing deployment targets
//!
//! ## Example
//!
//! ```zig
//! const migration = @import("storage").migration;
//!
//! // Migrate from memory to SQLite
//! var source = try storage.createBackend(allocator, .memory);
//! var dest = try storage.createBackend(allocator, .sqlite);
//!
//! try source.open("mydb", .{});
//! try dest.open("mydb_migrated", .{ .create_if_missing = true });
//!
//! const stats = try migration.migrate(allocator, source, dest, .{});
//! std.debug.print("Migrated {} objects in {}ms\n", .{ stats.objects_migrated, stats.duration_ms });
//! ```
//!
//! ## Specification References
//!
//! - WHATWG Storage Standard: https://storage.spec.whatwg.org/
//! - W3C IndexedDB 3.0: https://w3c.github.io/IndexedDB/

const std = @import("std");
const backend = @import("backend.zig");

const StorageBackend = backend.StorageBackend;
const BackendError = backend.BackendError;
const TransactionMode = backend.TransactionMode;
const KeyRange = backend.KeyRange;
const CursorDirection = backend.CursorDirection;

// ============================================================================
// Migration Types
// ============================================================================

/// Migration options
pub const MigrationOptions = struct {
    /// Batch size for copying data (affects memory usage and transaction size)
    batch_size: usize = 1000,

    /// Verify data integrity after migration
    verify: bool = true,

    /// Continue on errors (log but don't fail)
    continue_on_error: bool = false,

    /// Progress callback (called every batch_size items)
    progress_callback: ?*const fn (MigrationProgress) void = null,

    /// Filter function for selective migration (return true to include)
    key_filter: ?*const fn ([]const u8) bool = null,
};

/// Migration progress information
pub const MigrationProgress = struct {
    /// Total objects processed so far
    objects_processed: u64,

    /// Total bytes processed so far
    bytes_processed: u64,

    /// Estimated total objects (may be 0 if unknown)
    estimated_total: u64,

    /// Current object store being migrated
    current_store: ?[]const u8,

    /// Whether migration is complete
    is_complete: bool,
};

/// Migration statistics
pub const MigrationStats = struct {
    /// Number of objects successfully migrated
    objects_migrated: u64 = 0,

    /// Number of bytes migrated
    bytes_migrated: u64 = 0,

    /// Number of errors encountered
    errors: u64 = 0,

    /// Migration duration in milliseconds
    duration_ms: i64 = 0,

    /// Number of object stores migrated
    stores_migrated: u32 = 0,

    /// Number of indexes migrated
    indexes_migrated: u32 = 0,

    /// Verification passed (if verify option was enabled)
    verification_passed: bool = true,
};

/// Migration error with context
pub const MigrationError = error{
    /// Source database is not open
    SourceNotOpen,

    /// Destination database is not open
    DestinationNotOpen,

    /// Failed to read from source
    SourceReadError,

    /// Failed to write to destination
    DestinationWriteError,

    /// Data verification failed
    VerificationFailed,

    /// Migration was cancelled
    Cancelled,

    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// Migration Functions
// ============================================================================

/// Migrate all data from source to destination backend
///
/// This function:
/// 1. Opens read transaction on source
/// 2. Opens write transaction on destination
/// 3. Iterates all object stores and their data
/// 4. Copies each key-value pair to destination
/// 5. Optionally verifies the migration
///
/// Both backends must be open before calling this function.
pub fn migrate(
    allocator: std.mem.Allocator,
    source: StorageBackend,
    destination: StorageBackend,
    options: MigrationOptions,
) MigrationError!MigrationStats {
    var stats = MigrationStats{};
    const start_time = std.time.milliTimestamp();

    // Verify backends are open
    if (!source.isOpen()) {
        return MigrationError.SourceNotOpen;
    }
    if (!destination.isOpen()) {
        return MigrationError.DestinationNotOpen;
    }

    // Get source database info
    const source_info = source.getInfo() catch {
        return MigrationError.SourceReadError;
    };
    defer {
        allocator.free(source_info.name);
        // Free each object store name
        for (source_info.object_stores) |store_name| {
            allocator.free(store_name);
        }
        allocator.free(source_info.object_stores);
    }

    // Begin read transaction on source
    const source_txn = source.beginTransaction(.readonly) catch {
        return MigrationError.SourceReadError;
    };
    defer source.rollback(source_txn);

    // Begin write transaction on destination (versionchange for schema operations)
    const dest_txn = destination.beginTransaction(.versionchange) catch {
        return MigrationError.DestinationWriteError;
    };
    errdefer destination.rollback(dest_txn);

    // Migrate each object store
    for (source_info.object_stores) |store_name| {
        const result = migrateObjectStore(
            allocator,
            source,
            source_txn,
            destination,
            dest_txn,
            store_name,
            options,
            &stats,
        );

        if (result) |_| {
            stats.stores_migrated += 1;
        } else |err| {
            stats.errors += 1;
            if (!options.continue_on_error) {
                return err;
            }
        }
    }

    // Commit destination transaction
    destination.commit(dest_txn) catch {
        return MigrationError.DestinationWriteError;
    };

    // Verify if requested
    if (options.verify) {
        const verified = verifyMigration(allocator, source, destination) catch false;
        stats.verification_passed = verified;
        if (!verified and !options.continue_on_error) {
            return MigrationError.VerificationFailed;
        }
    }

    stats.duration_ms = std.time.milliTimestamp() - start_time;

    // Final progress callback
    if (options.progress_callback) |callback| {
        callback(.{
            .objects_processed = stats.objects_migrated,
            .bytes_processed = stats.bytes_migrated,
            .estimated_total = stats.objects_migrated,
            .current_store = null,
            .is_complete = true,
        });
    }

    return stats;
}

/// Migrate a single object store
fn migrateObjectStore(
    _: std.mem.Allocator,
    source: StorageBackend,
    source_txn: backend.TransactionHandle,
    destination: StorageBackend,
    dest_txn: backend.TransactionHandle,
    store_name: []const u8,
    options: MigrationOptions,
    stats: *MigrationStats,
) MigrationError!void {
    // Try to create object store in destination (ignore if already exists)
    destination.createObjectStore(dest_txn, store_name, .{}) catch |err| {
        // Ignore AlreadyExists - that's fine for migration
        if (err != BackendError.AlreadyExists) {
            return MigrationError.DestinationWriteError;
        }
    };

    // Open cursor on source
    const cursor = source.cursorOpen(source_txn, KeyRange{}, .next) catch {
        return MigrationError.SourceReadError;
    };
    defer source.cursorClose(cursor);

    var batch_count: usize = 0;

    // Iterate and copy
    while (true) {
        var kv = source.cursorNext(cursor) catch {
            return MigrationError.SourceReadError;
        } orelse break;
        defer kv.deinit();

        // Apply key filter if provided
        if (options.key_filter) |filter| {
            if (!filter(kv.key)) {
                continue;
            }
        }

        // Write to destination
        destination.write(dest_txn, kv.key, kv.value) catch {
            return MigrationError.DestinationWriteError;
        };

        stats.objects_migrated += 1;
        stats.bytes_migrated += kv.key.len + kv.value.len;
        batch_count += 1;

        // Progress callback
        if (batch_count >= options.batch_size) {
            if (options.progress_callback) |callback| {
                callback(.{
                    .objects_processed = stats.objects_migrated,
                    .bytes_processed = stats.bytes_migrated,
                    .estimated_total = 0, // Unknown
                    .current_store = store_name,
                    .is_complete = false,
                });
            }
            batch_count = 0;
        }
    }
}

/// Verify migration by comparing source and destination
fn verifyMigration(
    allocator: std.mem.Allocator,
    source: StorageBackend,
    destination: StorageBackend,
) !bool {
    // Get database info from both
    const source_info = try source.getInfo();
    defer {
        allocator.free(source_info.name);
        for (source_info.object_stores) |store_name| {
            allocator.free(store_name);
        }
        allocator.free(source_info.object_stores);
    }

    const dest_info = try destination.getInfo();
    defer {
        allocator.free(dest_info.name);
        for (dest_info.object_stores) |store_name| {
            allocator.free(store_name);
        }
        allocator.free(dest_info.object_stores);
    }

    // Compare object store counts
    if (source_info.object_stores.len != dest_info.object_stores.len) {
        return false;
    }

    // Compare sizes
    const source_size = try source.estimateSize();
    const dest_size = try destination.estimateSize();

    // Allow some variance due to backend-specific overhead
    const size_diff = if (source_size > dest_size) source_size - dest_size else dest_size - source_size;
    const tolerance = source_size / 10; // 10% tolerance

    if (size_diff > tolerance) {
        return false;
    }

    return true;
}

/// Copy a single key-value pair between backends
pub fn copyKey(
    allocator: std.mem.Allocator,
    source: StorageBackend,
    destination: StorageBackend,
    key: []const u8,
) !void {
    const source_txn = try source.beginTransaction(.readonly);
    defer source.rollback(source_txn);

    const value = try source.vtable.read(source.ptr, allocator, source_txn, key) orelse return error.KeyNotFound;
    defer allocator.free(value);

    const dest_txn = try destination.beginTransaction(.readwrite);
    errdefer destination.rollback(dest_txn);

    try destination.write(dest_txn, key, value);
    try destination.commit(dest_txn);
}

/// Export all data to a portable format (for backup)
pub fn exportToBuffer(
    allocator: std.mem.Allocator,
    source: StorageBackend,
) ![]u8 {
    if (!source.isOpen()) {
        return MigrationError.SourceNotOpen;
    }

    var buffer: std.ArrayListUnmanaged(u8) = .{};
    errdefer buffer.deinit(allocator);

    const txn = try source.beginTransaction(.readonly);
    defer source.rollback(txn);

    // Simple format: [key_len:4][key][value_len:4][value]...
    const cursor = try source.cursorOpen(txn, KeyRange{}, .next);
    defer source.cursorClose(cursor);

    while (try source.cursorNext(cursor)) |kv| {
        var kv_mut = kv;
        defer kv_mut.deinit();

        // Write key length
        var key_len: [4]u8 = undefined;
        std.mem.writeInt(u32, &key_len, @intCast(kv_mut.key.len), .little);
        try buffer.appendSlice(allocator, &key_len);

        // Write key
        try buffer.appendSlice(allocator, kv_mut.key);

        // Write value length
        var val_len: [4]u8 = undefined;
        std.mem.writeInt(u32, &val_len, @intCast(kv_mut.value.len), .little);
        try buffer.appendSlice(allocator, &val_len);

        // Write value
        try buffer.appendSlice(allocator, kv_mut.value);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Import data from a buffer (for restore)
pub fn importFromBuffer(
    destination: StorageBackend,
    data: []const u8,
) !u64 {
    if (!destination.isOpen()) {
        return MigrationError.DestinationNotOpen;
    }

    const txn = try destination.beginTransaction(.readwrite);
    errdefer destination.rollback(txn);

    var pos: usize = 0;
    var count: u64 = 0;

    while (pos < data.len) {
        // Read key length
        if (pos + 4 > data.len) break;
        const key_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;

        // Read key
        if (pos + key_len > data.len) break;
        const key = data[pos..][0..key_len];
        pos += key_len;

        // Read value length
        if (pos + 4 > data.len) break;
        const val_len = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;

        // Read value
        if (pos + val_len > data.len) break;
        const value = data[pos..][0..val_len];
        pos += val_len;

        // Write to destination
        try destination.write(txn, key, value);
        count += 1;
    }

    try destination.commit(txn);

    return count;
}

// ============================================================================
// Tests
// ============================================================================

test "migrate - memory to memory" {
    const allocator = std.testing.allocator;
    const backends = @import("backends/root.zig");

    // Create source and destination
    var source = try backends.MemoryBackend.create(allocator);
    defer source.destroy();

    var dest = try backends.MemoryBackend.create(allocator);
    defer dest.destroy();

    // Setup source
    try source.open("source_db", .{});
    defer source.close();

    const txn = try source.beginTransaction(.readwrite);
    try source.write(txn, "key1", "value1");
    try source.write(txn, "key2", "value2");
    try source.write(txn, "key3", "value3");
    try source.commit(txn);

    // Setup destination
    try dest.open("dest_db", .{ .create_if_missing = true });
    defer dest.close();

    // Migrate
    const stats = try migrate(allocator, source, dest, .{ .verify = false });

    try std.testing.expectEqual(@as(u64, 3), stats.objects_migrated);
    try std.testing.expectEqual(@as(u64, 0), stats.errors);
    try std.testing.expect(stats.duration_ms >= 0);
}

test "exportToBuffer and importFromBuffer" {
    const allocator = std.testing.allocator;
    const backends = @import("backends/root.zig");

    // Create and populate source
    var source = try backends.MemoryBackend.create(allocator);
    defer source.destroy();

    try source.open("export_test", .{});
    defer source.close();

    const txn = try source.beginTransaction(.readwrite);
    try source.write(txn, "hello", "world");
    try source.write(txn, "foo", "bar");
    try source.commit(txn);

    // Export
    const buffer = try exportToBuffer(allocator, source);
    defer allocator.free(buffer);

    try std.testing.expect(buffer.len > 0);

    // Create destination and import
    var dest = try backends.MemoryBackend.create(allocator);
    defer dest.destroy();

    try dest.open("import_test", .{});
    defer dest.close();

    const count = try importFromBuffer(dest, buffer);
    try std.testing.expectEqual(@as(u64, 2), count);

    // Verify data
    const read_txn = try dest.beginTransaction(.readonly);
    defer dest.rollback(read_txn);

    const value1 = try dest.vtable.read(dest.ptr, allocator, read_txn, "hello");
    defer if (value1) |v| allocator.free(v);
    try std.testing.expectEqualStrings("world", value1.?);

    const value2 = try dest.vtable.read(dest.ptr, allocator, read_txn, "foo");
    defer if (value2) |v| allocator.free(v);
    try std.testing.expectEqualStrings("bar", value2.?);
}
