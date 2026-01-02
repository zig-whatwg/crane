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
//! - Index 2: SharedWorker context
//! - Index 3: ServiceWorker context
//! - Index 4: AudioWorklet context
//! - Index 5: PaintWorklet context
//! - Index 6: AnimationWorklet context
//! - Index 7: LayoutWorklet context
//! - Index 8: SharedStorageWorklet context
//! - Index 9: ShadowRealm context
//!
//! ## Usage
//!
//! ```zig
//! const index = SnapshotContextIndex.dedicated_worker;
//! const context = v8_Context_NewFromSnapshotAt(isolate, @intFromEnum(index));
//!
//! // Convert from GlobalScopeKind
//! const scope_kind = GlobalScopeKind.audio_worklet;
//! const snapshot_index = SnapshotContextIndex.forScopeKind(scope_kind);
//! ```
//!
//! ## Specification References
//! - HTML Realms: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//! - WebIDL [Exposed]: https://webidl.spec.whatwg.org/#Exposed
//! - Worklets: https://drafts.css-houdini.org/worklets/

const std = @import("std");
const runtime = @import("runtime");
const GlobalScopeKind = runtime.GlobalScopeKind;
const helpers = @import("webidl").helpers;
const HelperGlobalScope = helpers.GlobalScope;

/// Snapshot context indices
///
/// These indices correspond to the order in which contexts are added to the
/// V8 snapshot via SnapshotCreator::AddContext(). The indices are stable and
/// must not change between snapshot creation and loading.
///
/// IMPORTANT: The enum values (0, 1, 2, ...) are the actual snapshot indices.
/// Adding new context types MUST append to the end to maintain compatibility.
pub const SnapshotContextIndex = enum(usize) {
    /// Window context (primary browser context)
    /// Contains: Document, Window, Element, etc.
    /// [Exposed=Window] interfaces
    window = 0,

    /// DedicatedWorkerGlobalScope context
    /// Contains: WorkerGlobalScope, DedicatedWorkerGlobalScope, etc.
    /// [Exposed=Worker] or [Exposed=DedicatedWorker] interfaces
    dedicated_worker = 1,

    /// SharedWorkerGlobalScope context
    /// [Exposed=Worker] or [Exposed=SharedWorker] interfaces
    shared_worker = 2,

    /// ServiceWorkerGlobalScope context
    /// [Exposed=Worker] or [Exposed=ServiceWorker] interfaces
    service_worker = 3,

    /// AudioWorkletGlobalScope context
    /// [Exposed=AudioWorklet] interfaces
    audio_worklet = 4,

    /// PaintWorkletGlobalScope context
    /// [Exposed=PaintWorklet] interfaces
    paint_worklet = 5,

    /// AnimationWorkletGlobalScope context
    /// [Exposed=AnimationWorklet] interfaces
    animation_worklet = 6,

    /// LayoutWorkletGlobalScope context
    /// [Exposed=LayoutWorklet] interfaces
    layout_worklet = 7,

    /// SharedStorageWorkletGlobalScope context
    /// [Exposed=SharedStorageWorklet] interfaces
    shared_storage_worklet = 8,

    /// ShadowRealm context
    /// Limited exposure for isolated JavaScript realms
    shadow_realm = 9,

    /// Convert from a scope kind value (as usize) to SnapshotContextIndex.
    /// The values correspond to GlobalScopeKind enum values:
    /// 0=window, 1=dedicated_worker, 2=shared_worker, 3=service_worker,
    /// 4=audio_worklet, 5=paint_worklet, 6=animation_worklet,
    /// 7=layout_worklet, 8=shared_storage_worklet, 9=shadow_realm
    ///
    /// Usage: SnapshotContextIndex.forScopeKindValue(@intFromEnum(scope_kind))
    pub fn forScopeKindValue(value: usize) ?SnapshotContextIndex {
        return std.meta.intToEnum(SnapshotContextIndex, value) catch null;
    }

    /// Get the scope kind value (matches GlobalScopeKind enum values)
    pub fn toScopeKindValue(self: SnapshotContextIndex) usize {
        return @intFromEnum(self);
    }

    /// Convert to GlobalScopeKind
    pub fn toScopeKind(self: SnapshotContextIndex) GlobalScopeKind {
        return switch (self) {
            .window => .window,
            .dedicated_worker => .dedicated_worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            .audio_worklet => .audio_worklet,
            .paint_worklet => .paint_worklet,
            .animation_worklet => .animation_worklet,
            .layout_worklet => .layout_worklet,
            .shared_storage_worklet => .shared_storage_worklet,
            .shadow_realm => .shadow_realm,
        };
    }

    /// Convert to helpers.GlobalScope (for WebIDL interface installation)
    pub fn toHelperScope(self: SnapshotContextIndex) HelperGlobalScope {
        return switch (self) {
            .window => .Window,
            .dedicated_worker => .DedicatedWorker,
            .shared_worker => .SharedWorker,
            .service_worker => .ServiceWorker,
            .audio_worklet => .AudioWorklet,
            .paint_worklet => .PaintWorklet,
            .animation_worklet => .AnimationWorklet,
            .layout_worklet => .LayoutWorklet,
            .shared_storage_worklet => .SharedStorageWorklet,
            .shadow_realm => .ShadowRealm,
        };
    }

    /// Convert from GlobalScopeKind to SnapshotContextIndex
    pub fn forScopeKind(kind: GlobalScopeKind) SnapshotContextIndex {
        return switch (kind) {
            .window => .window,
            .dedicated_worker => .dedicated_worker,
            .shared_worker => .shared_worker,
            .service_worker => .service_worker,
            .audio_worklet => .audio_worklet,
            .paint_worklet => .paint_worklet,
            .animation_worklet => .animation_worklet,
            .layout_worklet => .layout_worklet,
            .shared_storage_worklet => .shared_storage_worklet,
            .shadow_realm => .shadow_realm,
            .unknown => .window, // Fallback to window for unknown
        };
    }

    /// Check if this context type is a worker context
    pub fn isWorker(self: SnapshotContextIndex) bool {
        return switch (self) {
            .dedicated_worker, .shared_worker, .service_worker => true,
            else => false,
        };
    }

    /// Check if this context type is a worklet context
    pub fn isWorklet(self: SnapshotContextIndex) bool {
        return switch (self) {
            .audio_worklet, .paint_worklet, .animation_worklet, .layout_worklet, .shared_storage_worklet => true,
            else => false,
        };
    }

    /// Check if this context type is implemented
    pub fn isImplemented(self: SnapshotContextIndex) bool {
        return self.toScopeKind().isImplemented();
    }

    /// Get the global object interface name for this context
    pub fn globalInterfaceName(self: SnapshotContextIndex) []const u8 {
        return switch (self) {
            .window => "Window",
            .dedicated_worker => "DedicatedWorkerGlobalScope",
            .shared_worker => "SharedWorkerGlobalScope",
            .service_worker => "ServiceWorkerGlobalScope",
            .audio_worklet => "AudioWorkletGlobalScope",
            .paint_worklet => "PaintWorkletGlobalScope",
            .animation_worklet => "AnimationWorkletGlobalScope",
            .layout_worklet => "LayoutWorkletGlobalScope",
            .shared_storage_worklet => "SharedStorageWorkletGlobalScope",
            .shadow_realm => "ShadowRealm",
        };
    }

    /// Total number of context types in the snapshot
    /// Used by snapshot generator to know how many contexts to create
    pub const count: usize = 10;

    /// Currently implemented context types
    /// Only window and dedicated_worker are fully implemented
    pub const implemented = [_]SnapshotContextIndex{
        .window,
        .dedicated_worker,
    };

    /// All context types for iteration
    pub const all = [_]SnapshotContextIndex{
        .window,
        .dedicated_worker,
        .shared_worker,
        .service_worker,
        .audio_worklet,
        .paint_worklet,
        .animation_worklet,
        .layout_worklet,
        .shared_storage_worklet,
        .shadow_realm,
    };
};

