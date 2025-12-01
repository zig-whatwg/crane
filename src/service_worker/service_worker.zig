//! Service Worker Internal Structure
//!
//! Internal representation of a service worker per spec Section 2.1.
//! This is NOT the WebIDL ServiceWorker interface (that's in interfaces/).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const ServiceWorkerState = types.ServiceWorkerState;
const WorkerType = types.WorkerType;

/// Internal service worker structure.
///
/// A service worker is a type of web worker. It executes in the registering
/// service worker client's origin.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker
pub const ServiceWorker = struct {
    allocator: Allocator,

    /// Unique identifier for this service worker.
    id: u64,

    /// The service worker's state.
    /// Initially "parsed".
    state: ServiceWorkerState = .parsed,

    /// The script URL.
    script_url: []const u8,

    /// Worker type (classic or module).
    worker_type: WorkerType = .classic,

    /// The containing service worker registration.
    /// Set after construction.
    containing_registration: ?*anyopaque = null,

    /// The global object (ServiceWorkerGlobalScope).
    /// Null when the worker is not running.
    global_object: ?*anyopaque = null,

    /// Skip waiting flag.
    /// When set, the worker can activate without waiting.
    skip_waiting_flag: bool = false,

    /// Classic scripts imported flag.
    /// Set when importScripts() has been called.
    classic_scripts_imported_flag: bool = false,

    /// All fetch listeners are empty flag.
    /// Set when no fetch event listeners are registered.
    all_fetch_listeners_are_empty_flag: bool = false,

    /// Set of event types to handle.
    /// Contains event types that have listeners registered.
    event_types_to_handle: std.StringHashMapUnmanaged(void),

    /// Script resource map.
    /// Maps URLs to cached script responses.
    script_resource_map: std.StringHashMapUnmanaged([]const u8),

    /// Set of used scripts.
    /// URLs of scripts actually used (for pruning unused resources).
    used_scripts: std.StringHashMapUnmanaged(void),

    /// Start status.
    /// Null until the worker has started, then success or error.
    start_status: ?StartStatus = null,

    /// Script hash for byte-for-byte comparison during updates.
    script_hash: ?[]const u8 = null,

    /// Counter for generating unique IDs.
    var next_id: u64 = 0;

    const Self = @This();

    /// Start status of a service worker.
    pub const StartStatus = union(enum) {
        /// Successfully started.
        success: void,

        /// Failed to start with error message.
        failure: []const u8,
    };

    /// Create a new service worker.
    pub fn init(allocator: Allocator, script_url: []const u8, worker_type: WorkerType) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const url_copy = try allocator.dupe(u8, script_url);
        errdefer allocator.free(url_copy);

        self.* = .{
            .allocator = allocator,
            .id = next_id,
            .script_url = url_copy,
            .worker_type = worker_type,
            .event_types_to_handle = .{},
            .script_resource_map = .{},
            .used_scripts = .{},
        };
        next_id += 1;

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.script_url);

        // Free script hash if set
        if (self.script_hash) |hash| {
            self.allocator.free(hash);
        }

        // Free script resource map values
        var script_iter = self.script_resource_map.iterator();
        while (script_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.script_resource_map.deinit(self.allocator);

        // Free event types keys
        var event_iter = self.event_types_to_handle.iterator();
        while (event_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.event_types_to_handle.deinit(self.allocator);

        // Free used scripts keys
        var used_iter = self.used_scripts.iterator();
        while (used_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.used_scripts.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    // === State Management ===

    /// Get the current state.
    pub fn getState(self: *const Self) ServiceWorkerState {
        return self.state;
    }

    /// Transition to a new state.
    ///
    /// Returns error if the transition is invalid.
    pub fn transitionTo(self: *Self, new_state: ServiceWorkerState) !void {
        if (!self.state.canTransitionTo(new_state)) {
            return error.InvalidStateTransition;
        }
        self.state = new_state;
    }

    /// Check if the worker is running.
    ///
    /// A service worker is running if its global object is not null
    /// and its event loop is running.
    pub fn isRunning(self: *const Self) bool {
        return self.global_object != null;
    }

    /// Check if the worker is in a terminal state.
    pub fn isTerminal(self: *const Self) bool {
        return self.state == .redundant;
    }

    /// Set the worker state directly (bypasses transition validation).
    ///
    /// Use this for algorithm implementations where the spec dictates
    /// specific state changes.
    pub fn setState(self: *Self, new_state: ServiceWorkerState) void {
        self.state = new_state;
    }

    /// Set the running status.
    ///
    /// This controls whether the worker appears as "running" by
    /// setting or clearing the global object pointer.
    pub fn setRunning(self: *Self, running: bool) void {
        if (running) {
            // Use a sentinel value to indicate running
            self.global_object = @ptrFromInt(1);
        } else {
            self.global_object = null;
        }
    }

    // === Event Handling ===

    /// Add an event type to handle.
    pub fn addEventTypeToHandle(self: *Self, event_type: []const u8) !void {
        const key = try self.allocator.dupe(u8, event_type);
        errdefer self.allocator.free(key);
        try self.event_types_to_handle.put(self.allocator, key, {});
    }

    /// Check if the worker handles an event type.
    pub fn handlesEventType(self: *const Self, event_type: []const u8) bool {
        return self.event_types_to_handle.contains(event_type);
    }

    /// Check if the worker handles fetch events.
    pub fn handlesFetchEvents(self: *const Self) bool {
        return self.handlesEventType("fetch") and !self.all_fetch_listeners_are_empty_flag;
    }

    // === Script Resources ===

    /// Add a script resource.
    pub fn addScriptResource(self: *Self, url: []const u8, content: []const u8) !void {
        const url_copy = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(url_copy);

        const content_copy = try self.allocator.dupe(u8, content);
        errdefer self.allocator.free(content_copy);

        // Remove old entry if exists
        if (self.script_resource_map.fetchRemove(url)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }

        try self.script_resource_map.put(self.allocator, url_copy, content_copy);
    }

    /// Get a script resource.
    pub fn getScriptResource(self: *const Self, url: []const u8) ?[]const u8 {
        return self.script_resource_map.get(url);
    }

    /// Mark a script as used.
    pub fn markScriptUsed(self: *Self, url: []const u8) !void {
        if (!self.used_scripts.contains(url)) {
            const url_copy = try self.allocator.dupe(u8, url);
            try self.used_scripts.put(self.allocator, url_copy, {});
        }
    }

    /// Check if a script is used.
    pub fn isScriptUsed(self: *const Self, url: []const u8) bool {
        return self.used_scripts.contains(url);
    }

    // === Skip Waiting ===

    /// Set skip waiting flag.
    pub fn setSkipWaiting(self: *Self) void {
        self.skip_waiting_flag = true;
    }

    /// Check skip waiting flag.
    pub fn shouldSkipWaiting(self: *const Self) bool {
        return self.skip_waiting_flag;
    }

    // === Start Status ===

    /// Mark the worker as successfully started.
    pub fn markStartSuccess(self: *Self) void {
        self.start_status = .success;
    }

    /// Mark the worker as failed to start.
    pub fn markStartFailure(self: *Self, message: []const u8) void {
        self.start_status = .{ .failure = message };
    }

    /// Check if the worker started successfully.
    pub fn didStartSuccessfully(self: *const Self) bool {
        if (self.start_status) |status| {
            return switch (status) {
                .success => true,
                .failure => false,
            };
        }
        return false;
    }

    // === Script Hash ===

    /// Set the script hash for update comparison.
    pub fn setScriptHash(self: *Self, hash: []const u8) !void {
        if (self.script_hash) |old_hash| {
            self.allocator.free(old_hash);
        }
        self.script_hash = try self.allocator.dupe(u8, hash);
    }

    /// Get the script hash.
    pub fn getScriptHash(self: *const Self) ?[]const u8 {
        return self.script_hash;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorker.init and deinit" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .module);
    defer sw.deinit();

    try std.testing.expectEqualStrings("https://example.com/sw.js", sw.script_url);
    try std.testing.expectEqual(WorkerType.module, sw.worker_type);
    try std.testing.expectEqual(ServiceWorkerState.parsed, sw.state);
}

test "ServiceWorker.transitionTo valid transitions" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try sw.transitionTo(.installing);
    try std.testing.expectEqual(ServiceWorkerState.installing, sw.state);

    try sw.transitionTo(.installed);
    try std.testing.expectEqual(ServiceWorkerState.installed, sw.state);

    try sw.transitionTo(.activating);
    try std.testing.expectEqual(ServiceWorkerState.activating, sw.state);

    try sw.transitionTo(.activated);
    try std.testing.expectEqual(ServiceWorkerState.activated, sw.state);
}

test "ServiceWorker.transitionTo invalid transition" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    // Can't go from parsed to activated directly
    const result = sw.transitionTo(.activated);
    try std.testing.expectError(error.InvalidStateTransition, result);
}

test "ServiceWorker.addEventTypeToHandle" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try sw.addEventTypeToHandle("fetch");
    try sw.addEventTypeToHandle("install");

    try std.testing.expect(sw.handlesEventType("fetch"));
    try std.testing.expect(sw.handlesEventType("install"));
    try std.testing.expect(!sw.handlesEventType("activate"));
}

