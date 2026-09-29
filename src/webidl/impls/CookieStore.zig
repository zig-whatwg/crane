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
const engine = @import("engine");
const webidl = @import("webidl");
const EventTargetImpl = @import("EventTarget.zig");
const log = std.log.scoped(.cookie_store);

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
    /// The jar's changes since this store last fired `change` - every one,
    /// from any API; which are observable for its URL is decided when it
    /// fires (`fireChangeEvent`).
    change_observer: CookieChangeObserver,
    /// A task to fire `change` is queued (`scheduleChangeEvent`).
    change_task_queued: bool = false,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, is_secure_context: bool) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .is_secure_context = is_secure_context,
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
    // A CookieStore is an EventTarget: its EventTarget state first.
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);

    // Initialize internal state with default values
    const internal = try InternalState.init(allocator, true);

    // Store internal state pointer in state
    const state = instance.getState(StateType);
    state.own._internal = internal;
    listenToJar(instance);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // It hears the jar no more; a queued change task finds it gone.
    unlistenToJar(instance);
    // Clean up internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        state.own._internal = null;
    }
    EventTargetImpl.deinit(instance);
}

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Getter for onchange (HTML § 8.1.8.1, the event handler IDL attribute).
pub fn get_onchange(instance: *runtime.Instance) anyerror!typedefs.EventHandler {
    return EventTargetImpl.eventHandler(typedefs.EventHandler, instance, "change");
}

/// Setter for onchange: the handler joins the event listener list, where
/// dispatch finds it in the order it was activated.
pub fn set_onchange(instance: *runtime.Instance, value: typedefs.EventHandler) anyerror!void {
    try EventTargetImpl.setEventHandler(typedefs.EventHandler, instance, "change", value);
}

// ============================================================================
// Process cookie changes
//
// Cookie Store "process cookie changes": whenever the user agent's cookie
// store changes - through fetch, a navigation, document.cookie, a WebSocket
// handshake or this API - every Window's CookieStore whose creation URL
// observes the change gets a `change` event, queued as a global task. Here
// each live CookieStore registers with its jar (`listenToJar`); the jar's
// change hook (`jarChanged`) records the change with every store on that
// jar and queues each one's task; the task (`fireChangeEvent`) keeps the
// changes observable for the store's URL and fires them.
// ============================================================================

/// A CookieStore that hears its jar: the instance, its slab generation when
/// it registered (an address is not an identity), and the jar.
const Listening = struct {
    instance: *runtime.Instance,
    generation: u64,
    jar: *CookieJar,
};

/// Every CookieStore on this thread that hears a jar. The jar never points
/// at a store - its hook is `jarChanged`, with the jar as context - so a
/// store and the jar can end in either order.
threadlocal var listening: std.ArrayListUnmanaged(Listening) = .empty;

/// Register `instance` with the jar its relevant settings object reaches,
/// and give that jar the hook. A store with no jar hears nothing.
fn listenToJar(instance: *runtime.Instance) void {
    const client = clientOf(instance) orelse return;
    listening.append(std.heap.page_allocator, .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .jar = client.jar,
    }) catch {
        log.warn("a CookieStore will fire no change events: out of memory", .{});
        return;
    };
    client.jar.on_change = .{ .callback = &jarChanged, .context = client.jar };
}

fn unlistenToJar(instance: *runtime.Instance) void {
    var i: usize = 0;
    while (i < listening.items.len) {
        if (listening.items[i].instance == instance) {
            _ = listening.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

/// Whether `instance`, as it was at `generation`, still hears a jar.
fn stillListening(instance: *runtime.Instance, generation: u64) bool {
    for (listening.items) |entry| {
        if (entry.instance == instance and entry.generation == generation) return true;
    }
    return false;
}

/// The jar's change hook: `cookie` (borrowed) was inserted or removed.
/// HttpOnly cookies are never observable to script.
fn jarChanged(context: ?*anyopaque, change_type: cookiestore.CookieChangeType, cookie: *const Cookie) void {
    if (cookie.http_only) return;
    const jar: *CookieJar = @ptrCast(@alignCast(context.?));
    // By index: a store's task can run here and now (a realm with no loop),
    // and its script can make or end a CookieStore.
    var i: usize = 0;
    while (i < listening.items.len) : (i += 1) {
        const entry = listening.items[i];
        if (entry.jar != jar) continue;
        if (runtime.SlabAllocator.generationOf(entry.instance) != entry.generation) continue;
        const internal = getInternalState(entry.instance) orelse continue;
        internal.change_observer.recordChange(change_type, cookie.*) catch continue;
        scheduleChangeEvent(entry.instance, internal);
    }
}

/// Step 1.4: queue a global task on the DOM manipulation task source to
/// fire `change` - one task for however many changes arrive before it runs.
fn scheduleChangeEvent(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.change_task_queued) return;
    const task = internal.allocator.create(ChangeTask) catch return;
    task.* = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .allocator = internal.allocator,
    };
    internal.change_task_queued = true;
    if (instance.ctx.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = ChangeTask.run, .context = task, .drop = ChangeTask.drop });
        return;
    }
    if (instance.ctx.getOptionalTimer()) |timer| {
        if (timer.setTimeout(0, ChangeTask.run, task) != 0) return;
    }
    // No loop to queue on (a realm built for tests): now.
    ChangeTask.run(task);
}

