//! Service Worker Client Internal Structure
//!
//! Internal representation of a service worker client per spec Section 2.4.
//! This is NOT the WebIDL Client interface (that's in interfaces/).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker-client

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const ClientType = types.ClientType;
const FrameType = types.FrameType;
const VisibilityState = types.VisibilityState;
const service_worker_mod = @import("service_worker.zig");
const ServiceWorker = service_worker_mod.ServiceWorker;

/// Internal service worker client structure.
///
/// A service worker client is an environment. It can be a window client,
/// dedicated worker client, or shared worker client.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-service-worker-client
pub const Client = struct {
    allocator: Allocator,

    /// Unique identifier for this client.
    id: []const u8,

    /// The client's URL.
    url: []const u8,

    /// The client type (window, worker, sharedworker).
    client_type: ClientType,

    /// Frame type (for window clients only).
    frame_type: FrameType = .none,

    /// The active service worker controlling this client.
    /// Null if not controlled.
    active_service_worker: ?*ServiceWorker = null,

    /// Discarded flag.
    /// Set when the client is discarded/navigated away.
    discarded: bool = false,

    /// Reference to the environment (global object).
    /// Type depends on client_type:
    /// - Window: *Window
    /// - DedicatedWorker: *DedicatedWorkerGlobalScope
    /// - SharedWorker: *SharedWorkerGlobalScope
    environment: ?*anyopaque = null,

    /// Counter for generating unique IDs.
    var next_id: u64 = 0;

    const Self = @This();

    /// Create a new client.
    pub fn init(
        allocator: Allocator,
        url: []const u8,
        client_type: ClientType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Generate unique ID
        const id = try std.fmt.allocPrint(allocator, "client-{d}", .{next_id});
        errdefer allocator.free(id);
        next_id += 1;

        const url_copy = try allocator.dupe(u8, url);

        self.* = .{
            .allocator = allocator,
            .id = id,
            .url = url_copy,
            .client_type = client_type,
        };

        return self;
    }

    /// Create a window client.
    pub fn initWindow(
        allocator: Allocator,
        url: []const u8,
        frame_type: FrameType,
    ) !*Self {
        const self = try init(allocator, url, .window);
        self.frame_type = frame_type;
        return self;
    }

    /// Create a worker client.
    pub fn initWorker(allocator: Allocator, url: []const u8) !*Self {
        return init(allocator, url, .worker);
    }

    /// Create a shared worker client.
    pub fn initSharedWorker(allocator: Allocator, url: []const u8) !*Self {
        return init(allocator, url, .sharedworker);
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.id);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    // === Getters ===

    /// Get the client ID.
    pub fn getId(self: *const Self) []const u8 {
        return self.id;
    }

    /// Get the client URL.
    pub fn getUrl(self: *const Self) []const u8 {
        return self.url;
    }

    /// Get the client type.
    pub fn getType(self: *const Self) ClientType {
        return self.client_type;
    }

    /// Get the frame type (window clients only).
    pub fn getFrameType(self: *const Self) FrameType {
        return self.frame_type;
    }

    // === Control ===

    /// Check if this client is controlled by a service worker.
    pub fn isControlled(self: *const Self) bool {
        return self.active_service_worker != null;
    }

    /// Get the controlling service worker.
    pub fn getController(self: *const Self) ?*ServiceWorker {
        return self.active_service_worker;
    }

    /// Set the controlling service worker.
    pub fn setController(self: *Self, worker: ?*ServiceWorker) void {
        self.active_service_worker = worker;
    }

    // === Discarding ===

    /// Mark the client as discarded.
    pub fn discard(self: *Self) void {
        self.discarded = true;
    }

    /// Check if the client is discarded.
    pub fn isDiscarded(self: *const Self) bool {
        return self.discarded;
    }

    // === Type Checks ===

    /// Check if this is a window client.
    pub fn isWindowClient(self: *const Self) bool {
        return self.client_type == .window;
    }

    /// Check if this is a worker client (dedicated or shared).
    pub fn isWorkerClient(self: *const Self) bool {
        return self.client_type == .worker or self.client_type == .sharedworker;
    }

    /// Check if this is a dedicated worker client.
    pub fn isDedicatedWorkerClient(self: *const Self) bool {
        return self.client_type == .worker;
    }

    /// Check if this is a shared worker client.
    pub fn isSharedWorkerClient(self: *const Self) bool {
        return self.client_type == .sharedworker;
    }
};

