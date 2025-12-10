//! Implementation for CookieStore interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The CookieStore interface provides an asynchronous API for reading and
//! writing cookies. It is available in Window and ServiceWorker contexts
//! as a SecureContext-only feature.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const cookiestore = @import("cookiestore");

const CookieStore = interfaces.CookieStore;
const CookieJar = cookiestore.CookieJar;
const CookieChangeObserver = cookiestore.CookieChangeObserver;
const CookieListItem = cookiestore.CookieListItem;
const Cookie = cookiestore.Cookie;

pub const State = CookieStore.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    SecurityError,
    OutOfMemory,
};

/// Internal state for CookieStore implementation
pub const InternalState = struct {
    /// The origin URL host for this cookie store
    origin_host: []const u8,
    /// Whether this store is in a secure context
    is_secure_context: bool,
    /// The onchange event handler
    onchange_handler: ?*const anyopaque,
    /// Cookie jar for storage
    cookie_jar: CookieJar,
    /// Change observer for event dispatch
    change_observer: CookieChangeObserver,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, origin_host: []const u8, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const host_copy = try allocator.dupe(u8, origin_host);
        errdefer allocator.free(host_copy);

        internal.* = InternalState{
            .origin_host = host_copy,
            .is_secure_context = is_secure_context,
            .onchange_handler = null,
            .cookie_jar = CookieJar.init(allocator),
            .change_observer = CookieChangeObserver.init(allocator),
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        self.cookie_jar.deinit();
        self.change_observer.deinit();
        self.allocator.free(self.origin_host);
        self.allocator.destroy(self);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state with default values
    const internal = try InternalState.init(allocator, "localhost", true);

    // Store internal state pointer in state
    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
}

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Getter for onchange
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    _ = instance;
    // Return null event handler - event dispatch happens via change observer
    return null;
}

/// Setter for onchange
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    if (getInternalState(instance)) |internal| {
        internal.onchange_handler = value;
    }
}

/// Sentinel value representing "undefined" for Promise resolution
const undefined_sentinel: u8 = 0;

/// Operation: get(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-get
///
/// Returns a Promise that resolves with a CookieListItem for the first
/// matching cookie, or null if no cookie matches.
///
/// Note: The interface expects *const anyopaque for Promise-returning operations.
/// The V8 bindings handle Promise creation/resolution.
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Query cookies using the algorithms
    var items = try cookiestore.queryCookies(
        allocator,
        &internal.cookie_jar,
        internal.origin_host,
        "/",
        if (name.len > 0) name else null,
    );
    defer {
        for (items.items) |*item| item.deinit();
        items.deinit(allocator);
    }

    // Return first item or null
    if (items.items.len > 0) {
        // Clone the first item to return
        const result = try allocator.create(CookieListItem);
        result.* = try items.items[0].clone(allocator);
        return runtime.JSValue.fromAnyopaque(@ptrCast(result));
    }

    // Return undefined for "no cookie found"
    return runtime.JSValue.jsUndefined;
}

/// Operation: getAll(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-getall
///
/// Returns a Promise that resolves with a sequence of CookieListItem
/// for all matching cookies.
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Query cookies using the algorithms
    var items = try cookiestore.queryCookies(
        allocator,
        &internal.cookie_jar,
        internal.origin_host,
        "/",
        if (name.len > 0) name else null,
    );

    // Create a result array on the heap
    const result = try allocator.create(std.ArrayListUnmanaged(CookieListItem));
    result.* = items;
    // Prevent items from being cleaned up since we transferred ownership
    items = .{};

    return runtime.JSValue.fromAnyopaque(@ptrCast(result));
}

/// Operation: set(name, value)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-set
///
/// Returns a Promise that resolves when the cookie has been set.
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Check secure context requirement
    if (!internal.is_secure_context) {
        return error.SecurityError;
    }

    // Use setCookie algorithm
    try cookiestore.setCookie(allocator, &internal.cookie_jar, internal.origin_host, .{
        .name = name,
        .value = value,
    });

    // Return undefined for void Promise resolution
    return runtime.JSValue.jsUndefined;
}

/// Operation: delete(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-delete
///
/// Returns a Promise that resolves when the cookie has been deleted.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const allocator = internal.allocator;

    // Use deleteCookie algorithm
    try cookiestore.deleteCookie(allocator, &internal.cookie_jar, internal.origin_host, .{
        .name = name,
    });

    // Return undefined for void Promise resolution
    return runtime.JSValue.jsUndefined;
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new CookieStore for a given origin
/// This is used by Window and ServiceWorkerGlobalScope to create their
/// cookieStore attribute.
pub fn createForOrigin(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    origin_host: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    const internal = try InternalState.init(allocator, origin_host, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Get the cookie jar for direct access (used by Fetch API)
pub fn getCookieJar(instance: *runtime.Instance) ?*CookieJar {
    if (getInternalState(instance)) |internal| {
        return &internal.cookie_jar;
    }
    return null;
}

/// Get the change observer for event registration
pub fn getChangeObserver(instance: *runtime.Instance) ?*CookieChangeObserver {
    if (getInternalState(instance)) |internal| {
        return &internal.change_observer;
    }
    return null;
}
