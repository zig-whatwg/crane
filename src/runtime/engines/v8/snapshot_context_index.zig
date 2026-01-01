//! Snapshot Context Index Map
//!
//! Defines the indices used for V8 snapshot contexts. These indices MUST match
//! between the snapshot generator (tools/snapshot_generator.zig) and the snapshot
//! loader (src/runtime/engines/v8/snapshot_loader.zig).
//!
//! V8's SnapshotCreator::AddContext() returns sequential indices (0, 1, 2, ...).
//! V8's Context::FromSnapshot(isolate, index) retrieves contexts by these indices.
//!
//! ## Architecture
//!
//! The snapshot contains multiple context types, each with different WebIDL
//! interface bindings based on [Exposed] attributes:
//!
//! - Index 0: Window context (Document, Window, etc.)
//! - Index 1: DedicatedWorker context (WorkerGlobalScope, etc.)
//! - Index 2: SharedWorker context (future)
//! - Index 3: ServiceWorker context (future)
//!
//! ## Usage
//!
//! ```zig
//! const index = SnapshotContextIndex.dedicated_worker;
//! const context = v8_Context_NewFromSnapshotAt(isolate, @intFromEnum(index));
//! ```
//!
//! ## Specification References
//! - HTML Realms: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//! - WebIDL [Exposed]: https://webidl.spec.whatwg.org/#Exposed

const std = @import("std");

/// Snapshot context indices
///
/// These indices correspond to the order in which contexts are added to the
/// V8 snapshot via SnapshotCreator::AddContext(). The indices are stable and
/// must not change between snapshot creation and loading.
pub const SnapshotContextIndex = enum(usize) {
    /// Window context (primary browser context)
    /// Contains: Document, Window, Element, etc.
    /// [Exposed=Window] interfaces
    window = 0,

    /// DedicatedWorkerGlobalScope context
    /// Contains: WorkerGlobalScope, DedicatedWorkerGlobalScope, etc.
    /// [Exposed=Worker] or [Exposed=DedicatedWorker] interfaces
    dedicated_worker = 1,

    /// SharedWorkerGlobalScope context (future)
    /// [Exposed=Worker] or [Exposed=SharedWorker] interfaces
    shared_worker = 2,

    /// ServiceWorkerGlobalScope context (future)
    /// [Exposed=Worker] or [Exposed=ServiceWorker] interfaces
    service_worker = 3,

    /// Check if this context type is a worker context
    pub fn isWorker(self: SnapshotContextIndex) bool {
        return switch (self) {
            .window => false,
            .dedicated_worker, .shared_worker, .service_worker => true,
        };
    }

    /// Get the global object interface name for this context
    pub fn globalInterfaceName(self: SnapshotContextIndex) []const u8 {
        return switch (self) {
            .window => "Window",
            .dedicated_worker => "DedicatedWorkerGlobalScope",
            .shared_worker => "SharedWorkerGlobalScope",
            .service_worker => "ServiceWorkerGlobalScope",
        };
    }

    /// Total number of context types in the snapshot
    /// Used by snapshot generator to know how many contexts to create
    pub const count: usize = 4;

    /// Currently implemented context types
    /// Only window and dedicated_worker are fully implemented
    pub const implemented = [_]SnapshotContextIndex{
        .window,
        .dedicated_worker,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "isWorker" {
    const testing = std.testing;

    try testing.expect(!SnapshotContextIndex.window.isWorker());
    try testing.expect(SnapshotContextIndex.dedicated_worker.isWorker());
    try testing.expect(SnapshotContextIndex.shared_worker.isWorker());
    try testing.expect(SnapshotContextIndex.service_worker.isWorker());
}

test "globalInterfaceName" {
    const testing = std.testing;

    try testing.expectEqualStrings("Window", SnapshotContextIndex.window.globalInterfaceName());
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", SnapshotContextIndex.dedicated_worker.globalInterfaceName());
    try testing.expectEqualStrings("SharedWorkerGlobalScope", SnapshotContextIndex.shared_worker.globalInterfaceName());
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", SnapshotContextIndex.service_worker.globalInterfaceName());
}

test "enum values are sequential" {
    const testing = std.testing;

    // Verify indices are sequential starting from 0 - CRITICAL for V8 snapshot
    try testing.expectEqual(@as(usize, 0), @intFromEnum(SnapshotContextIndex.window));
    try testing.expectEqual(@as(usize, 1), @intFromEnum(SnapshotContextIndex.dedicated_worker));
    try testing.expectEqual(@as(usize, 2), @intFromEnum(SnapshotContextIndex.shared_worker));
    try testing.expectEqual(@as(usize, 3), @intFromEnum(SnapshotContextIndex.service_worker));
}

test "implemented contexts" {
    const testing = std.testing;

    // Verify implemented list matches expected
    try testing.expectEqual(@as(usize, 2), SnapshotContextIndex.implemented.len);
    try testing.expectEqual(SnapshotContextIndex.window, SnapshotContextIndex.implemented[0]);
    try testing.expectEqual(SnapshotContextIndex.dedicated_worker, SnapshotContextIndex.implemented[1]);
}
