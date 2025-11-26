//! IndexedDB Storage Integration Tests
//!
//! Integration tests verifying the complete IndexedDB storage stack works
//! correctly. Tests cover:
//!
//! - Key encoding/decoding roundtrips
//! - Schema versioning and migrations
//! - Transaction management
//! - Worker thread pool operations
//! - Transaction ordering
//!
//! ## Spec References
//!
//! - Storage: https://storage.spec.whatwg.org/
//! - IndexedDB: https://w3c.github.io/IndexedDB/

const std = @import("std");
const storage = @import("storage");
const indexeddb = storage.indexeddb;

// ============================================================================
// Key Encoding/Decoding Tests
// ============================================================================

test "Integration - key encoding roundtrip for numbers" {
    const allocator = std.testing.allocator;

    const test_values = [_]f64{ -std.math.inf(f64), -1000.5, -1, -0.001, 0, 0.001, 1, 1000.5, std.math.inf(f64) };

    for (test_values) |val| {
        const key = indexeddb.IDBKey.number(val);
        const encoded = try indexeddb.encodeKey(allocator, key);
        defer allocator.free(encoded);

        const decoded = try indexeddb.decodeKey(allocator, encoded);
        try std.testing.expectEqual(val, decoded.value.number);
    }
}

test "Integration - key encoding roundtrip for strings" {
    const allocator = std.testing.allocator;

    const test_strings = [_][]const u8{ "", "a", "hello", "Hello World!", "日本語" };

    for (test_strings) |str| {
        const key = indexeddb.IDBKey.string(str);
        const encoded = try indexeddb.encodeKey(allocator, key);
        defer allocator.free(encoded);

        var decoded = try indexeddb.decodeKey(allocator, encoded);
        defer decoded.deinit();

        try std.testing.expectEqualStrings(str, decoded.value.string);
    }
}

test "Integration - key ordering is preserved in encoding" {
    const allocator = std.testing.allocator;

    // Per IndexedDB spec: number < date < string < binary < array
    const num_key = try indexeddb.encodeKey(allocator, indexeddb.IDBKey.number(1));
    defer allocator.free(num_key);

    const date_key = try indexeddb.encodeKey(allocator, indexeddb.IDBKey.date(0));
    defer allocator.free(date_key);

    const str_key = try indexeddb.encodeKey(allocator, indexeddb.IDBKey.string("a"));
    defer allocator.free(str_key);

    const bin_key = try indexeddb.encodeKey(allocator, indexeddb.IDBKey.binary("a"));
    defer allocator.free(bin_key);

    // Type tag is first byte, and types are ordered correctly
    try std.testing.expect(num_key[0] < date_key[0]);
    try std.testing.expect(date_key[0] < str_key[0]);
    try std.testing.expect(str_key[0] < bin_key[0]);
}

// ============================================================================
// Schema Versioning Tests
// ============================================================================

test "Integration - schema version upgrade chain" {
    const allocator = std.testing.allocator;

    var mgr = try indexeddb.SchemaManager.init(allocator, "testdb", 0);
    defer mgr.deinit();

    // Upgrade to version 1
    var m1 = try mgr.beginUpgrade(1);
    try m1.addChange(indexeddb.SchemaChange.createObjectStore("users", "id", true));
    try mgr.commitUpgrade();

    try std.testing.expectEqual(@as(u64, 1), mgr.getVersion());
    try std.testing.expect(mgr.hasObjectStore("users"));

    // Upgrade to version 2
    var m2 = try mgr.beginUpgrade(2);
    try m2.addChange(indexeddb.SchemaChange.createObjectStore("posts", "id", true));
    try m2.addChange(indexeddb.SchemaChange.createIndex("users", "email_idx", "email", true, false));
    try mgr.commitUpgrade();

    try std.testing.expectEqual(@as(u64, 2), mgr.getVersion());
    try std.testing.expect(mgr.hasObjectStore("posts"));

    // Upgrade to version 3 - delete a store
    var m3 = try mgr.beginUpgrade(3);
    try m3.addChange(indexeddb.SchemaChange.deleteObjectStore("posts"));
    try mgr.commitUpgrade();

    try std.testing.expectEqual(@as(u64, 3), mgr.getVersion());
    try std.testing.expect(!mgr.hasObjectStore("posts"));
    try std.testing.expect(mgr.hasObjectStore("users"));
}

