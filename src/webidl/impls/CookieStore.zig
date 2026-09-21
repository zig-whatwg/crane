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

// The Promise-returning operations build real V8 Promises, so this impl
// reaches for the engine directly - the same seam Blob.text() uses.
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;

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

// ============================================================================
// Query seam
//
// The jar is synchronous; everything asynchronous about this interface is the
// Promise wrapper. Keeping the query out of the V8 code makes it testable
// without an isolate - see tests/cookiestore/query_items_test.zig.
// ============================================================================

/// Query this store's jar. `null` matches every cookie.
///
/// https://cookiestore.spec.whatwg.org/#query-cookies
///
/// Caller owns the list and each item; pass both to `freeItems`.
pub fn queryItems(
    internal: *InternalState,
    name: ?[]const u8,
) !std.ArrayListUnmanaged(CookieListItem) {
    return cookiestore.queryCookies(
        internal.allocator,
        &internal.cookie_jar,
        internal.origin_host,
        "/",
        name,
    );
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
// Handle ownership follows the house rule (AGENTS.md): every `v8_*` call
// returning a pointer allocates a `Global<T>` the caller owns. Everything
// acquired here is disposed except the `Global<Promise>` handed back, which
// the return path in interface.zig consumes.
// ============================================================================

/// The current isolate and context, for the duration of one operation.
const Realm = struct {
    isolate: *v8.Isolate,
    context: *v8.Context,

    fn enter() error{NoRealm}!Realm {
        const isolate = v8.v8_Isolate_GetCurrent() orelse return error.NoRealm;
        const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoRealm;
        return .{ .isolate = isolate, .context = context };
    }

    /// `v8_Isolate_GetCurrentContext` allocated the Global we are holding.
    fn exit(self: Realm) void {
        v8.v8_Context_Dispose(self.context);
    }

    /// A settled promise carrying `value`, which the caller still owns.
    fn resolve(self: Realm, value: *v8.Value) error{OutOfMemory}!runtime.JSValue {
        const resolver = v8.v8_PromiseResolver_New(self.context) orelse return error.OutOfMemory;
        defer v8.v8_PromiseResolver_Dispose(resolver);

        const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse return error.OutOfMemory;
        _ = v8.v8_PromiseResolver_Resolve(resolver, self.context, value);
        return runtime.JSValue.fromPromise(@ptrCast(promise));
    }

    /// `Promise<undefined>` - what set() and delete() resolve with.
    fn resolveUndefined(self: Realm) error{OutOfMemory}!runtime.JSValue {
        const value = v8.v8_Undefined(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_Value_Dispose(value);
        return self.resolve(value);
    }

    /// `Promise<CookieListItem?>` resolving with null - get() found nothing.
    fn resolveNull(self: Realm) error{OutOfMemory}!runtime.JSValue {
        const value = v8.v8_Null(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_Value_Dispose(value);
        return self.resolve(value);
    }

    /// A rejected promise.
    ///
    /// Failures on this interface are rejections, never synchronous throws:
    /// the WPT suite reaches for `promise_rejects_js(t, TypeError, ...)`
    /// throughout, which only sees a promise.
    fn rejectTypeError(self: Realm, message: []const u8) error{OutOfMemory}!runtime.JSValue {
        const text = v8.v8_String_NewFromUtf8(
            self.isolate,
            message.ptr,
            @intCast(message.len),
        ) orelse return error.OutOfMemory;
        defer v8.v8_String_Dispose(text);

        const exception = v8.v8_Exception_TypeErrorInContext(self.context, text) orelse
            return error.OutOfMemory;
        defer v8.v8_Value_Dispose(exception);

        const resolver = v8.v8_PromiseResolver_New(self.context) orelse return error.OutOfMemory;
        defer v8.v8_PromiseResolver_Dispose(resolver);

        const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse return error.OutOfMemory;
        _ = v8.v8_PromiseResolver_Reject(resolver, self.context, exception);
        return runtime.JSValue.fromPromise(@ptrCast(promise));
    }

    /// Set one own string property on `object`.
    fn setString(self: Realm, object: *v8.Object, key: []const u8, value: []const u8) error{OutOfMemory}!void {
        const key_str = v8.v8_String_NewFromUtf8(self.isolate, key.ptr, @intCast(key.len)) orelse
            return error.OutOfMemory;
        defer v8.v8_String_Dispose(key_str);

        // An empty Zig slice has no usable `.ptr`, so the empty string gets its
        // own constructor. Cookies with an empty name or value are real - see
        // change_eventhandler_for_no_name_and_no_value.https.window.js.
        const value_str = if (value.len > 0)
            v8.v8_String_NewFromUtf8(self.isolate, value.ptr, @intCast(value.len)) orelse
                return error.OutOfMemory
        else
            v8.v8_String_Empty(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_String_Dispose(value_str);

        _ = v8.v8_Object_Set(object, self.context, @ptrCast(key_str), @ptrCast(value_str));
    }

    /// A `CookieListItem` as script sees it: `{ name, value }`.
    ///
    /// https://cookiestore.spec.whatwg.org/#create-a-cookielistitem
    ///
    /// The IDL dictionary carries only `name` and `value`; the attribute-rich
    /// form that `cookieListItem_attributes.https.any.js` expects (domain,
    /// path, expires, secure, sameSite) is not in specs/idl/cookiestore.idl,
    /// so it is not built here.
    fn cookieListItem(self: Realm, item: CookieListItem) error{OutOfMemory}!*v8.Object {
        const object = v8.v8_Object_NewInContext(self.context) orelse return error.OutOfMemory;
        errdefer v8.v8_Object_Dispose(object);

        try self.setString(object, "name", item.name);
        try self.setString(object, "value", item.value);
        return object;
    }

    /// A `CookieList` - a JS Array of CookieListItem objects.
    fn cookieList(self: Realm, items: []const CookieListItem) error{OutOfMemory}!*v8.Array {
        const array = v8.v8_Array_NewInContext(self.context, @intCast(items.len)) orelse
            return error.OutOfMemory;
        errdefer v8.v8_Array_Dispose(array);

        for (items, 0..) |item, index| {
            const object = try self.cookieListItem(item);
            defer v8.v8_Object_Dispose(object);
            _ = v8.v8_Array_Set(array, self.context, @intCast(index), @ptrCast(object));
        }
        return array;
    }
};

/// Operation: get(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-get
///
/// Resolves with a CookieListItem for the first matching cookie, or null.
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStore has no cookie jar");

    // Step 4: run query cookies with url and name.
    var items = queryItems(internal, nameFilter(name)) catch
        return realm.rejectTypeError("Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    // Step 5: resolve with the first item, or null when the list is empty.
    if (items.items.len == 0) return realm.resolveNull();

    const object = try realm.cookieListItem(items.items[0]);
    defer v8.v8_Object_Dispose(object);
    return realm.resolve(@ptrCast(object));
}

/// Operation: getAll(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-getall
///
/// Resolves with a CookieList - every matching cookie.
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStore has no cookie jar");

    var items = queryItems(internal, nameFilter(name)) catch
        return realm.rejectTypeError("Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    const array = try realm.cookieList(items.items);
    defer v8.v8_Array_Dispose(array);
    return realm.resolve(@ptrCast(array));
}

/// Operation: set(name, value)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-set
///
/// Resolves with undefined once the cookie is stored, and rejects with a
/// TypeError when the name/value pair fails validation.
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStore has no cookie jar");

    if (!internal.is_secure_context) {
        return realm.rejectTypeError("CookieStore.set requires a secure context");
    }

    cookiestore.setCookie(internal.allocator, &internal.cookie_jar, internal.origin_host, .{
        .name = name,
        .value = value,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => realm.rejectTypeError("Invalid cookie name or value"),
    };

    return realm.resolveUndefined();
}

/// Operation: delete(name)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-delete
///
/// Resolves with undefined. Deleting a cookie that is not there is not an
/// error - cookieStore_delete_basic.https.any.js asserts exactly that.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStore has no cookie jar");

    cookiestore.deleteCookie(internal.allocator, &internal.cookie_jar, internal.origin_host, .{
        .name = name,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => realm.rejectTypeError("Invalid cookie name"),
    };

    return realm.resolveUndefined();
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
