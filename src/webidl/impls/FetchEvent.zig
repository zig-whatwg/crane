//! Implementation for FetchEvent interface
//!
//! FetchEvent is dispatched when a service worker intercepts a fetch request.
//! This implementation stores the event data and provides the WebIDL API.
//!
//! The actual service_worker FetchEvent (in src/service_worker/events/) handles
//! the algorithm logic. This WebIDL impl provides the JavaScript-facing API.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const FetchEvent = interfaces.FetchEvent;

pub const State = FetchEvent.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
    TypeError,
};

/// Internal state for FetchEvent - stores the event data
pub const InternalState = struct {
    /// The intercepted Request instance
    request: *runtime.Instance,
    /// Client ID string
    client_id: runtime.DOMString = .{ .empty = {} },
    /// Resulting client ID for navigations
    resulting_client_id: runtime.DOMString = .{ .empty = {} },
    /// Replaces client ID for navigations
    replaces_client_id: runtime.DOMString = .{ .empty = {} },
    /// Preload response promise (if navigation preload is enabled)
    preload_response: runtime.JSValue = .{ .undefined = {} },
    /// The handled promise - resolves when event is fully handled
    handled_promise: runtime.JSValue = .{ .undefined = {} },
    /// Whether respondWith() has been called
    respond_with_called: bool = false,
    /// Whether the event is currently being dispatched
    dispatch_flag: bool = false,
    /// The response provided via respondWith()
    response_promise: runtime.JSValue = .{ .undefined = {} },
    /// Allocator for owned strings
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.client_id.deinit(self.allocator);
        self.resulting_client_id.deinit(self.allocator);
        self.replaces_client_id.deinit(self.allocator);
    }
};

/// Registry to map runtime instances to internal state
var registry: std.AutoHashMapUnmanaged(*runtime.Instance, *InternalState) = .{};
var registry_allocator: ?std.mem.Allocator = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMapUnmanaged(*runtime.Instance, *InternalState) {
    if (registry_allocator == null) {
        registry_allocator = allocator;
    }
    return &registry;
}

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const reg = getRegistry(std.heap.page_allocator);
    if (reg.get(instance)) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        _ = reg.remove(instance);
    }
}

/// Constructor implementation
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: dictionaries.FetchEventInit) !*runtime.Instance {
    const allocator = ctx.allocator;

    _ = @"type"; // Event type is always "fetch"

    // Create instance
    const instance = try init(allocator, State, &FetchEvent.vtable, ctx);
    errdefer deinit(instance);

    // Create internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // Initialize with values from dict
    internal.* = .{
        .allocator = allocator,
        .request = eventInitDict.request,
    };

    // Copy client IDs (duplicate strings since they need to outlive the dict)
    if (eventInitDict.clientId) |cid| {
        internal.client_id = try runtime.DOMString.initDupe(allocator, cid.asSlice());
    }
    if (eventInitDict.resultingClientId) |rcid| {
        internal.resulting_client_id = try runtime.DOMString.initDupe(allocator, rcid.asSlice());
    }
    if (eventInitDict.replacesClientId) |rpcid| {
        internal.replaces_client_id = try runtime.DOMString.initDupe(allocator, rpcid.asSlice());
    }

    // Copy promise references
    if (eventInitDict.preloadResponse) |pr| {
        internal.preload_response = pr;
    }
    if (eventInitDict.handled) |h| {
        internal.handled_promise = h;
    }

    // Register the mapping
    const reg = getRegistry(allocator);
    try reg.put(allocator, instance, internal);

    return instance;
}

/// Get the internal state for an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const reg = getRegistry(std.heap.page_allocator);
    return reg.get(instance);
}

/// Getter for request
pub fn get_request(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.request;
}

/// Getter for preloadResponse
pub fn get_preloadResponse(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.preload_response;
}

/// Getter for clientId
pub fn get_clientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.client_id;
}

/// Getter for resultingClientId
pub fn get_resultingClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.resulting_client_id;
}

/// Getter for replacesClientId
pub fn get_replacesClientId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.replaces_client_id;
}

/// Getter for handled
pub fn get_handled(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.handled_promise;
}

/// Operation: respondWith
/// Spec: https://w3c.github.io/ServiceWorker/#fetch-event-respondwith
pub fn call_respondWith(instance: *runtime.Instance, r: runtime.JSValue) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If respond_with_called is true, throw InvalidStateError
    if (internal.respond_with_called) {
        return error.InvalidStateError;
    }

    // Step 2: If dispatch flag is false, throw InvalidStateError
    if (!internal.dispatch_flag) {
        return error.InvalidStateError;
    }

    // Step 3: Mark as called
    internal.respond_with_called = true;

    // Step 4-5: Store the response promise
    internal.response_promise = r;
}

// =============================================================================
// Internal API for service_worker integration
// =============================================================================

/// Set the dispatch flag (called when event dispatch starts)
pub fn setDispatchFlag(instance: *runtime.Instance, flag: bool) void {
    if (getInternal(instance)) |internal| {
        internal.dispatch_flag = flag;
    }
}

/// Check if respondWith was called
pub fn wasRespondWithCalled(instance: *runtime.Instance) bool {
    if (getInternal(instance)) |internal| {
        return internal.respond_with_called;
    }
    return false;
}

/// Get the response promise (if respondWith was called)
pub fn getResponsePromise(instance: *runtime.Instance) ?runtime.JSValue {
    if (getInternal(instance)) |internal| {
        if (internal.response_promise != .undefined) {
            return internal.response_promise;
        }
    }
    return null;
}