test "Integration - schema upgrade abort" {
    const allocator = std.testing.allocator;

    var mgr = try indexeddb.SchemaManager.init(allocator, "testdb", 1);
    defer mgr.deinit();

    // Start upgrade but abort
    _ = try mgr.beginUpgrade(2);
    mgr.abortUpgrade();

    // Version should not change
    try std.testing.expectEqual(@as(u64, 1), mgr.getVersion());
}

// ============================================================================
// Transaction Management Tests
// ============================================================================

test "Integration - transaction state machine" {
    const allocator = std.testing.allocator;

    var txn = indexeddb.SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    // Transaction starts active
    try std.testing.expectEqual(indexeddb.TransactionState.active, txn.state);

    // Add store to scope
    try txn.addToScope("testStore");
    try std.testing.expect(txn.hasInScope("testStore"));
}

test "Integration - transaction abort with reason" {
    const allocator = std.testing.allocator;

    var txn = indexeddb.SQLiteTransaction.init(allocator, 1, .readwrite);
    defer txn.deinit();

    // Transaction starts active
    try std.testing.expectEqual(indexeddb.TransactionState.active, txn.state);

    // Abort the transaction
    txn.abort(.timeout);
    try std.testing.expectEqual(indexeddb.TransactionState.aborted, txn.state);
    try std.testing.expectEqual(indexeddb.AbortReason.timeout, txn.abort_reason.?);
}

test "Integration - transaction queue FIFO ordering" {
    const allocator = std.testing.allocator;

    var queue = indexeddb.TransactionQueue.init(allocator, 1);
    defer queue.deinit();

    // Enqueue operations in order
    _ = try queue.enqueue(.put, "store1", "key1", "value1");
    _ = try queue.enqueue(.get, "store1", "key2", null);
    _ = try queue.enqueue(.delete, "store1", "key3", null);

    // Dequeue should preserve FIFO order
    const op1 = queue.dequeue().?;
    try std.testing.expectEqual(indexeddb.QueuedRequest.OperationType.put, op1.operation);

    const op2 = queue.dequeue().?;
    try std.testing.expectEqual(indexeddb.QueuedRequest.OperationType.get, op2.operation);

    const op3 = queue.dequeue().?;
    try std.testing.expectEqual(indexeddb.QueuedRequest.OperationType.delete, op3.operation);

    try std.testing.expect(queue.isEmpty());
}

// ============================================================================
// MVCC Tests
// ============================================================================

test "Integration - MVCC snapshot lifecycle" {
    const allocator = std.testing.allocator;

    var mgr = indexeddb.MVCCManager.init(allocator);
    defer mgr.deinit();

    // Create snapshots
    const snap1 = try mgr.createSnapshot(100);
    const snap2 = try mgr.createSnapshot(101);

    try std.testing.expect(snap1.id != snap2.id);

    // Both should have snapshots in manager
    try std.testing.expect(mgr.getSnapshot(snap1.id) != null);
    try std.testing.expect(mgr.getSnapshot(snap2.id) != null);

    // Release first snapshot
    mgr.releaseSnapshot(snap1.id);

    // Release second snapshot
    mgr.releaseSnapshot(snap2.id);
}

// ============================================================================
// Worker Thread Tests
// ============================================================================

test "Integration - work queue operations" {
    const allocator = std.testing.allocator;

    var queue = indexeddb.WorkQueue.init(allocator);
    defer queue.deinit();

    // Push items
    try queue.push(indexeddb.WorkItem.query(allocator, 1, 1, "SELECT 1", null));
    try queue.push(indexeddb.WorkItem.execute(allocator, 1, 2, "INSERT INTO t VALUES (1)", null));

    try std.testing.expectEqual(@as(usize, 2), queue.len());

    // Pop items (FIFO)
    const item1 = queue.tryPop().?;
    try std.testing.expectEqual(indexeddb.WorkItemType.query, item1.work_type);

    const item2 = queue.tryPop().?;
    try std.testing.expectEqual(indexeddb.WorkItemType.execute, item2.work_type);

    try std.testing.expect(queue.tryPop() == null);
}

test "Integration - connection pool lifecycle" {
    const allocator = std.testing.allocator;

    var pool = indexeddb.ConnectionPool.init(allocator);
    defer pool.deinit();

    // Register connections
    const id1 = try pool.register("/data/db1.sqlite");
    const id2 = try pool.register("/data/db2.sqlite");

    try std.testing.expectEqual(@as(usize, 2), pool.openCount());

    // Get path
    try std.testing.expectEqualStrings("/data/db1.sqlite", pool.getPath(id1).?);

    // Close one
    pool.markClosed(id1);
    try std.testing.expect(!pool.isOpen(id1));
    try std.testing.expect(pool.isOpen(id2));
    try std.testing.expectEqual(@as(usize, 1), pool.openCount());
}