/// Window client with additional window-specific properties.
///
/// Spec: https://w3c.github.io/ServiceWorker/#dfn-window-client
pub const WindowClient = struct {
    /// Base client.
    base: *Client,

    /// Visibility state.
    visibility_state: VisibilityState = .hidden,

    /// Whether the window is focused.
    focused: bool = false,

    /// Ancestor origins (for nested browsing contexts).
    ancestor_origins: []const []const u8 = &[_][]const u8{},

    allocator: Allocator,

    const Self = @This();

    /// Create a window client.
    pub fn init(
        allocator: Allocator,
        url: []const u8,
        frame_type: FrameType,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        const base = try Client.initWindow(allocator, url, frame_type);
        errdefer base.deinit();

        self.* = .{
            .base = base,
            .allocator = allocator,
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.base.deinit();
        self.allocator.destroy(self);
    }

    // === Getters ===

    /// Get visibility state.
    pub fn getVisibilityState(self: *const Self) VisibilityState {
        return self.visibility_state;
    }

    /// Check if focused.
    pub fn isFocused(self: *const Self) bool {
        return self.focused;
    }

    /// Get ancestor origins.
    pub fn getAncestorOrigins(self: *const Self) []const []const u8 {
        return self.ancestor_origins;
    }

    // === Setters ===

    /// Set visibility state.
    pub fn setVisibilityState(self: *Self, state: VisibilityState) void {
        self.visibility_state = state;
    }

    /// Set focused state.
    pub fn setFocused(self: *Self, focused: bool) void {
        self.focused = focused;
    }

    // === Delegated methods ===

    pub fn getId(self: *const Self) []const u8 {
        return self.base.getId();
    }

    pub fn getUrl(self: *const Self) []const u8 {
        return self.base.getUrl();
    }

    pub fn getFrameType(self: *const Self) FrameType {
        return self.base.getFrameType();
    }

    pub fn isControlled(self: *const Self) bool {
        return self.base.isControlled();
    }

    pub fn getController(self: *const Self) ?*ServiceWorker {
        return self.base.getController();
    }

    pub fn setController(self: *Self, worker: ?*ServiceWorker) void {
        self.base.setController(worker);
    }
};

// =============================================================================
// Tests
// =============================================================================

test "Client.init and deinit" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/", .window);
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com/", client.getUrl());
    try std.testing.expectEqual(ClientType.window, client.getType());
    try std.testing.expect(!client.isControlled());
    try std.testing.expect(!client.isDiscarded());
}

test "Client.initWindow" {
    const allocator = std.testing.allocator;

    const client = try Client.initWindow(allocator, "https://example.com/", .top_level);
    defer client.deinit();

    try std.testing.expectEqual(ClientType.window, client.getType());
    try std.testing.expectEqual(FrameType.top_level, client.getFrameType());
    try std.testing.expect(client.isWindowClient());
}

test "Client.initWorker" {
    const allocator = std.testing.allocator;

    const client = try Client.initWorker(allocator, "https://example.com/worker.js");
    defer client.deinit();

    try std.testing.expectEqual(ClientType.worker, client.getType());
    try std.testing.expect(client.isWorkerClient());
    try std.testing.expect(client.isDedicatedWorkerClient());
}

test "Client.control" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/", .window);
    defer client.deinit();

    try std.testing.expect(!client.isControlled());

    // Create a service worker to control the client
    const sw = try ServiceWorker.init(allocator, "https://example.com/sw.js", .classic);
    defer sw.deinit();

    client.setController(sw);
    try std.testing.expect(client.isControlled());
    try std.testing.expectEqual(sw, client.getController().?);

    client.setController(null);
    try std.testing.expect(!client.isControlled());
}

test "Client.discard" {
    const allocator = std.testing.allocator;

    const client = try Client.init(allocator, "https://example.com/", .window);
    defer client.deinit();

    try std.testing.expect(!client.isDiscarded());

    client.discard();
    try std.testing.expect(client.isDiscarded());
}

test "WindowClient.init and deinit" {
    const allocator = std.testing.allocator;

    const client = try WindowClient.init(allocator, "https://example.com/", .top_level);
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com/", client.getUrl());
    try std.testing.expectEqual(FrameType.top_level, client.getFrameType());
    try std.testing.expectEqual(VisibilityState.hidden, client.getVisibilityState());
    try std.testing.expect(!client.isFocused());
}

test "WindowClient.visibility and focus" {
    const allocator = std.testing.allocator;

    const client = try WindowClient.init(allocator, "https://example.com/", .top_level);
    defer client.deinit();

    client.setVisibilityState(.visible);
    try std.testing.expectEqual(VisibilityState.visible, client.getVisibilityState());

    client.setFocused(true);
    try std.testing.expect(client.isFocused());
}

test "Client unique IDs" {
    const allocator = std.testing.allocator;

    const client1 = try Client.init(allocator, "https://example.com/", .window);
    defer client1.deinit();

    const client2 = try Client.init(allocator, "https://example.com/", .window);
    defer client2.deinit();

    try std.testing.expect(!std.mem.eql(u8, client1.getId(), client2.getId()));
}
