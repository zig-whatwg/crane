//! Client and WindowClient WebIDL Interfaces
//!
//! Interfaces representing clients (pages/workers) that can be controlled
//! by service workers. These are used within ServiceWorkerGlobalScope.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#client-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface Client {
//!   readonly attribute USVString url;
//!   readonly attribute FrameType frameType;
//!   readonly attribute DOMString id;
//!   readonly attribute ClientType type;
//!   undefined postMessage(any message, sequence<object> transfer);
//!   undefined postMessage(any message, optional StructuredSerializeOptions options = {});
//! };
//!
//! [Exposed=ServiceWorker]
//! interface WindowClient : Client {
//!   readonly attribute VisibilityState visibilityState;
//!   readonly attribute boolean focused;
//!   [SameObject] readonly attribute FrozenArray<USVString> ancestorOrigins;
//!   [NewObject] Promise<WindowClient> focus();
//!   [NewObject] Promise<WindowClient?> navigate(USVString url);
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const types = @import("types.zig");
const ClientType = types.ClientType;
const FrameType = types.FrameType;
const VisibilityState = types.VisibilityState;
const StructuredSerializeOptions = types.StructuredSerializeOptions;
const Promise = types.Promise;

// Internal client structs
const internal_client = @import("../client.zig");
const InternalClient = internal_client.Client;
const InternalWindowClient = internal_client.WindowClient;

/// Client WebIDL interface.
///
/// Represents a client (page or worker) that can be controlled by a service worker.
/// This is exposed only within ServiceWorkerGlobalScope.
///
/// Spec: https://w3c.github.io/ServiceWorker/#client-interface
pub const ClientInterface = struct {
    allocator: Allocator,

    /// The underlying internal client.
    internal: *InternalClient,

    /// Whether this interface owns the internal client.
    owns_internal: bool = false,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a Client interface wrapping an internal client.
    pub fn init(allocator: Allocator, internal_client_ptr: *InternalClient) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_client_ptr,
            .owns_internal = false,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.owns_internal) {
            self.internal.deinit();
        }
        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the client URL.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#client-url
    pub fn getUrl(self: *const Self) []const u8 {
        return self.internal.url;
    }

    /// Get the frame type.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#client-frametype
    pub fn getFrameType(self: *const Self) FrameType {
        return self.internal.frame_type;
    }

    /// Get the frame type as string.
    pub fn getFrameTypeString(self: *const Self) []const u8 {
        return self.internal.frame_type.name();
    }

    /// Get the client ID.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#client-id
    pub fn getId(self: *const Self) []const u8 {
        return self.internal.id;
    }

    /// Get the client type.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#client-type
    pub fn getType(self: *const Self) ClientType {
        return self.internal.client_type;
    }

    /// Get the client type as string.
    pub fn getTypeString(self: *const Self) []const u8 {
        return self.internal.client_type.name();
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Post a message to the client.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#client-postmessage
    ///
    /// Note: This is a simplified implementation.
    pub fn postMessage(
        self: *Self,
        message: *anyopaque,
        options: StructuredSerializeOptions,
    ) !void {
        _ = message;
        _ = options;

        // Check if client is discarded
        if (self.internal.discarded) {
            return error.InvalidStateError;
        }

        // In a real implementation:
        // 1. Serialize the message
        // 2. Queue a task to dispatch MessageEvent to the client
    }

    /// Post a message with transfer list.
    pub fn postMessageWithTransfer(
        self: *Self,
        message: *anyopaque,
        transfer: []const *anyopaque,
    ) !void {
        try self.postMessage(message, .{ .transfer = transfer });
    }

    // =========================================================================
    // Internal Access
    // =========================================================================

    pub fn getInternal(self: *Self) *InternalClient {
        return self.internal;
    }
};