/// The task, and what it needs to find its store again.
const ChangeTask = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,

    fn run(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context.?));
        const instance = self.instance;
        const alive = stillListening(instance, self.generation);
        self.allocator.destroy(self);
        if (!alive) return;
        // Entered from the event loop, not from script: the realm's task.
        engine.runTaskInRealm(instance.ctx, steps, instance) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const instance: *runtime.Instance = @ptrCast(@alignCast(data.?));
        const internal = getInternalState(instance) orelse return;
        internal.change_task_queued = false;
        fireChangeEvent(instance, internal);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context.?));
        self.allocator.destroy(self);
    }
};

/// "Fire a change event named `change` with changes at" the store: the
/// recorded changes observable for its creation URL (those the URL's
/// cookie-list for a "non-HTTP" API would hold), prepared as lists - a
/// deleted cookie's item has no value - in a CookieChangeEvent, trusted.
fn fireChangeEvent(instance: *runtime.Instance, internal: *InternalState) void {
    const allocator = internal.allocator;
    const observer = &internal.change_observer;
    // The changes this event reports, taken out of the store's list NOW:
    // dispatching runs script, and the microtasks it releases run before
    // the dispatch returns - a listener that sets or deletes a cookie adds
    // to the list mid-event, and schedules the next task. Those changes are
    // that task's. (Clearing the list after the dispatch dropped them, so
    // their event never came: change_eventhandler_for_already_expired's
    // second test waited forever for one.)
    var changes = observer.pending_changes;
    observer.pending_changes = .empty;
    defer {
        for (changes.items) |*change| change.deinit();
        changes.deinit(observer.allocator);
    }
    const client = clientOf(instance) orelse return;
    const url = cookiestore.RequestUrl.of(client.url) orelse return;
    const options: cookiestore.RetrieveOptions = .{
        .host = url.host,
        .path = url.path,
        .is_secure = url.secure,
        // TODO: the same-site mode, as for document.cookie.
        .same_site = .strict_or_less,
    };

    // "Prepare lists from changes": borrowed from the recorded changes,
    // which outlive the event's construction (it copies them).
    var changed: std.ArrayListUnmanaged(dictionaries.CookieListItem) = .empty;
    defer changed.deinit(allocator);
    var deleted: std.ArrayListUnmanaged(dictionaries.CookieListItem) = .empty;
    defer deleted.deinit(allocator);
    for (changes.items) |*change| {
        if (!CookieJar.cookieMatches(&change.cookie, options)) continue;
        const list = if (change.change_type == .changed) &changed else &deleted;
        list.append(allocator, .{
            .name = change.cookie.name,
            .value = if (change.change_type == .changed) change.cookie.value else null,
        }) catch return;
    }
    if (changed.items.len == 0 and deleted.items.len == 0) return;

    // Steps 1-6: a CookieChangeEvent of type `change`, neither bubbling nor
    // cancelable, with the lists.
    const type_string = runtime.DOMString.initInterned("change");
    const event = interfaces.CookieChangeEvent.call_constructor(
        instance.ctx,
        type_string,
        webidl.Opt(dictionaries.CookieChangeEventInit).passed(.{
            .base = .{},
            .changed = changed.items,
            .deleted = deleted.items,
        }),
    ) catch |err| {
        log.debug("change event not made: {s}", .{@errorName(err)});
        return;
    };
    // Step 7: dispatch it - fired by the user agent, so trusted. EventTarget
    // is an ancestor, so its impl.
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = EventTargetImpl.dispatchTrusted(instance, event) catch |err| {
        log.debug("change event not dispatched: {s}", .{@errorName(err)});
    };
    // An event no script saw is freed; a wrapped one belongs to its wrapper.
    event.releaseIfUnwrapped(generation);
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
    // A creation URL with no host (about:srcdoc, about:blank) keeps no
    // cookies: the storage model ignores one. The pair is still validated -
    // an invalid one still rejects - against a jar that is thrown away.
    var scratch = CookieJar.init(internal.allocator);
    defer scratch.deinit();
    const url = cookiestore.RequestUrl.of(client.url);
    const jar = if (url != null) client.jar else &scratch;

    // Step 6.1: set a cookie with url, name, value, and the defaults.
    // The jar's change hook records the change for every store (this one
    // included), so nothing is recorded here.
    cookiestore.setCookie(internal.allocator, jar, if (url) |u| u.host else "", .{
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
    // As set(): a URL with no host keeps no cookies to delete.
    var scratch = CookieJar.init(internal.allocator);
    defer scratch.deinit();
    const url = cookiestore.RequestUrl.of(client.url);
    const jar = if (url != null) client.jar else &scratch;

    // Step 6.1: delete a cookie with url, name, null, "/" and true.
    cookiestore.deleteCookie(internal.allocator, jar, if (url) |u| u.host else "", .{
        .name = name,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => cookie_values.rejectedWithTypeError(realm, "Invalid cookie name"),
    };

    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

// ============================================================================
// The dictionary overloads: get(options), getAll(options), set(options),
// delete(options)
// ============================================================================

/// Operation: get(options)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-get-options
pub fn call_get__1(instance: *runtime.Instance, options: webidl.Opt(dictionaries.CookieStoreGetOptions)) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);
    const given = if (options.was_passed) options.value else dictionaries.CookieStoreGetOptions{};
    // Step 5: If options is empty, then return a promise rejected with a
    // TypeError.
    if (given.name == null and given.url == null) return cookie_values.rejectedWithTypeError(realm, "get() needs a name or a url");
    return queryWithOptions(instance, realm, given, .first);
}

/// Operation: getAll(options)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-getall-options
pub fn call_getAll__1(instance: *runtime.Instance, options: webidl.Opt(dictionaries.CookieStoreGetOptions)) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);
    const given = if (options.was_passed) options.value else dictionaries.CookieStoreGetOptions{};
    return queryWithOptions(instance, realm, given, .all);
}

