//! Implementation for CookieStoreManager interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The CookieStoreManager interface manages cookie change subscriptions for
//! Service Workers. It is accessed via ServiceWorkerRegistration.cookies.
//!
//! Methods:
//! - subscribe(subscriptions): Add cookie change subscriptions
//! - getSubscriptions(): Get current subscriptions
//! - unsubscribe(subscriptions): Remove cookie change subscriptions

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CookieStoreManager = interfaces.CookieStoreManager;

// The Promise-returning operations build real V8 Promises, so this impl
// reaches for the engine directly - the same seam Blob.text() uses.
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;

pub const State = CookieStoreManager.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    SecurityError,
    OutOfMemory,
};

/// A cookie subscription (matches CookieStoreGetOptions)
pub const CookieSubscription = struct {
    /// Cookie name to subscribe to (null = all cookies)
    name: ?[]const u8,
    /// URL to scope subscription to (null = registration scope)
    url: ?[]const u8,

    /// Allocator for owned strings
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: ?[]const u8, url: ?[]const u8) !Self {
        return Self{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .url = if (url) |u| try allocator.dupe(u8, u) else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.name) |n| self.allocator.free(n);
        if (self.url) |u| self.allocator.free(u);
        self.* = undefined;
    }

    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self.init(allocator, self.name, self.url);
    }

    /// Check if two subscriptions are equal (for deduplication)
    pub fn eql(self: Self, other: Self) bool {
        const name_eq = if (self.name) |n1| blk: {
            if (other.name) |n2| {
                break :blk std.mem.eql(u8, n1, n2);
            }
            break :blk false;
        } else other.name == null;

        const url_eq = if (self.url) |url1| blk: {
            if (other.url) |url2| {
                break :blk std.mem.eql(u8, url1, url2);
            }
            break :blk false;
        } else other.url == null;

        return name_eq and url_eq;
    }
};

/// Internal state for CookieStoreManager implementation
pub const InternalState = struct {
    /// List of active subscriptions
    subscriptions: std.ArrayListUnmanaged(CookieSubscription),

    /// The scope URL for this manager (from ServiceWorkerRegistration)
    scope_url: ?[]const u8,

    /// Whether this is in a secure context
    is_secure_context: bool,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, scope_url: ?[]const u8, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        errdefer allocator.destroy(internal);

        const scope_copy = if (scope_url) |s| try allocator.dupe(u8, s) else null;
        errdefer if (scope_copy) |s| allocator.free(s);

        internal.* = InternalState{
            .subscriptions = .empty,
            .scope_url = scope_copy,
            .is_secure_context = is_secure_context,
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        for (self.subscriptions.items) |*sub| {
            sub.deinit();
        }
        self.subscriptions.deinit(self.allocator);

        if (self.scope_url) |s| {
            self.allocator.free(s);
        }

        self.allocator.destroy(self);
    }

    /// Add a subscription (with deduplication)
    pub fn addSubscription(self: *InternalState, name: ?[]const u8, url: ?[]const u8) !void {
        // Check for duplicate
        for (self.subscriptions.items) |existing| {
            const new_sub = CookieSubscription{
                .name = name,
                .url = url,
                .allocator = self.allocator,
            };
            if (existing.eql(new_sub)) {
                return; // Already exists
            }
        }

        const sub = try CookieSubscription.init(self.allocator, name, url);
        try self.subscriptions.append(self.allocator, sub);
    }

    /// Remove a subscription
    pub fn removeSubscription(self: *InternalState, name: ?[]const u8, url: ?[]const u8) void {
        const to_remove = CookieSubscription{
            .name = name,
            .url = url,
            .allocator = self.allocator,
        };

        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            if (self.subscriptions.items[i].eql(to_remove)) {
                var removed = self.subscriptions.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Check if a URL is within the scope
    pub fn isWithinScope(self: *InternalState, url: []const u8) bool {
        const scope = self.scope_url orelse return true; // No scope = allow all
        return std.mem.startsWith(u8, url, scope);
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
    const internal = try InternalState.init(allocator, null, true);

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

// ============================================================================
// Promise plumbing
//
// All three operations are `Promise<T>` in cookiestore.idl. Returning
// `jsUndefined` from an impl does not produce a promise that resolves with
// undefined - the binding hands the value straight to JavaScript, so script
// gets the literal `undefined` and every `await` throws.
//
// Handle ownership follows the house rule (AGENTS.md): every `v8_*` call
// returning a pointer allocates a `Global<T>` the caller owns, so everything
// acquired here is disposed except the `Global<Promise>` handed back, which
// the return path in interface.zig consumes.
//
// The duplication with CookieStore.zig's `Realm` is deliberate: impls are
// private to each other (AGENTS.md, "The impls boundary"), and a shared helper
// would have to live outside `impls/`.
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

    /// `Promise<undefined>` - what subscribe() and unsubscribe() resolve with.
    fn resolveUndefined(self: Realm) error{OutOfMemory}!runtime.JSValue {
        const value = v8.v8_Undefined(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_Value_Dispose(value);
        return self.resolve(value);
    }

    /// A rejected promise. Failures here are rejections, never synchronous
    /// throws - cookieStore_subscribe_arguments.https.any.js asserts with
    /// `promise_rejects_js`, which only ever sees a promise.
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

    fn setString(self: Realm, object: *v8.Object, key: []const u8, value: []const u8) error{OutOfMemory}!void {
        const key_str = v8.v8_String_NewFromUtf8(self.isolate, key.ptr, @intCast(key.len)) orelse
            return error.OutOfMemory;
        defer v8.v8_String_Dispose(key_str);

        // An empty Zig slice has no usable `.ptr`, so the empty string needs
        // its own constructor.
        const value_str = if (value.len > 0)
            v8.v8_String_NewFromUtf8(self.isolate, value.ptr, @intCast(value.len)) orelse
                return error.OutOfMemory
        else
            v8.v8_String_Empty(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_String_Dispose(value_str);

        _ = v8.v8_Object_Set(object, self.context, @ptrCast(key_str), @ptrCast(value_str));
    }

    /// One subscription as a `CookieStoreGetOptions`: `{ name?, url? }`.
    /// Both members are optional in the IDL, so an absent one is left off the
    /// object rather than written as null.
    fn subscriptionObject(self: Realm, sub: CookieSubscription) error{OutOfMemory}!*v8.Object {
        const object = v8.v8_Object_NewInContext(self.context) orelse return error.OutOfMemory;
        errdefer v8.v8_Object_Dispose(object);

        if (sub.name) |name| try self.setString(object, "name", name);
        if (sub.url) |url| try self.setString(object, "url", url);
        return object;
    }

    /// A JS Array of CookieStoreGetOptions - getSubscriptions()'s answer.
    fn subscriptionList(self: Realm, subs: []const CookieSubscription) error{OutOfMemory}!*v8.Array {
        const array = v8.v8_Array_NewInContext(self.context, @intCast(subs.len)) orelse
            return error.OutOfMemory;
        errdefer v8.v8_Array_Dispose(array);

        for (subs, 0..) |sub, index| {
            const object = try self.subscriptionObject(sub);
            defer v8.v8_Object_Dispose(object);
            _ = v8.v8_Array_Set(array, self.context, @intCast(index), @ptrCast(object));
        }
        return array;
    }
};

/// Operation: subscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-subscribe
///
/// Add cookie change subscriptions. Each subscription specifies a name and/or
/// URL to watch for cookie changes.
pub fn call_subscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStoreManager has no subscription list");

    if (!internal.is_secure_context) {
        return realm.rejectTypeError("CookieStoreManager.subscribe requires a secure context");
    }

    // The subscriptions parameter is a sequence<CookieStoreGetOptions>.
    const subs_slice = webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    ) catch return realm.rejectTypeError("subscribe expects a sequence of CookieStoreGetOptions");

    for (subs_slice) |sub| {
        // A subscription URL must be inside the registration's scope.
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return realm.rejectTypeError("Subscription URL must be within the registration scope");
            }
        }

        internal.addSubscription(sub.name, sub.url) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    }

    return realm.resolveUndefined();
}

/// Operation: getSubscriptions()
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-getsubscriptions
///
/// Resolves with the current list of subscriptions, which is empty when
/// nothing has subscribed.
pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStoreManager has no subscription list");

    const array = try realm.subscriptionList(internal.subscriptions.items);
    defer v8.v8_Array_Dispose(array);
    return realm.resolve(@ptrCast(array));
}