// ============================================================================
// Transaction Ordering Tests
// ============================================================================

test "Integration - task priority ordering" {
    const allocator = std.testing.allocator;

    var scheduler = indexeddb.TransactionScheduler.init(allocator);
    defer scheduler.deinit();

    // Schedule tasks with different priorities
    try scheduler.scheduleTask(indexeddb.IDBTask.checkCommit(1)); // Low priority
    try scheduler.scheduleTask(indexeddb.IDBTask.fireSuccess(1, 1)); // Medium priority
    try scheduler.scheduleTask(indexeddb.IDBTask.fireUpgradeneeded(1)); // High priority

    // Should come out in priority order (highest first)
    const task1 = scheduler.nextTask().?;
    try std.testing.expectEqual(indexeddb.IDBTaskType.fire_upgradeneeded, task1.task_type);

    const task2 = scheduler.nextTask().?;
    try std.testing.expectEqual(indexeddb.IDBTaskType.fire_success, task2.task_type);

    const task3 = scheduler.nextTask().?;
    try std.testing.expectEqual(indexeddb.IDBTaskType.check_commit, task3.task_type);
}

test "Integration - versionchange exclusivity" {
    const allocator = std.testing.allocator;

    var coord = indexeddb.VersionchangeCoordinator.init(allocator);
    defer coord.deinit();

    // First versionchange starts immediately
    const result1 = try coord.requestVersionchange(100);
    try std.testing.expectEqual(indexeddb.VersionchangeCoordinator.VersionchangeResult.started, result1);

    // Subsequent versionchanges are blocked
    const result2 = try coord.requestVersionchange(101);
    try std.testing.expectEqual(indexeddb.VersionchangeCoordinator.VersionchangeResult.blocked, result2);

    const result3 = try coord.requestVersionchange(102);
    try std.testing.expectEqual(indexeddb.VersionchangeCoordinator.VersionchangeResult.blocked, result3);

    // Complete first → second starts
    const next1 = coord.completeVersionchange(100);
    try std.testing.expectEqual(@as(?u64, 101), next1);

    // Complete second → third starts
    const next2 = coord.completeVersionchange(101);
    try std.testing.expectEqual(@as(?u64, 102), next2);

    // Complete third → nothing waiting
    const next3 = coord.completeVersionchange(102);
    try std.testing.expect(next3 == null);
}

// ============================================================================
// Auto-Increment Tests
// ============================================================================

test "Integration - auto-increment key generation" {
    // Generator starts at 1 (typical IDB behavior)
    var gen = indexeddb.AutoIncrementGenerator.init(1);

    // Generate sequential keys
    try std.testing.expectEqual(@as(u64, 1), try gen.next());
    try std.testing.expectEqual(@as(u64, 2), try gen.next());
    try std.testing.expectEqual(@as(u64, 3), try gen.next());

    // maybeUpdateCurrent advances generator when given larger key
    gen.maybeUpdateCurrent(100);
    try std.testing.expectEqual(@as(u64, 101), try gen.next());

    // maybeUpdateCurrent ignores smaller keys
    gen.maybeUpdateCurrent(50);
    try std.testing.expectEqual(@as(u64, 102), try gen.next());
}

// ============================================================================
// End-to-End Workflow Tests
// ============================================================================

test "Integration - complete transaction workflow" {
    const allocator = std.testing.allocator;

    // Create ordering manager
    var mgr = indexeddb.TransactionOrderingManager.init(allocator);
    defer mgr.deinit();

    // Start transaction
    try mgr.startTransaction(1, false);

    // Queue requests
    const req1 = try mgr.queueRequest(1, "put");
    const req2 = try mgr.queueRequest(1, "get");

    // Verify requests are sequential
    try std.testing.expect(req1 < req2);

    // Complete requests
    try mgr.completeRequest(1, req1, true);
    try mgr.completeRequest(1, req2, true);

    // End transaction
    try mgr.endTransaction(1, true, false);

    // Process all pending tasks
    var task_count: usize = 0;
    while (mgr.hasPendingTasks()) {
        _ = mgr.processNextTask();
        task_count += 1;
    }

    // Should have processed some tasks
    try std.testing.expect(task_count > 0);
}
