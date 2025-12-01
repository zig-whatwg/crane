//! FetchEvent
//!
//! Event fired when a service worker intercepts a fetch request.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#fetchevent-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=ServiceWorker]
//! interface FetchEvent : ExtendableEvent {
//!   constructor(DOMString type, FetchEventInit eventInitDict);
//!   [SameObject] readonly attribute Request request;
//!   [SameObject] readonly attribute Promise<any> preloadResponse;
//!   readonly attribute DOMString clientId;
//!   readonly attribute DOMString resultingClientId;
//!   readonly attribute DOMString replacesClientId;
//!   readonly attribute Promise<undefined> handled;
//!
//!   undefined respondWith(Promise<Response> r);
//!   undefined addRoutes(sequence<RouterRule> rules);
//! };
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

const ExtendableEvent = @import("extendable_event.zig").ExtendableEvent;
const ExtendableEventInit = @import("extendable_event.zig").ExtendableEventInit;

const router = @import("router.zig");
const RouterRule = router.RouterRule;

const iface_types = @import("../interfaces/types.zig");
const Promise = iface_types.Promise;
const VoidPromise = iface_types.VoidPromise;

/// FetchEvent initialization options.
pub const FetchEventInit = struct {
    /// The intercepted request (required).
    request: *anyopaque,

    /// ID of the client that initiated the request.
    client_id: []const u8 = "",

    /// ID of the client being navigated to (for navigations).
    resulting_client_id: []const u8 = "",

    /// ID of the client being replaced (for navigations).
    replaces_client_id: []const u8 = "",

    /// Promise for navigation preload response.
    preload_response: ?*anyopaque = null,

    /// Promise that resolves when the event is handled.
    handled: ?*anyopaque = null,

    /// Base event options.
    event_init: ExtendableEventInit = .{},
};

/// Stored response from respondWith().
pub const StoredResponse = struct {
    /// The response object.
    response: *anyopaque,
    /// Whether this is an error response.
    is_error: bool = false,
    /// Error message if error response.
    error_message: ?[]const u8 = null,
};

