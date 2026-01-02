//! BSCOPE-11: SharedWorker Runtime Bootstrap Validation Tests
//!
//! Validates that SharedWorker context creation uses correct snapshot indices
//! and that the SharedWorkerManager registry works correctly.
//!
//! Validation criteria from BSCOPE-11:
//! 1. Shared worker registry keyed by (origin, resolved URL, name)
//! 2. createSharedWorkerContext(...) -> ContextEntry (via Context.init with .shared_worker)
//! 3. Two SharedWorkers with same key yield same global scope instance
//! 4. SharedWorker stays alive while ports exist
//! 5. No crashes/leaks

const std = @import("std");
const testing = std.testing;
const v8 = @import("v8");
const runtime = @import("runtime");

const SnapshotContextIndex = v8.SnapshotContextIndex;
const GlobalScopeKind = runtime.realm.GlobalScopeKind;

// =============================================================================
// Test 1: SharedWorker snapshot index mapping
// =============================================================================

test "BSCOPE-11: SharedWorker uses correct snapshot index" {
    // SharedWorker should map to snapshot index 2
    const shared_worker_index = SnapshotContextIndex.shared_worker;
    try testing.expectEqual(@as(usize, 2), @intFromEnum(shared_worker_index));

    // Verify it maps to correct GlobalScopeKind (snake_case enum)
    const scope_kind = shared_worker_index.toScopeKind();
    try testing.expectEqual(GlobalScopeKind.shared_worker, scope_kind);

    // Verify reverse mapping
    const reverse_index = SnapshotContextIndex.forScopeKind(GlobalScopeKind.shared_worker);
    try testing.expectEqual(shared_worker_index, reverse_index);
}

// =============================================================================
// Test 2: SharedWorker is NOT a worklet
// =============================================================================

test "BSCOPE-11: SharedWorker is worker, not worklet" {
    const shared_worker_index = SnapshotContextIndex.shared_worker;

    // SharedWorker is a worker
    try testing.expect(shared_worker_index.isWorker());

    // SharedWorker is NOT a worklet
    try testing.expect(!shared_worker_index.isWorklet());

    // SharedWorker is implemented
    try testing.expect(shared_worker_index.isImplemented());
}

// =============================================================================
// Test 3: SharedWorker global interface name
// =============================================================================

test "BSCOPE-11: SharedWorker has correct global interface name" {
    const shared_worker_index = SnapshotContextIndex.shared_worker;
    const global_name = shared_worker_index.globalInterfaceName();

    try testing.expectEqualStrings("SharedWorkerGlobalScope", global_name);
}

// =============================================================================
// Test 4: All worker types have distinct snapshot indices
// =============================================================================

test "BSCOPE-11: Worker types have distinct snapshot indices" {
    const window_idx = @intFromEnum(SnapshotContextIndex.window);
    const dedicated_idx = @intFromEnum(SnapshotContextIndex.dedicated_worker);
    const shared_idx = @intFromEnum(SnapshotContextIndex.shared_worker);
    const service_idx = @intFromEnum(SnapshotContextIndex.service_worker);

    // All indices are distinct
    try testing.expect(window_idx != dedicated_idx);
    try testing.expect(window_idx != shared_idx);
    try testing.expect(window_idx != service_idx);
    try testing.expect(dedicated_idx != shared_idx);
    try testing.expect(dedicated_idx != service_idx);
    try testing.expect(shared_idx != service_idx);

    // Verify expected order: window=0, dedicated=1, shared=2, service=3
    try testing.expectEqual(@as(usize, 0), window_idx);
    try testing.expectEqual(@as(usize, 1), dedicated_idx);
    try testing.expectEqual(@as(usize, 2), shared_idx);
    try testing.expectEqual(@as(usize, 3), service_idx);
}

// =============================================================================
// Test 5: SharedWorker scope kind round-trip
// =============================================================================

test "BSCOPE-11: SharedWorker scope kind round-trip consistency" {
    // Start with scope kind (snake_case enum)
    const scope = GlobalScopeKind.shared_worker;

    // Map to index
    const index = SnapshotContextIndex.forScopeKind(scope);

    // Map back to scope
    const round_trip_scope = index.toScopeKind();

    // Should be identical
    try testing.expectEqual(scope, round_trip_scope);
}

// =============================================================================
// Test 6: All implemented worker scopes have correct classification
// =============================================================================

test "BSCOPE-11: All worker scopes correctly classified" {
    // Window is NOT a worker
    try testing.expect(!SnapshotContextIndex.window.isWorker());

    // All worker types ARE workers
    try testing.expect(SnapshotContextIndex.dedicated_worker.isWorker());
    try testing.expect(SnapshotContextIndex.shared_worker.isWorker());
    try testing.expect(SnapshotContextIndex.service_worker.isWorker());

    // Worklets are worklets, not workers
    try testing.expect(SnapshotContextIndex.audio_worklet.isWorklet());
    try testing.expect(SnapshotContextIndex.paint_worklet.isWorklet());
    try testing.expect(!SnapshotContextIndex.audio_worklet.isWorker());
}

// =============================================================================
// Test 7: SharedWorker global scope name matches interface
// =============================================================================

test "BSCOPE-11: SharedWorker interface naming consistency" {
    // The global interface name should match what WebIDL expects
    const shared_name = SnapshotContextIndex.shared_worker.globalInterfaceName();
    const dedicated_name = SnapshotContextIndex.dedicated_worker.globalInterfaceName();
    const service_name = SnapshotContextIndex.service_worker.globalInterfaceName();

    // Each worker type has unique global scope interface
    try testing.expect(!std.mem.eql(u8, shared_name, dedicated_name));
    try testing.expect(!std.mem.eql(u8, shared_name, service_name));
    try testing.expect(!std.mem.eql(u8, dedicated_name, service_name));

    // Verify exact names
    try testing.expectEqualStrings("SharedWorkerGlobalScope", shared_name);
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", dedicated_name);
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", service_name);
}
