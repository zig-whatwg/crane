//! Realm and Context Type Infrastructure
//!
//! Per WHATWG HTML spec, a Realm is a JavaScript execution environment.
//! Each Realm has an associated global object that determines API exposure.
//!
//! This module provides:
//! - ContextType enum for identifying execution environments
//! - RealmInfo struct for context metadata
//! - Exposure checking for WebIDL [Exposed] attributes
//!
//! ## Specification References
//! - HTML Realms: https://html.spec.whatwg.org/multipage/webappapis.html#concept-realm
//! - WebIDL Exposed: https://webidl.spec.whatwg.org/#Exposed

const std = @import("std");

/// JavaScript execution context type
///
/// Per HTML spec, these correspond to different global object types.
/// Each type has different API exposure per WebIDL [Exposed] attributes.
pub const ContextType = enum {
    /// Browser window context (global = Window)
    /// Most APIs are exposed here
    window,

    /// Dedicated Web Worker (global = DedicatedWorkerGlobalScope)
    /// Subset of APIs, no DOM access
    dedicated_worker,

    /// Shared Web Worker (global = SharedWorkerGlobalScope)
    /// Similar to dedicated but shared across contexts
    shared_worker,

    /// Service Worker (global = ServiceWorkerGlobalScope)
    /// Background worker for offline/caching
    service_worker,

    /// Worklet (AudioWorklet, PaintWorklet, etc.)
    /// Highly restricted execution environment
    worklet,

    /// Unknown/unspecified context (for testing)
    /// Should not be used in production
    unknown,

    /// Get human-readable name for debugging
    pub fn name(self: ContextType) []const u8 {
        return switch (self) {
            .window => "Window",
            .dedicated_worker => "DedicatedWorkerGlobalScope",
            .shared_worker => "SharedWorkerGlobalScope",
            .service_worker => "ServiceWorkerGlobalScope",
            .worklet => "Worklet",
            .unknown => "Unknown",
        };
    }
};

/// WebIDL [Exposed] attribute values
///
/// Maps to WebIDL extended attribute:
/// - [Exposed=Window]
/// - [Exposed=Worker]
/// - [Exposed=(Window,Worker)]
/// - [Exposed=*]
pub const Exposure = enum {
    /// Exposed only in Window context
    window,

    /// Exposed only in Worker contexts (all worker types)
    worker,

    /// Exposed in both Window and Worker contexts
    window_and_worker,

    /// Exposed in all contexts
    all,
};

/// Realm information for a JavaScript execution context
///
/// Contains metadata about the current Realm, used for:
/// - API exposure checking ([Exposed] attributes)
/// - Security origin checks (future)
/// - Settings object access (future)
pub const RealmInfo = struct {
    /// Type of execution context
    context_type: ContextType,

    // Future fields:
    // origin: ?Origin,           // Security origin
    // settings_object: ?*EnvironmentSettingsObject,
    // global_object: ?*anyopaque,  // Reference to global (Window, Worker, etc.)

    const Self = @This();

    /// Create RealmInfo for a Window context
    pub fn forWindow() Self {
        return .{ .context_type = .window };
    }

    /// Create RealmInfo for a DedicatedWorker context
    pub fn forDedicatedWorker() Self {
        return .{ .context_type = .dedicated_worker };
    }

    /// Create RealmInfo for a SharedWorker context
    pub fn forSharedWorker() Self {
        return .{ .context_type = .shared_worker };
    }

    /// Create RealmInfo for a ServiceWorker context
    pub fn forServiceWorker() Self {
        return .{ .context_type = .service_worker };
    }

    /// Create RealmInfo for a Worklet context
    pub fn forWorklet() Self {
        return .{ .context_type = .worklet };
    }

    /// Create RealmInfo for testing (unknown context)
    pub fn forTesting() Self {
        return .{ .context_type = .unknown };
    }

    /// Check if this is a Window context
    pub fn isWindow(self: Self) bool {
        return self.context_type == .window;
    }

    /// Check if this is any Worker context
    pub fn isWorker(self: Self) bool {
        return switch (self.context_type) {
            .dedicated_worker, .shared_worker, .service_worker => true,
            else => false,
        };
    }

    /// Check if this is a Worklet context
    pub fn isWorklet(self: Self) bool {
        return self.context_type == .worklet;
    }

    /// Check if an API with given exposure is available in this context
    ///
    /// Per WebIDL spec, [Exposed] attribute determines availability:
    /// - [Exposed=Window] -> only in Window
    /// - [Exposed=Worker] -> only in Workers
    /// - [Exposed=(Window,Worker)] -> both
    /// - [Exposed=*] -> all contexts
    pub fn isExposedTo(self: Self, exposure: Exposure) bool {
        return switch (exposure) {
            .window => self.isWindow(),
            .worker => self.isWorker(),
            .window_and_worker => self.isWindow() or self.isWorker(),
            .all => true,
        };
    }

    /// Get human-readable context name
    pub fn contextName(self: Self) []const u8 {
        return self.context_type.name();
    }
};

// ============================================================================
// Tests
// ============================================================================

test "ContextType - names" {
    const testing = std.testing;

    try testing.expectEqualStrings("Window", ContextType.window.name());
    try testing.expectEqualStrings("DedicatedWorkerGlobalScope", ContextType.dedicated_worker.name());
    try testing.expectEqualStrings("ServiceWorkerGlobalScope", ContextType.service_worker.name());
}

test "RealmInfo - factory methods" {
    const testing = std.testing;

    const window = RealmInfo.forWindow();
    try testing.expect(window.isWindow());
    try testing.expect(!window.isWorker());

    const worker = RealmInfo.forDedicatedWorker();
    try testing.expect(!worker.isWindow());
    try testing.expect(worker.isWorker());

    const service = RealmInfo.forServiceWorker();
    try testing.expect(service.isWorker());
}

test "RealmInfo - exposure checking" {
    const testing = std.testing;

    const window = RealmInfo.forWindow();
    try testing.expect(window.isExposedTo(.window));
    try testing.expect(!window.isExposedTo(.worker));
    try testing.expect(window.isExposedTo(.window_and_worker));
    try testing.expect(window.isExposedTo(.all));

    const worker = RealmInfo.forDedicatedWorker();
    try testing.expect(!worker.isExposedTo(.window));
    try testing.expect(worker.isExposedTo(.worker));
    try testing.expect(worker.isExposedTo(.window_and_worker));
    try testing.expect(worker.isExposedTo(.all));
}

test "RealmInfo - worklet not exposed to worker" {
    const testing = std.testing;

    const worklet = RealmInfo.forWorklet();
    try testing.expect(!worklet.isWindow());
    try testing.expect(!worklet.isWorker());
    try testing.expect(!worklet.isExposedTo(.window));
    try testing.expect(!worklet.isExposedTo(.worker));
    try testing.expect(!worklet.isExposedTo(.window_and_worker));
    try testing.expect(worklet.isExposedTo(.all));
}