// ============================================================================
// Tests
// ============================================================================

test "isWorker" {
    const testing = std.testing;

    // Workers
    try testing.expect(!SnapshotContextIndex.window.isWorker());
    try testing.expect(SnapshotContextIndex.dedicated_worker.isWorker());
    try testing.expect(SnapshotContextIndex.shared_worker.isWorker());
    try testing.expect(SnapshotContextIndex.service_worker.isWorker());

    // Worklets are not workers
    try testing.expect(!SnapshotContextIndex.audio_worklet.isWorker());
    try testing.expect(!SnapshotContextIndex.paint_worklet.isWorker());
    try testing.expect(!SnapshotContextIndex.animation_worklet.isWorker());
    try testing.expect(!SnapshotContextIndex.layout_worklet.isWorker());
    try testing.expect(!SnapshotContextIndex.shared_storage_worklet.isWorker());
    try testing.expect(!SnapshotContextIndex.shadow_realm.isWorker());
}

test "isWorklet" {
    const testing = std.testing;

    // Non-worklets
    try testing.expect(!SnapshotContextIndex.window.isWorklet());
    try testing.expect(!SnapshotContextIndex.dedicated_worker.isWorklet());
    try testing.expect(!SnapshotContextIndex.shared_worker.isWorklet());
    try testing.expect(!SnapshotContextIndex.service_worker.isWorklet());
    try testing.expect(!SnapshotContextIndex.shadow_realm.isWorklet());

    // Worklets
    try testing.expect(SnapshotContextIndex.audio_worklet.isWorklet());
    try testing.expect(SnapshotContextIndex.paint_worklet.isWorklet());
    try testing.expect(SnapshotContextIndex.animation_worklet.isWorklet());
    try testing.expect(SnapshotContextIndex.layout_worklet.isWorklet());
    try testing.expect(SnapshotContextIndex.shared_storage_worklet.isWorklet());
}