test "ServiceWorker.handlesFetchEvents" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    // No fetch handler initially
    try std.testing.expect(!sw.handlesFetchEvents());

    // Add fetch handler
    try sw.addEventTypeToHandle("fetch");
    try std.testing.expect(sw.handlesFetchEvents());

    // Set empty flag
    sw.all_fetch_listeners_are_empty_flag = true;
    try std.testing.expect(!sw.handlesFetchEvents());
}

test "ServiceWorker.addScriptResource" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try sw.addScriptResource("https://example.com/lib.js", "console.log('hello');");

    const content = sw.getScriptResource("https://example.com/lib.js");
    try std.testing.expect(content != null);
    try std.testing.expectEqualStrings("console.log('hello');", content.?);
}

test "ServiceWorker.markScriptUsed" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try std.testing.expect(!sw.isScriptUsed("https://example.com/lib.js"));

    try sw.markScriptUsed("https://example.com/lib.js");
    try std.testing.expect(sw.isScriptUsed("https://example.com/lib.js"));
}

test "ServiceWorker.skipWaiting" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try std.testing.expect(!sw.shouldSkipWaiting());

    sw.setSkipWaiting();
    try std.testing.expect(sw.shouldSkipWaiting());
}

test "ServiceWorker.startStatus" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try std.testing.expect(!sw.didStartSuccessfully());

    sw.markStartSuccess();
    try std.testing.expect(sw.didStartSuccessfully());
}

test "ServiceWorker.isRunning" {
    const allocator = std.testing.allocator;

    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    try std.testing.expect(!sw.isRunning());

    // Mock a global object
    var dummy: u8 = 0;
    sw.global_object = @ptrCast(&dummy);
    try std.testing.expect(sw.isRunning());
}
