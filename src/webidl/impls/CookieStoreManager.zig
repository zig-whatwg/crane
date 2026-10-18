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
const cookiestore = @import("cookiestore");

// The Promise-returning operations make their promises and values through
// the engine protocol (cookie_values.zig).
const engine = @import("engine");
const cookie_values = @import("cookie_values.zig");

pub const State = CookieStoreManager.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    SecurityError,
    OutOfMemory,
};

/// A cookie subscription (matches CookieStoreGetOptions), and the internal
/// state for CookieStoreManager implementation: their types are the
/// cookiestore module's, testable without an engine; the state is this
/// manager's.
pub const CookieSubscription = cookiestore.CookieSubscription;
pub const InternalState = cookiestore.CookieStoreManagerState;

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
// Every value is made in the current realm - the realm of the operation
// called - through the engine protocol, and handed to the binding OWNED.
// ============================================================================

/// One subscription as a `CookieStoreGetOptions`: `{ name?, url? }`. Both
/// members are optional in the IDL, so an absent one is left off the object
/// rather than written as null. OWNED.
fn subscriptionObject(realm: runtime.Context, sub: CookieSubscription) engine.Error!engine.Owned {
    var members: [2]engine.DictionaryMember = undefined;
    var count: usize = 0;
    if (sub.name) |name| {
        members[count] = .{ .name = "name", .value = runtime.JSValue.fromStringRef(name) };
        count += 1;
    }
    if (sub.url) |url| {
        members[count] = .{ .name = "url", .value = runtime.JSValue.fromStringRef(url) };
        count += 1;
    }
    return engine.createDictionaryObject(realm, members[0..count]);
}

/// getSubscriptions()'s answer: `sequence<CookieStoreGetOptions>` as a new
/// Array. OWNED.
fn subscriptionList(realm: runtime.Context, subs: []const CookieSubscription, allocator: std.mem.Allocator) engine.Error!engine.Owned {
    const objects = allocator.alloc(engine.Owned, subs.len) catch return error.OutOfMemory;
    defer allocator.free(objects);
    var made: usize = 0;
    defer for (objects[0..made]) |object| object.release();
    for (subs, objects) |sub, *object| {
        object.* = try subscriptionObject(realm, sub);
        made += 1;
    }
    const values = allocator.alloc(runtime.JSValue, subs.len) catch return error.OutOfMemory;
    defer allocator.free(values);
    for (objects, values) |object, *value| value.* = object.value;
    return engine.createSequenceOfValues(realm, values);
}

/// Operation: subscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-subscribe
///
/// Add cookie change subscriptions. Each subscription specifies a name and/or
/// URL to watch for cookie changes.
pub fn call_subscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStoreManager has no subscription list");

    if (!internal.is_secure_context) {
        return cookie_values.rejectedWithTypeError(realm, "CookieStoreManager.subscribe requires a secure context");
    }

    // The subscriptions parameter is a sequence<CookieStoreGetOptions>.
    const subs_slice = webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    ) catch return cookie_values.rejectedWithTypeError(realm, "subscribe expects a sequence of CookieStoreGetOptions");

    for (subs_slice) |sub| {
        // A subscription URL must be inside the registration's scope.
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return cookie_values.rejectedWithTypeError(realm, "Subscription URL must be within the registration scope");
            }
        }

        internal.addSubscription(sub.name, sub.url) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
        };
    }

    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

/// Operation: getSubscriptions()
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-getsubscriptions
///
/// Resolves with the current list of subscriptions, which is empty when
/// nothing has subscribed.
pub fn call_getSubscriptions(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStoreManager has no subscription list");

    const list = try subscriptionList(realm, internal.subscriptions.items, internal.allocator);
    defer list.release();
    return cookie_values.resolvedWith(realm, list.value);
}

/// Operation: unsubscribe(subscriptions)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestoremanager-unsubscribe
///
/// Remove cookie change subscriptions.
pub fn call_unsubscribe(instance: *runtime.Instance, subscriptions: runtime.JSValue) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);

    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStoreManager has no subscription list");

    if (!internal.is_secure_context) {
        return cookie_values.rejectedWithTypeError(realm, "CookieStoreManager.unsubscribe requires a secure context");
    }

    const subs_slice = webidl.extractDictionarySlice(
        dictionaries.CookieStoreGetOptions,
        subscriptions.toAnyopaque(),
    ) catch return cookie_values.rejectedWithTypeError(realm, "unsubscribe expects a sequence of CookieStoreGetOptions");

    for (subs_slice) |sub| {
        if (sub.url) |url| {
            if (!internal.isWithinScope(url)) {
                return cookie_values.rejectedWithTypeError(realm, "Subscription URL must be within the registration scope");
            }
        }

        internal.removeSubscription(sub.name, sub.url);
    }

    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
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