test "globalInterfaceName" {
    const testing = std.testing;

    try testing.expectEqualStrings("Window", SnapshotContextIndex.window.globalInterfaceName());
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", SnapshotContextIndex.dedicated_worker.globalInterfaceName());
    try testing.expectEqualStrings("SharedWorkerGlobalScope", SnapshotContextIndex.shared_worker.globalInterfaceName());
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", SnapshotContextIndex.service_worker.globalInterfaceName());
    try testing.expectEqualStrings("AudioWorkletGlobalScope", SnapshotContextIndex.audio_worklet.globalInterfaceName());
    try testing.expectEqualStrings("PaintWorkletGlobalScope", SnapshotContextIndex.paint_worklet.globalInterfaceName());
    try testing.expectEqualStrings("AnimationWorkletGlobalScope", SnapshotContextIndex.animation_worklet.globalInterfaceName());
    try testing.expectEqualStrings("LayoutWorkletGlobalScope", SnapshotContextIndex.layout_worklet.globalInterfaceName());
    try testing.expectEqualStrings("SharedStorageWorkletGlobalScope", SnapshotContextIndex.shared_storage_worklet.globalInterfaceName());
    try testing.expectEqualStrings("ShadowRealm", SnapshotContextIndex.shadow_realm.globalInterfaceName());
}

test "enum values are sequential" {
    const testing = std.testing;

    // Verify indices are sequential starting from 0 - CRITICAL for V8 snapshot
    try testing.expectEqual(@as(usize, 0), @intFromEnum(SnapshotContextIndex.window));
    try testing.expectEqual(@as(usize, 1), @intFromEnum(SnapshotContextIndex.dedicated_worker));
    try testing.expectEqual(@as(usize, 2), @intFromEnum(SnapshotContextIndex.shared_worker));
    try testing.expectEqual(@as(usize, 3), @intFromEnum(SnapshotContextIndex.service_worker));
    try testing.expectEqual(@as(usize, 4), @intFromEnum(SnapshotContextIndex.audio_worklet));
    try testing.expectEqual(@as(usize, 5), @intFromEnum(SnapshotContextIndex.paint_worklet));
    try testing.expectEqual(@as(usize, 6), @intFromEnum(SnapshotContextIndex.animation_worklet));
    try testing.expectEqual(@as(usize, 7), @intFromEnum(SnapshotContextIndex.layout_worklet));
    try testing.expectEqual(@as(usize, 8), @intFromEnum(SnapshotContextIndex.shared_storage_worklet));
    try testing.expectEqual(@as(usize, 9), @intFromEnum(SnapshotContextIndex.shadow_realm));
}

test "count matches all array" {
    const testing = std.testing;

    try testing.expectEqual(SnapshotContextIndex.count, SnapshotContextIndex.all.len);
}

test "forScopeKind roundtrip" {
    const testing = std.testing;

    // Test all scope kinds convert correctly
    for (SnapshotContextIndex.all) |idx| {
        const kind = idx.toScopeKind();
        const back = SnapshotContextIndex.forScopeKind(kind);
        try testing.expectEqual(idx, back);
    }
}

test "implemented contexts" {
    const testing = std.testing;

    // Verify implemented list matches expected (only window and dedicated_worker for now)
    try testing.expectEqual(@as(usize, 2), SnapshotContextIndex.implemented.len);
    try testing.expectEqual(SnapshotContextIndex.window, SnapshotContextIndex.implemented[0]);
    try testing.expectEqual(SnapshotContextIndex.dedicated_worker, SnapshotContextIndex.implemented[1]);

    // Verify isImplemented matches implemented array
    for (SnapshotContextIndex.implemented) |idx| {
        try testing.expect(idx.isImplemented());
    }
}