/// Operation: unsubscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-unsubscribe
///
/// Remove cookie change subscriptions.
pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = try Realm.enter();
    defer realm.exit();

    const internal = getInternalState(instance) orelse
        return realm.rejectTypeError("CookieStoreManager has no subscription list");

    if (!internal.is_secure_context) {
        return realm.rejectTypeError("CookieStoreManager.unsubscribe requires a secure context");
    }

    const subs_slice = webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    ) catch return realm.rejectTypeError("unsubscribe expects a sequence of CookieStoreGetOptions");

    for (subs_slice) |sub| {
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return realm.rejectTypeError("Subscription URL must be within the registration scope");
            }
        }

        internal.removeSubscription(sub.name, sub.url);
    }

    return realm.resolveUndefined();
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new CookieStoreManager for a ServiceWorkerRegistration
/// This is used by ServiceWorkerRegistration to create its cookies attribute.
pub fn createForRegistration(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    scope_url: []const u8,
    is_secure_context: bool,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    const internal = try InternalState.init(allocator, scope_url, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Get the subscriptions list for external access
pub fn getSubscriptions(instance: *runtime.Instance) ?[]const CookieSubscription {
    if (getInternalState(instance)) |internal| {
        return internal.subscriptions.items;
    }
    return null;
}

/// Check if a cookie change matches any subscription
pub fn matchesSubscription(instance: *runtime.Instance, cookie_name: []const u8, cookie_url: []const u8) bool {
    const internal = getInternalState(instance) orelse return false;

    // No subscriptions = match nothing
    if (internal.subscriptions.items.len == 0) {
        return false;
    }

    for (internal.subscriptions.items) |sub| {
        // Check name match (null = match all)
        const name_matches = if (sub.name) |n| std.mem.eql(u8, n, cookie_name) else true;

        // Check URL match (null = match scope)
        const url_matches = if (sub.url) |u| std.mem.startsWith(u8, cookie_url, u) else true;

        if (name_matches and url_matches) {
            return true;
        }
    }

    return false;
}