/// get(options) steps 1-4 and 6-9, and getAll(options)'s 1-8: the query of
/// options["name"] at the creation URL, or at options["url"] when that
/// names it (a Window) or a URL of its origin (a worker).
fn queryWithOptions(instance: *runtime.Instance, realm: runtime.Context, options: dictionaries.CookieStoreGetOptions, answer: enum { first, all }) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    const allocator = internal.allocator;
    // Steps 1-4: the relevant settings object; an opaque origin rejects with
    // a SecurityError; the URL is its creation URL.
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");

    // Step 6 (getAll: 5): options["url"], parsed against the API base URL.
    var chosen: ?[]const u8 = null;
    defer if (chosen) |u| allocator.free(u);
    if (options.url) |url_option| {
        chosen = switch (try urlForQuery(allocator, instance, client.url, url_option)) {
            .url => |u| u,
            .type_error => |message| return cookie_values.rejectedWithTypeError(realm, message),
        };
    }

    // Step 8.1 (getAll: 7.1): query cookies with url and options["name"],
    // default null. (Normalizing a name is the identity.)
    var items = queryItems(allocator, client.jar, chosen orelse client.url, options.name) catch
        return cookie_values.rejectedWithTypeError(realm, "Failed to read cookies");
    defer freeItems(allocator, &items);

    switch (answer) {
        // 8.3-8.4: null for none, else the first item.
        .first => {
            if (items.items.len == 0) return cookie_values.resolvedWith(realm, runtime.JSValue.jsNull);
            const item = try cookie_values.listItem(realm, items.items[0]);
            defer item.release();
            return cookie_values.resolvedWith(realm, item.value);
        },
        // 7.3: the list.
        .all => {
            const list = try cookie_values.list(realm, items.items, allocator);
            defer list.release();
            return cookie_values.resolvedWith(realm, list.value);
        },
    }
}

/// get(options) step 6: "Let parsed be the result of parsing options["url"]
/// with settings's API base URL" - here the creation URL. A Window may only
/// name its own URL (fragments aside); any global only a URL of its origin.
/// The URL serialized (OWNED), or the TypeError's message.
fn urlForQuery(allocator: std.mem.Allocator, instance: *runtime.Instance, creation_url: []const u8, input: []const u8) !union(enum) { url: []const u8, type_error: []const u8 } {
    const basic_parser = @import("basic_parser");
    const url_serializer = @import("url_serializer");
    const origin = @import("origin");
    var base = basic_parser.parse(allocator, creation_url, null) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return .{ .type_error = "The creation URL does not parse" },
    };
    defer base.deinit();
    var parsed = basic_parser.parse(allocator, input, &base) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return .{ .type_error = "url does not parse" },
    };
    defer parsed.deinit();

    // 6.2. A Window: parsed must equal url, fragments excluded.
    const record = instance.ctx.getRealm();
    const is_window = if (record) |r| if (r.global_object) |g| std.mem.eql(u8, @as(*runtime.Instance, @ptrCast(@alignCast(g))).vtable.name, "Window") else false else false;
    if (is_window and !try @import("url").equivalence.equals(allocator, &parsed, &base, true)) {
        return .{ .type_error = "A Window's cookieStore reads its own URL only" };
    }
    // 6.3. parsed's origin and url's origin must be the same origin.
    var parsed_origin = try origin.getOrigin(allocator, &parsed);
    defer parsed_origin.deinit(allocator);
    var base_origin = try origin.getOrigin(allocator, &base);
    defer base_origin.deinit(allocator);
    if (!origin.isSameOrigin(parsed_origin, base_origin)) return .{ .type_error = "url is not of this origin" };

    // 6.4. Set url to parsed.
    return .{ .url = try url_serializer.serialize(allocator, &parsed, false) };
}