/// WindowClient WebIDL interface.
///
/// Extended client interface for window clients with focus and navigation capabilities.
///
/// Spec: https://w3c.github.io/ServiceWorker/#windowclient-interface
pub const WindowClientInterface = struct {
    allocator: Allocator,

    /// The underlying internal window client.
    internal: *InternalWindowClient,

    /// Whether this interface owns the internal client.
    owns_internal: bool = false,

    /// Cached ancestor origins array.
    ancestor_origins_cache: ?[]const []const u8 = null,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a WindowClient interface wrapping an internal window client.
    pub fn init(allocator: Allocator, internal_window_client: *InternalWindowClient) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .internal = internal_window_client,
            .owns_internal = false,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.owns_internal) {
            self.internal.deinit();
        }
        self.allocator.destroy(self);
    }

    // =========================================================================
    // Client Attributes (inherited)
    // =========================================================================

    pub fn getUrl(self: *const Self) []const u8 {
        return self.internal.getUrl();
    }

    pub fn getFrameType(self: *const Self) FrameType {
        return self.internal.getFrameType();
    }

    pub fn getFrameTypeString(self: *const Self) []const u8 {
        return self.internal.getFrameType().name();
    }

    pub fn getId(self: *const Self) []const u8 {
        return self.internal.getId();
    }

    pub fn getType(_: *const Self) ClientType {
        return .window;
    }

    pub fn getTypeString(_: *const Self) []const u8 {
        return "window";
    }

    // =========================================================================
    // WindowClient Attributes
    // =========================================================================

    /// Get the visibility state.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#windowclient-visibilitystate
    pub fn getVisibilityState(self: *const Self) VisibilityState {
        return self.internal.visibility_state;
    }

    /// Get the visibility state as string.
    pub fn getVisibilityStateString(self: *const Self) []const u8 {
        return self.internal.visibility_state.name();
    }

    /// Check if the window is focused.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#windowclient-focused
    pub fn isFocused(self: *const Self) bool {
        return self.internal.focused;
    }

    /// Get the ancestor origins.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#windowclient-ancestororigins
    pub fn getAncestorOrigins(self: *const Self) []const []const u8 {
        return self.internal.ancestor_origins;
    }

    // =========================================================================
    // WindowClient Methods
    // =========================================================================

    /// Focus the window.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#windowclient-focus
    ///
    /// Note: This requires user activation in real implementations.
    pub fn focus(self: *Self) Promise(*Self) {
        var promise = Promise(*Self).init();

        // Check if client is discarded
        if (self.internal.base.discarded) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // In a real implementation:
        // 1. Check for user activation
        // 2. Focus the window's browsing context
        // 3. Resolve with this WindowClient

        // For now, just update the internal state
        self.internal.setFocused(true);
        self.internal.setVisibilityState(.visible);
        promise.resolve(self);

        return promise;
    }

    /// Navigate the window to a URL.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#windowclient-navigate
    pub fn navigate(self: *Self, url: []const u8) Promise(?*Self) {
        // URL will be used in full implementation
        _ = url;

        var promise = Promise(?*Self).init();

        // Check if client is discarded
        if (self.internal.base.discarded) {
            promise.reject(error.InvalidStateError);
            return promise;
        }

        // In a real implementation:
        // 1. Parse the URL
        // 2. Navigate the window's browsing context
        // 3. Resolve with this WindowClient or null

        // For now, just resolve with self
        promise.resolve(self);

        return promise;
    }

    /// Post a message (inherited from Client).
    pub fn postMessage(
        self: *Self,
        message: *anyopaque,
        options: StructuredSerializeOptions,
    ) !void {
        _ = message;
        _ = options;

        if (self.internal.base.discarded) {
            return error.InvalidStateError;
        }

        // Stub implementation
    }

    // =========================================================================
    // Internal Access
    // =========================================================================

    pub fn getInternal(self: *Self) *InternalWindowClient {
        return self.internal;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "ClientInterface.init" {
    const allocator = std.testing.allocator;

    const internal = try InternalClient.init(allocator, "https://example.com/page.html", .window);
    defer internal.deinit();

    const client = try ClientInterface.init(allocator, internal);
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com/page.html", client.getUrl());
    try std.testing.expectEqual(ClientType.window, client.getType());
    try std.testing.expectEqualStrings("window", client.getTypeString());
}

test "ClientInterface.postMessage" {
    const allocator = std.testing.allocator;

    const internal = try InternalClient.init(allocator, "https://example.com/page.html", .window);
    defer internal.deinit();

    const client = try ClientInterface.init(allocator, internal);
    defer client.deinit();

    var dummy: u8 = 0;

    // Should succeed on non-discarded client
    try client.postMessage(&dummy, .{});

    // Should fail on discarded client
    internal.discard();
    const result = client.postMessage(&dummy, .{});
    try std.testing.expectError(error.InvalidStateError, result);
}

test "WindowClientInterface.init" {
    const allocator = std.testing.allocator;

    const internal = try InternalWindowClient.init(allocator, "https://example.com/page.html", .top_level);
    defer internal.deinit();

    const client = try WindowClientInterface.init(allocator, internal);
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com/page.html", client.getUrl());
    try std.testing.expectEqual(FrameType.top_level, client.getFrameType());
    try std.testing.expectEqual(VisibilityState.hidden, client.getVisibilityState());
    try std.testing.expect(!client.isFocused());
}

test "WindowClientInterface.focus" {
    const allocator = std.testing.allocator;

    const internal = try InternalWindowClient.init(allocator, "https://example.com/page.html", .top_level);
    defer internal.deinit();

    const client = try WindowClientInterface.init(allocator, internal);
    defer client.deinit();

    try std.testing.expect(!client.isFocused());
    try std.testing.expectEqual(VisibilityState.hidden, client.getVisibilityState());

    const promise = client.focus();
    try std.testing.expect(promise.isFulfilled());

    // After focus, should be focused and visible
    try std.testing.expect(client.isFocused());
    try std.testing.expectEqual(VisibilityState.visible, client.getVisibilityState());
}

test "WindowClientInterface.navigate" {
    const allocator = std.testing.allocator;

    const internal = try InternalWindowClient.init(allocator, "https://example.com/page.html", .top_level);
    defer internal.deinit();

    const client = try WindowClientInterface.init(allocator, internal);
    defer client.deinit();

    const promise = client.navigate("https://example.com/other.html");
    try std.testing.expect(promise.isFulfilled());
    try std.testing.expectEqual(client, promise.value.?.?);
}
