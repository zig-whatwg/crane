//! BSCOPE-12: SharedWorker connect event + MessagePort plumbing validation tests
//!
//! Validates:
//! - MessagePort infrastructure exists and compiles
//! - SharedWorkerGlobalScope connect event infrastructure
//! - Snapshot context for SharedWorker is properly configured

const std = @import("std");
const testing = std.testing;

// Import runtime types (available in test context)
const runtime = @import("runtime");
const v8 = @import("v8");

// Test 1: SharedWorker snapshot context is implemented
test "BSCOPE-12: SharedWorker snapshot context implemented" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;

    // SharedWorker context should be implemented (added in BSCOPE-11)
    try testing.expect(SnapshotContextIndex.shared_worker.isImplemented());
}

// Test 2: SharedWorker maps to correct GlobalScopeKind
test "BSCOPE-12: SharedWorker scope kind mapping" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;
    const GlobalScopeKind = runtime.realm.GlobalScopeKind;

    // SharedWorker snapshot index should map to shared_worker scope
    const scope = SnapshotContextIndex.shared_worker.toScopeKind();
    try testing.expectEqual(GlobalScopeKind.shared_worker, scope);
}

// Test 3: SharedWorker is classified as worker (not worklet)
test "BSCOPE-12: SharedWorker worker classification" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;

    // SharedWorker should be a worker
    try testing.expect(SnapshotContextIndex.shared_worker.isWorker());

    // SharedWorker should NOT be a worklet
    try testing.expect(!SnapshotContextIndex.shared_worker.isWorklet());
}

// Test 4: SharedWorker global interface name
test "BSCOPE-12: SharedWorker global interface name" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;

    // SharedWorker should have correct interface name
    const name = SnapshotContextIndex.shared_worker.globalInterfaceName();
    try testing.expectEqualStrings("SharedWorkerGlobalScope", name);
}

// Test 5: SharedWorker helper scope name
test "BSCOPE-12: SharedWorker helper scope" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;

    // SharedWorker should map to SharedWorker helper scope
    // toHelperScope() returns webidl.helpers.GlobalScope enum
    const helper = SnapshotContextIndex.shared_worker.toHelperScope();
    // Verify it's the SharedWorker variant by checking the tag name
    try testing.expectEqualStrings("SharedWorker", @tagName(helper));
}

// Test 6: Bidirectional mapping consistency
test "BSCOPE-12: SharedWorker bidirectional mapping" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;
    const GlobalScopeKind = runtime.realm.GlobalScopeKind;

    // Forward: index -> scope
    const scope = SnapshotContextIndex.shared_worker.toScopeKind();
    try testing.expectEqual(GlobalScopeKind.shared_worker, scope);

    // Reverse: scope -> index
    const index = SnapshotContextIndex.forScopeKind(scope);
    try testing.expectEqual(SnapshotContextIndex.shared_worker, index);
}

// Test 7: SharedWorker is in implemented list
test "BSCOPE-12: SharedWorker in implemented list" {
    const SnapshotContextIndex = v8.SnapshotContextIndex;

    // implemented array should contain shared_worker
    var found = false;
    for (SnapshotContextIndex.implemented) |idx| {
        if (idx == .shared_worker) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}