/// Operation: set(options)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-set-options
pub fn call_set__1(instance: *runtime.Instance, options: dictionaries.CookieInit) anyerror!runtime.JSValue {
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
    // As set(name, value): a URL with no host keeps no cookies.
    var scratch = CookieJar.init(internal.allocator);
    defer scratch.deinit();
    const url = cookiestore.RequestUrl.of(client.url);
    const jar = if (url != null) client.jar else &scratch;

    // Step 6.1: set a cookie with url and the options - sameSite "strict",
    // path "/" and partitioned false by default.
    cookiestore.setCookie(internal.allocator, jar, if (url) |u| u.host else "", .{
        .name = options.name,
        .value = options.value,
        // A DOMHighResTimeStamp: milliseconds since the epoch.
        .expires = if (options.expires) |ms| timestampMillis(ms) else null,
        .max_age = options.maxAge,
        .domain = options.domain,
        .path = options.path orelse "/",
        .url_path = if (url) |u| u.path else "/",
        .same_site = if (options.sameSite) |same_site| switch (same_site) {
            ._strict_ => .strict,
            ._lax_ => .lax,
            ._none_ => .none,
        } else .strict,
        .partitioned = options.partitioned orelse false,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        // Step 6.2: failure rejects with a TypeError.
        else => cookie_values.rejectedWithTypeError(realm, "Invalid cookie"),
    };
    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

/// Operation: delete(options)
/// https://cookiestore.spec.whatwg.org/#dom-cookiestore-delete-options
pub fn call_delete__1(instance: *runtime.Instance, options: dictionaries.CookieStoreDeleteOptions) anyerror!runtime.JSValue {
    const realm = cookie_values.operationRealm(instance);
    const internal = getInternalState(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    // Steps 1-4, as get().
    const client = clientOf(instance) orelse
        return cookie_values.rejectedWithTypeError(realm, "CookieStore has no cookie jar");
    if (client.opaque_origin) return cookie_values.rejectedWithDOMException(realm, "SecurityError", "An opaque origin has no cookies");
    var scratch = CookieJar.init(internal.allocator);
    defer scratch.deinit();
    const url = cookiestore.RequestUrl.of(client.url);
    const jar = if (url != null) client.jar else &scratch;

    // Step 6.1: delete a cookie with url, name, domain, path and
    // partitioned - path "/" and partitioned false by default.
    cookiestore.deleteCookie(internal.allocator, jar, if (url) |u| u.host else "", .{
        .name = options.name,
        .domain = options.domain,
        .path = options.path orelse "/",
        .partitioned = options.partitioned orelse false,
    }) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => cookie_values.rejectedWithTypeError(realm, "Invalid cookie"),
    };
    return cookie_values.resolvedWith(realm, runtime.JSValue.jsUndefined);
}

/// A DOMHighResTimeStamp as whole milliseconds, saturating.
fn timestampMillis(ms: f64) i64 {
    if (std.math.isNan(ms)) return 0;
    const limit: f64 = @floatFromInt(std.math.maxInt(i64));
    return @intFromFloat(std.math.clamp(ms, -limit, limit));
}

// ============================================================================
// Public API for integration
// ============================================================================

/// Create a new CookieStore. This is used by Window and
/// ServiceWorkerGlobalScope to create their cookieStore attribute. The
/// store keeps no origin: every operation reads its relevant settings
/// object - its jar, creation URL and origin - when it runs.
pub fn createForOrigin(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
    is_secure_context: bool,
) !*runtime.Instance {
    // A CookieStore is an EventTarget: its EventTarget state first.
    const instance = try EventTargetImpl.init(allocator, StateType, vtable, ctx);
    errdefer EventTargetImpl.deinit(instance);

    const internal = try InternalState.init(allocator, is_secure_context);

    const state = instance.getState(StateType);
    state.own._internal = internal;
    listenToJar(instance);

    return instance;
}

/// Get the change observer for event registration
pub fn getChangeObserver(instance: *runtime.Instance) ?*CookieChangeObserver {
    if (getInternalState(instance)) |internal| {
        return &internal.change_observer;
    }
    return null;
}
