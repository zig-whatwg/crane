//! Cookie Store values as script sees them, made through the engine protocol
//! (AGENTS.md "The engine boundary"): a CookieListItem dictionary, a
//! CookieList sequence or FrozenArray, and the settled promises the
//! CookieStore and CookieStoreManager operations return.
//!
//! A helper shared by the four Cookie Store impls: nothing binds it. Every
//! value comes back OWNED (`engine.Owned`); an operation hands its result to
//! the binding with `take()`.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const cookiestore = @import("cookiestore");

const CookieListItem = cookiestore.CookieListItem;
const JSValue = runtime.JSValue;

/// Cookie Store "create a CookieListItem", as an ECMAScript value: the IDL
/// dictionary `CookieListItem { USVString name; USVString value; }`, members
/// in the dictionary's order. OWNED.
///
/// https://cookiestore.spec.whatwg.org/#create-a-cookielistitem
pub fn listItem(realm: runtime.Context, item: CookieListItem) engine.Error!engine.Owned {
    return engine.createDictionaryObject(realm, &.{
        .{ .name = "name", .value = JSValue.fromStringRef(item.name) },
        .{ .name = "value", .value = JSValue.fromStringRef(item.value) },
    });
}

/// The CookieListItem values of `items`, each OWNED; `releaseAll` ends them.
fn listItems(realm: runtime.Context, items: []const CookieListItem, allocator: std.mem.Allocator) engine.Error![]engine.Owned {
    const values = allocator.alloc(engine.Owned, items.len) catch return error.OutOfMemory;
    var made: usize = 0;
    errdefer {
        for (values[0..made]) |value| value.release();
        allocator.free(values);
    }
    for (items, values) |item, *value| {
        value.* = try listItem(realm, item);
        made += 1;
    }
    return values;
}

fn releaseAll(values: []const engine.Owned, allocator: std.mem.Allocator) void {
    for (values) |value| value.release();
    allocator.free(values);
}

/// Their values, BORROWED from `owned`, as a list an operation takes.
fn borrowAll(owned: []const engine.Owned, allocator: std.mem.Allocator) engine.Error![]JSValue {
    const values = allocator.alloc(JSValue, owned.len) catch return error.OutOfMemory;
    for (owned, values) |o, *value| value.* = o.value;
    return values;
}

/// A CookieList - `sequence<CookieListItem>` - as a new Array. OWNED.
pub fn list(realm: runtime.Context, items: []const CookieListItem, allocator: std.mem.Allocator) engine.Error!engine.Owned {
    const owned = try listItems(realm, items, allocator);
    defer releaseAll(owned, allocator);
    const values = try borrowAll(owned, allocator);
    defer allocator.free(values);
    return engine.createSequenceOfValues(realm, values);
}

/// A `FrozenArray<CookieListItem>`: WebIDL "create a frozen array" of the
/// list. OWNED.
pub fn frozenList(realm: runtime.Context, items: []const CookieListItem, allocator: std.mem.Allocator) engine.Error!engine.Owned {
    const owned = try listItems(realm, items, allocator);
    defer releaseAll(owned, allocator);
    const values = try borrowAll(owned, allocator);
    defer allocator.free(values);
    return engine.createFrozenArray(realm, values);
}

/// WebIDL "a promise resolved with" `value` (BORROWED), for the binding:
/// the promise is handed over.
pub fn resolvedWith(realm: runtime.Context, value: JSValue) engine.Error!JSValue {
    return (try engine.createResolvedPromise(realm, value)).take();
}

/// WebIDL "a promise rejected with" a new TypeError of `message`, for the
/// binding. Failures of the Cookie Store operations are rejections, never
/// synchronous throws: the WPT suite reaches for
/// `promise_rejects_js(t, TypeError, ...)` throughout.
pub fn rejectedWithTypeError(realm: runtime.Context, message: []const u8) engine.Error!JSValue {
    const exception = try engine.createSimpleException(realm, .TypeError, message);
    defer exception.release();
    return (try engine.createRejectedPromise(realm, exception.value)).take();
}

/// The realm an operation's promise is made in: the current realm (WebIDL
/// makes an operation's promise in the realm of the function called), else
/// the object's relevant realm.
pub fn operationRealm(instance: *runtime.Instance) runtime.Context {
    return engine.currentRealm() orelse instance.ctx;
}
