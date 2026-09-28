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

// The Promise-returning operations make their promises and values through
// the engine protocol (cookie_values.zig).
const cookie_values = @import("cookie_values.zig");

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
///
/// The cookies are not here: they are the user agent's, in the jar this
/// store's relevant settings object reaches (`clientOf`), which fetch,
/// navigations and document.cookie use too.
pub const InternalState = struct {
    /// Whether this store is in a secure context
    is_secure_context: bool,
    /// The onchange event handler
    onchange_handler: ?*const anyopaque,
    /// Change observer for event dispatch
    change_observer: CookieChangeObserver,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .is_secure_context = is_secure_context,
            .onchange_handler = null,
            .change_observer = CookieChangeObserver.init(allocator),
            .allocator = allocator,
        };
        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        self.change_observer.deinit();
        self.allocator.destroy(self);
    }
};

/// This store's relevant settings object, as the Cookie Store algorithms
/// read it: the user agent's cookie jar, its creation URL, and whether its
/// origin is opaque.
const Client = struct {
    jar: *CookieJar,
    /// The creation URL, serialized - the realm's document URL (a worker's
    /// is its script URL). Borrowed from the realm.
    url: []const u8,
    opaque_origin: bool,
};

/// `instance`'s relevant settings object as a `Client`, or null for one
/// that reaches no jar (a realm no Browser made) or has no URL yet.
fn clientOf(instance: *runtime.Instance) ?Client {
    const record = instance.ctx.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const global_settings = @import("dom").global_settings;
    const jar = global_settings.cookieJarOf(global) orelse return null;
    const url = instance.ctx.documentUrl() orelse return null;
    const settings = global_settings.of(global) orelse return null;
    const origin = settings.origin(global) catch return null;
    defer global.ctx.allocator.free(origin);
    return .{ .jar = jar, .url = url, .opaque_origin = std.mem.eql(u8, origin, "null") };
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state with default values
    const internal = try InternalState.init(allocator, true);

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

// ============================================================================
// Query seam
//
// The jar is synchronous; everything asynchronous about this interface is the
// Promise wrapper. Keeping the query out of the V8 code makes it testable
// without an isolate - see tests/cookiestore/query_items_test.zig.
// ============================================================================

/// Cookie Store "query cookies" given `url` (serialized) and `name`:
/// `jar`'s cookies for the URL as a "non-HTTP" API sees them - no HttpOnly
/// cookie - those named `name`, or all for null.
///
/// https://cookiestore.spec.whatwg.org/#query-cookies
///
/// Caller owns the list and each item; pass both to `freeItems`.
pub fn queryItems(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    url: []const u8,
    name: ?[]const u8,
) !std.ArrayListUnmanaged(CookieListItem) {
    const parts = cookiestore.RequestUrl.of(url) orelse return .empty;
    return cookiestore.queryCookies(allocator, jar, parts.host, parts.path, name);
}

/// Release a list returned by `queryItems`.
pub fn freeItems(
    allocator: std.mem.Allocator,
    items: *std.ArrayListUnmanaged(CookieListItem),
) void {
    for (items.items) |*item| item.deinit();
    items.deinit(allocator);
}

/// Turn the `name` argument of get()/getAll() into a query filter.
///
/// An omitted argument and an empty string arrive here identically: the
/// binding defaults a missing `USVString` to an empty slice (see
/// `getDefaultArgValue` in src/runtime/engines/v8/interface.zig), and only the
/// `CookieStoreGetOptions` overload - which codegen has not produced - could
/// tell them apart. `getAll()` with no argument is the common case and means
/// "every cookie", so the empty string is read as the wildcard.
pub fn nameFilter(name: runtime.USVString) ?[]const u8 {
    return if (name.len > 0) name else null;
}

// ============================================================================
// Promise plumbing
//
// Every operation below is `Promise<T>` in cookiestore.idl. The binding hands
// whatever an impl returns straight to JavaScript, so returning `jsUndefined`
// here does not mean "a promise that resolves with undefined" - it means the
// literal value `undefined`, and every `await` in the WPT suite then throws
// "Cannot read properties of undefined (reading 'then')".
//
// The jar answers synchronously, so each promise is already settled when it is
// returned. That is indistinguishable from an asynchronous jar to script: an
// `await` still yields to the microtask queue.
//
// Every value is made in the current realm - the realm of the operation
// called - through the engine protocol, and handed to the binding OWNED.
// ============================================================================

/// Operation: get(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-get
///
/// Resolves with a CookieListItem for the first matching cookie, or null.
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    // Steps 1-4: the relevant settings object; an opaque origin rejects
    // with a SecurityError; its creation URL is the one queried.
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");

    // Step 6.1: run query cookies with url and name.
    var items = queryItems(internal.allocator, client.jar, client.url, nameFilter(name)) catch
        return cookie_values.rejectedWithTypeError(realm, "Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    // Step 5: resolve with the first item, or null when the list is empty.
    if (items.items.len == 0) return cookie_values.resolvedWith(realm, runtime.JSValue.jsNull);

    const item = try cookie_values.listItem(realm, items.items[0]);
    defer item.release();
    return cookie_values.resolvedWith(realm, item.value);
}

/// Operation: getAll(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-getall
///
/// Resolves with a CookieList - every matching cookie.
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    // Steps 1-4, as get().
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");

    var items = queryItems(internal.allocator, client.jar, client.url, nameFilter(name)) catch
        return cookie_values.rejectedWithTypeError(realm, "Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    const list = try cookie_values.list(realm, items.items, internal.allocator);
    defer list.release();
    return cookie_values.resolvedWith(realm, list.value);
}

/// Operation: set(name, value)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-set
///
/// Resolves with undefined once the cookie is stored, and rejects with a
/// TypeError when the name/value pair fails validation.
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");

    if (!internal.is_secure_context) {
        return cookie_values.rejectedWithTypeError(realm, "CookieStore.set requires a secure context");
    }
    // Steps 1-4, as get().
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");
    const url = cookiestore.RequestUrl.of(client.url) orelse
        return cookie_values.rejectedWithTypeError(realm, "Cookies are kept only for HTTP(S) URLs");

    // Step 6.1: set a cookie with url, name, value, and the defaults.
    cookiestore.setCookieObserved(internal.allocator, client.jar, &internal.change_observer, url.host, .{
        .name = name,
        .value = value,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => cookie_values.rejectedWithTypeError(realm, "Invalid cookie name or value"),
    };

    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

/// Operation: delete(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-delete
///
/// Resolves with undefined. Deleting a cookie that is not there is not an
/// error - cookieStore_delete_basic.https.any.js asserts exactly that.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    // Steps 1-4, as get().
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");
    const url = cookiestore.RequestUrl.of(client.url) orelse
        return cookie_values.rejectedWithTypeError(realm, "Cookies are kept only for HTTP(S) URLs");

    // Step 6.1: delete a cookie with url, name, null, "/" and true.
    cookiestore.deleteCookieObserved(internal.allocator, client.jar, &internal.change_observer, url.host, .{
        .name = name,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => cookie_values.rejectedWithTypeError(realm, "Invalid cookie name"),
    };

    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new CookieStore for a given origin
/// This is used by Window and ServiceWorkerGlobalScope to create their
/// cookieStore attribute.
///
/// `origin_host` is not read: every operation reads the store's relevant
/// settings object - its jar, creation URL and origin - when it runs.
/// (Window passed its serialized origin here as a host.)
pub fn createForOrigin(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    origin_host: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    _ = origin_host;
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    const internal = try InternalState.init(allocator, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Get the change observer for event registration
pub fn getChangeObserver(instance: *runtime.Instance) ?*CookieChangeObserver {
    if (getInternalState(instance)) |internal| {
        return &internal.change_observer;
    }
    return null;
}