/// FetchEvent.
///
/// Fired when a service worker intercepts a network request.
/// The service worker can respond using respondWith().
///
/// Spec: https://w3c.github.io/ServiceWorker/#fetchevent-interface
pub const FetchEvent = struct {
    allocator: Allocator,

    /// Base ExtendableEvent.
    base: *ExtendableEvent,
    owns_base: bool = false,

    /// The intercepted request.
    request: *anyopaque,

    /// Navigation preload response promise (if preload enabled).
    preload_response: ?*anyopaque = null,

    /// ID of the client that initiated the request.
    client_id: []const u8,

    /// ID of the client being navigated to.
    resulting_client_id: []const u8,

    /// ID of the client being replaced.
    replaces_client_id: []const u8,

    /// Whether respondWith() has been called.
    respond_with_called: bool = false,

    /// Whether we're waiting for a response.
    wait_to_respond: bool = false,

    /// The response provided via respondWith().
    stored_response: ?StoredResponse = null,

    /// Router rules added via addRoutes().
    added_routes: std.ArrayListUnmanaged(RouterRule),

    /// Promise that resolves when the event is handled.
    handled_promise: VoidPromise,

    const Self = @This();

    // =========================================================================
    // Construction
    // =========================================================================

    /// Create a new FetchEvent.
    pub fn init(allocator: Allocator, options: FetchEventInit) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Create base ExtendableEvent
        const base = try ExtendableEvent.init(allocator, "fetch", options.event_init);
        errdefer base.deinit();

        const client_id_copy = try allocator.dupe(u8, options.client_id);
        errdefer allocator.free(client_id_copy);

        const resulting_id_copy = try allocator.dupe(u8, options.resulting_client_id);
        errdefer allocator.free(resulting_id_copy);

        const replaces_id_copy = try allocator.dupe(u8, options.replaces_client_id);

        self.* = .{
            .allocator = allocator,
            .base = base,
            .owns_base = true,
            .request = options.request,
            .preload_response = options.preload_response,
            .client_id = client_id_copy,
            .resulting_client_id = resulting_id_copy,
            .replaces_client_id = replaces_id_copy,
            .added_routes = .{},
            .handled_promise = VoidPromise.init(),
        };

        return self;
    }

    pub fn deinit(self: *Self) void {
        // Free stored response error message
        if (self.stored_response) |resp| {
            if (resp.error_message) |msg| {
                self.allocator.free(msg);
            }
        }

        self.added_routes.deinit(self.allocator);
        self.allocator.free(self.client_id);
        self.allocator.free(self.resulting_client_id);
        self.allocator.free(self.replaces_client_id);

        if (self.owns_base) {
            self.base.deinit();
        }

        self.allocator.destroy(self);
    }

    // =========================================================================
    // WebIDL Attributes
    // =========================================================================

    /// Get the intercepted request.
    pub fn getRequest(self: *const Self) *anyopaque {
        return self.request;
    }

    /// Get the preload response promise.
    pub fn getPreloadResponse(self: *const Self) ?*anyopaque {
        return self.preload_response;
    }

    /// Get the client ID.
    pub fn getClientId(self: *const Self) []const u8 {
        return self.client_id;
    }

    /// Get the resulting client ID.
    pub fn getResultingClientId(self: *const Self) []const u8 {
        return self.resulting_client_id;
    }

    /// Get the replaces client ID.
    pub fn getReplacesClientId(self: *const Self) []const u8 {
        return self.replaces_client_id;
    }

    /// Get the handled promise.
    pub fn getHandled(self: *Self) *VoidPromise {
        return &self.handled_promise;
    }

    // =========================================================================
    // WebIDL Methods
    // =========================================================================

    /// Respond to the fetch with a custom response.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#fetch-event-respondwith
    ///
    /// Steps:
    /// 1. If respond_with_called is true, throw InvalidStateError
    /// 2. If dispatch flag is false, throw InvalidStateError
    /// 3. Set respond_with_called to true
    /// 4. Set wait_to_respond to true
    /// 5. Add response promise to extend_lifetime_promises
    pub fn respondWith(self: *Self, response: *anyopaque) !void {
        // Step 1: Check if already called
        if (self.respond_with_called) {
            return error.InvalidStateError;
        }

        // Step 2: Check if still dispatching
        if (!self.base.dispatch_flag) {
            return error.InvalidStateError;
        }

        // Step 3: Mark as called
        self.respond_with_called = true;

        // Step 4: Set wait flag
        self.wait_to_respond = true;

        // Step 5: Add to lifetime promises
        _ = try self.base.waitUntil();

        // Store the response
        self.stored_response = .{
            .response = response,
        };
    }

    /// Mark the response as rejected.
    pub fn rejectResponse(self: *Self, error_message: []const u8) void {
        if (self.stored_response) |*resp| {
            resp.is_error = true;
            resp.error_message = self.allocator.dupe(u8, error_message) catch null;
        } else {
            self.stored_response = .{
                .response = undefined,
                .is_error = true,
                .error_message = self.allocator.dupe(u8, error_message) catch null,
            };
        }
        self.wait_to_respond = false;

        // Reject handled promise
        self.handled_promise.reject(error.ResponseRejected);
    }

    /// Mark the response as resolved.
    pub fn resolveResponse(self: *Self) void {
        self.wait_to_respond = false;
        self.handled_promise.resolve({});
    }

    /// Add router rules during fetch event handling.
    ///
    /// Spec: https://w3c.github.io/ServiceWorker/#fetch-event-addroutes
    pub fn addRoutes(self: *Self, rules: []const RouterRule) !void {
        for (rules) |rule| {
            try self.added_routes.append(self.allocator, rule);
        }
    }

    // =========================================================================
    // State Queries
    // =========================================================================

    /// Check if respondWith was called.
    pub fn wasRespondWithCalled(self: *const Self) bool {
        return self.respond_with_called;
    }

    /// Check if waiting for response.
    pub fn isWaitingForResponse(self: *const Self) bool {
        return self.wait_to_respond;
    }

    /// Get the stored response (if respondWith was called).
    pub fn getStoredResponse(self: *const Self) ?StoredResponse {
        return self.stored_response;
    }

    /// Check if the response was an error.
    pub fn isResponseError(self: *const Self) bool {
        if (self.stored_response) |resp| {
            return resp.is_error;
        }
        return false;
    }

    /// Get added routes.
    pub fn getAddedRoutes(self: *const Self) []const RouterRule {
        return self.added_routes.items;
    }

    // =========================================================================
    // Delegated to ExtendableEvent
    // =========================================================================

    pub fn waitUntil(self: *Self) !u64 {
        return self.base.waitUntil();
    }

    pub fn resolvePromise(self: *Self, promise_id: u64) void {
        self.base.resolvePromise(promise_id);
    }

    pub fn rejectPromise(self: *Self, promise_id: u64, msg: ?[]const u8) void {
        self.base.rejectPromise(promise_id, msg);
    }

    pub fn startDispatch(self: *Self, target_ptr: *anyopaque) void {
        self.base.startDispatch(target_ptr);
    }

    pub fn endDispatch(self: *Self) void {
        self.base.endDispatch();
    }

    pub fn isComplete(self: *const Self) bool {
        return self.base.isComplete() and !self.wait_to_respond;
    }

    pub fn canExtend(self: *const Self) bool {
        return self.base.canExtend();
    }

    pub fn getType(self: *const Self) []const u8 {
        return self.base.getType();
    }
};

