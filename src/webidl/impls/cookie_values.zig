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
    // A member that is not present is not converted: a deleted cookie's
    // item has no `value` (Cookie Store "prepare lists from changes").
    if (!item.has_value) return engine.createDictionaryObject(realm, &.{
        .{ .name = "name", .value = JSValue.fromStringRef(item.name) },
    });
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

/// WebIDL "a promise rejected with" a new DOMException named `name`, for
/// the binding - an opaque origin's "SecurityError".
pub fn rejectedWithDOMException(realm: runtime.Context, name: []const u8, message: []const u8) engine.Error!JSValue {
    const exception = try engine.createDOMException(realm, name, message);
    defer exception.release();
    return (try engine.createRejectedPromise(realm, exception.value)).take();
}

// ============================================================================
// Promises settled from "in parallel"
//
// Every Cookie Store operation settles its promise from steps it runs "in
// parallel", and a result handed back from in-parallel steps arrives in a
// task. The jar answers at once, but settling p at once reorders script
// against the tasks already queued. cookieStore.set() queues its `change`
// event task as the jar changes; a promise already settled lets the next
// awaited step run before that event. change_eventhandler_for_already_expired
// then saw a test's cleanup deletions in the NEXT test's event. So these
// promises are made now and settled from a task on the realm's event loop,
// behind anything the operation queued.
// ============================================================================

/// How an in-parallel operation settles its promise. The value is OWNED
/// and handed over.
pub const Outcome = union(enum) {
    fulfill: engine.Owned,
    reject: engine.Owned,

    fn release(self: Outcome) void {
        switch (self) {
            .fulfill, .reject => |value| value.release(),
        }
    }
};

/// A new promise in `realm`, settled with `outcome` from a task: on the
/// realm's event loop, else now (a realm with none, as in tests). Returned
/// for the binding. The realm is a CookieStore's - a Window's
/// ([Exposed=(ServiceWorker,Window)]; no ServiceWorkerGlobalScope realm is
/// made) - and a window or frame realm has its loop and its timers together
/// or neither, so there is no timer to fall back to.
pub fn settledInTask(realm: runtime.Context, outcome: Outcome) engine.Error!JSValue {
    var capability = engine.createPromise(realm) catch |err| {
        outcome.release();
        return err;
    };
    const p = engine.retainValue(realm, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        outcome.release();
        return err;
    };
    const task = realm.allocator.create(SettleTask) catch {
        engine.releasePromiseCapability(&capability);
        outcome.release();
        p.release();
        return error.OutOfMemory;
    };
    task.* = .{ .realm = realm, .capability = capability, .outcome = outcome };
    if (realm.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = SettleTask.run, .context = task, .drop = SettleTask.drop });
        return p.take();
    }
    SettleTask.run(task);
    return p.take();
}

/// "Resolve p with `value`" (BORROWED) from a task.
pub fn resolvedInTask(realm: runtime.Context, value: JSValue) engine.Error!JSValue {
    return settledInTask(realm, .{ .fulfill = try engine.retainValue(realm, value) });
}

/// "Reject p with a TypeError" from a task.
pub fn rejectedInTaskWithTypeError(realm: runtime.Context, message: []const u8) engine.Error!JSValue {
    return settledInTask(realm, .{ .reject = try engine.createSimpleException(realm, .TypeError, message) });
}

const SettleTask = struct {
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    outcome: Outcome,

    fn run(context: ?*anyopaque) void {
        const self: *SettleTask = @ptrCast(@alignCast(context.?));
        // A realm the adapter has retired has nobody to hear it.
        if (self.realm.hasEngine()) {
            engine.runTaskInRealm(self.realm, steps, self) catch {};
        }
        self.finish();
    }

    fn steps(data: ?*anyopaque) void {
        const self: *SettleTask = @ptrCast(@alignCast(data.?));
        switch (self.outcome) {
            .fulfill => |value| engine.resolvePromise(&self.capability, value.value) catch {},
            .reject => |reason| engine.rejectPromise(&self.capability, reason.value) catch {},
        }
    }

    /// The loop ends with the task still queued.
    fn drop(context: ?*anyopaque) void {
        const self: *SettleTask = @ptrCast(@alignCast(context.?));
        self.finish();
    }

    fn finish(self: *SettleTask) void {
        self.outcome.release();
        engine.releasePromiseCapability(&self.capability);
        self.realm.allocator.destroy(self);
    }
};

/// The realm an operation's promise is made in: the current realm (WebIDL
/// makes an operation's promise in the realm of the function called), else
/// the object's relevant realm.
pub fn operationRealm(instance: *runtime.Instance) runtime.Context {
    return engine.currentRealm() orelse instance.ctx;
}