// =============================================================================
// Tests
// =============================================================================

test "FetchEvent.init and deinit" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
        .client_id = "client-123",
    });
    defer event.deinit();

    try std.testing.expectEqualStrings("fetch", event.getType());
    try std.testing.expectEqualStrings("client-123", event.getClientId());
    try std.testing.expect(!event.wasRespondWithCalled());
}

test "FetchEvent.respondWith" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    var dummy_response: u8 = 1;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    // Start dispatch
    var dummy_target: u8 = 2;
    event.startDispatch(&dummy_target);

    // Call respondWith
    try event.respondWith(&dummy_response);

    try std.testing.expect(event.wasRespondWithCalled());
    try std.testing.expect(event.isWaitingForResponse());
    try std.testing.expect(event.getStoredResponse() != null);
}

test "FetchEvent.respondWith fails if already called" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    var dummy_response: u8 = 1;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    var dummy_target: u8 = 2;
    event.startDispatch(&dummy_target);

    // First call succeeds
    try event.respondWith(&dummy_response);

    // Second call fails
    const result = event.respondWith(&dummy_response);
    try std.testing.expectError(error.InvalidStateError, result);
}

test "FetchEvent.respondWith fails if not dispatching" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    var dummy_response: u8 = 1;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    // Don't start dispatch - respondWith should fail
    const result = event.respondWith(&dummy_response);
    try std.testing.expectError(error.InvalidStateError, result);
}

test "FetchEvent.resolveResponse" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    var dummy_response: u8 = 1;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    var dummy_target: u8 = 2;
    event.startDispatch(&dummy_target);
    try event.respondWith(&dummy_response);

    try std.testing.expect(event.isWaitingForResponse());

    event.resolveResponse();

    try std.testing.expect(!event.isWaitingForResponse());
    try std.testing.expect(event.handled_promise.isFulfilled());
}

test "FetchEvent.rejectResponse" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;
    var dummy_response: u8 = 1;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    var dummy_target: u8 = 2;
    event.startDispatch(&dummy_target);
    try event.respondWith(&dummy_response);

    event.rejectResponse("Network error");

    try std.testing.expect(!event.isWaitingForResponse());
    try std.testing.expect(event.isResponseError());
    try std.testing.expect(event.handled_promise.isRejected());
}

test "FetchEvent.addRoutes" {
    const allocator = std.testing.allocator;

    var dummy_request: u8 = 0;

    const event = try FetchEvent.init(allocator, .{
        .request = &dummy_request,
    });
    defer event.deinit();

    const rules = [_]RouterRule{
        .{ .condition = .{ .url_pattern = .{} }, .source = .network },
    };

    try event.addRoutes(&rules);

    try std.testing.expectEqual(@as(usize, 1), event.getAddedRoutes().len);
}
