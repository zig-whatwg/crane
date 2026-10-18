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

/// Internal state for CookieStore implementation: its type is the cookiestore
/// module's (`cookiestore.CookieStoreState`), testable without an engine; the
/// state is this store's.
pub const InternalState = cookiestore.CookieStoreState;

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

/// What a CookieStore is given at construction (`initWith`): whether its
/// relevant settings object is a secure context - Window and
/// ServiceWorkerGlobalScope pass theirs to their cookieStore attribute's
/// store. The store keeps no origin: every operation reads its relevant
/// settings object - its jar, creation URL and origin - when it runs.
pub const construction_args = .{"is_secure_context"};

/// CookieStore's own construction steps: the generated chain runs
/// EventTarget's first. Made with no arguments, a store is a secure
/// context's.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const is_secure_context: bool = if (@hasField(@TypeOf(args), "is_secure_context")) args.is_secure_context else true;

    const internal = try InternalState.init(allocator, is_secure_context);

    // Store internal state pointer in state
    const state = instance.getState(State);
    state.own._internal = internal;
    listenToJar(instance);
}

/// CookieStore's own teardown: the generated chain runs EventTarget's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    // It hears the jar no more; a queued change task finds it gone.
    unlistenToJar(instance);
    // Clean up internal state
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        state.own._internal = null;
    }
}

/// Helper to get internal state from instance
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

// ============================================================================
// Process cookie changes
//
// Cookie Store "process cookie changes": whenever the user agent's cookie
// store changes - through fetch, a navigation, document.cookie, a WebSocket
// handshake or this API, on any of the Browser's threads - every Window's
// CookieStore whose creation URL observes the change gets a `change` event,
// queued as a global task. Each live CookieStore listens to its Browser's
// jar (dom.cookie_change_listeners, a supplement of the Browser's scope,
// which is the jar's change hook); the listeners tell it of each change on
// its own realm's thread (`deliverChange`), which records the change and
// queues its task; the task (`fireChangeEvent`) keeps the changes
// observable for the store's URL and fires them.
// ============================================================================

const CookieChangeListeners = @import("dom").cookie_change_listeners.CookieChangeListeners;

/// Listen to the jar of the Browser `instance`'s realm belongs to. A store a
/// Browser did not make (a test realm's) hears nothing.
fn listenToJar(instance: *runtime.Instance) void {
    const listeners = CookieChangeListeners.of(instance.ctx) orelse return;
    listeners.listen(instance, &deliverChange) catch {
        log.warn("a CookieStore will fire no change events: out of memory", .{});
    };
}

fn unlistenToJar(instance: *runtime.Instance) void {
    const listeners = CookieChangeListeners.existingOf(instance.ctx) orelse return;
    listeners.unlisten(instance);
}

/// The listeners' delivery, on `instance`'s realm's thread: `cookie`
/// (borrowed) was inserted or removed. Recorded with the store, and its
/// task queued.
fn deliverChange(instance: *runtime.Instance, change_type: cookiestore.CookieChangeType, cookie: *const Cookie) void {
    const internal = getInternalState(instance) orelse return;
    internal.change_observer.recordChange(change_type, cookie.*) catch return;
    scheduleChangeEvent(instance, internal);
}

/// Steps 1.2-1.4: capture this notification's changes before queueing its
/// global task. WebKit CookieStore::cookiesAdded/cookiesDeleted likewise
/// prepares each event's lists before queueTaskToDispatchEvent.
fn scheduleChangeEvent(instance: *runtime.Instance, internal: *InternalState) void {
    var changes = internal.change_observer.pending_changes;
    internal.change_observer.pending_changes = .empty;
    const task = internal.allocator.create(ChangeTask) catch {
        for (changes.items) |*change| change.deinit();
        changes.deinit(internal.allocator);
        return;
    };
    task.* = .{
        .instance = instance,
        .generation = runtime.SlabAllocator.generationOf(instance),
        .allocator = internal.allocator,
        .changes = changes,
        // Read now, while the store is alive: the task may find it gone.
        .listeners = CookieChangeListeners.existingOf(instance.ctx),
    };
    // A CookieStore's realm is a Window's ([Exposed=(ServiceWorker,Window)],
    // and no ServiceWorkerGlobalScope realm is made), and a window or frame
    // realm has its loop and its timers together or neither
    // (browser/Context.zig takes both from the Browser's loop; a frame
    // copies its parent's). So there is no timer to fall back to: the only
    // realm with timers and no loop is a shared worker's.
    if (instance.ctx.getOptionalEventLoop()) |loop| {
        loop.queueTask(.{ .callback = ChangeTask.run, .context = task, .drop = ChangeTask.drop });
        return;
    }
    // No loop to queue on (a realm built for tests): now.
    ChangeTask.run(task);
}

/// The task, and what it needs to find its store again.
const ChangeTask = struct {
    instance: *runtime.Instance,
    generation: u64,
    allocator: std.mem.Allocator,
    /// The store's Browser's listeners: whether it still listens says
    /// whether it is still there. They outlive every task of the Browser.
    listeners: ?*CookieChangeListeners,
    /// Captured before queueing; no later mutation can join this event.
    changes: std.ArrayListUnmanaged(cookiestore.CookieChange),

    fn run(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context.?));
        defer self.destroy();
        const instance = self.instance;
        const listeners = self.listeners orelse return;
        if (!listeners.isListening(instance, self.generation)) return;
        // Entered from the event loop, not from script: the realm's task.
        engine.runTaskInRealm(instance.ctx, steps, self) catch {};
    }

    fn steps(data: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(data.?));
        const internal = getInternalState(self.instance) orelse return;
        fireChangeEvent(self.instance, internal, self.changes.items);
    }

    fn drop(context: ?*anyopaque) void {
        const self: *ChangeTask = @ptrCast(@alignCast(context.?));
        self.destroy();
    }

    fn destroy(self: *ChangeTask) void {
        for (self.changes.items) |*change| change.deinit();
        self.changes.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// "Fire a change event named `change` with changes at" the store: the
/// recorded changes observable for its creation URL (those the URL's
/// cookie-list for a "non-HTTP" API would hold), prepared as lists - a
/// deleted cookie's item has no value - in a CookieChangeEvent, trusted.
fn fireChangeEvent(instance: *runtime.Instance, internal: *InternalState, changes: []const cookiestore.CookieChange) void {
    const allocator = internal.allocator;
    // The task owns these records through dispatch, including reentrant
    // script and microtasks. A listener's writes queue independent tasks.
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
    for (changes) |*change| {
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
    _ = @import("dom").fire_event.dispatchTrusted(instance, event) catch |err| {
        log.debug("change event not dispatched: {s}", .{@errorName(err)});
    };
    // An event no script saw is freed; a wrapped one belongs to its wrapper.
    event.releaseIfUnwrapped(generation);
}

// ============================================================================
// Query seam
//
// The jar is synchronous; everything asynchronous about this interface is the
// Promise wrapper. The query is the cookiestore module's
// (`cookiestore.queryItems`), testable without an isolate - see
// tests/cookiestore/query_items_test.zig.
// ============================================================================

const queryItems = cookiestore.queryItems;
const freeItems = cookiestore.freeItems;

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

    // Step 6.1: query with the given name, even when it is empty. Only the
    // dictionary overload can omit the filter (get(options) step 8.1).
    var items = queryItems(internal.allocator, client.jar, client.url, name) catch
        return cookie_values.rejectedInTaskWithTypeError(realm, "Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    // Step 5: resolve with the first item, or null when the list is empty.
    if (items.items.len == 0) return cookie_values.resolvedInTask(realm, runtime.JSValue.jsNull);

    const item = try cookie_values.listItem(realm, items.items[0]);
    defer item.release();
    return cookie_values.resolvedInTask(realm, item.value);
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

    // Step 6.1: an empty string selects nameless cookies. getAll() without
    // arguments uses the dictionary overload's null name (step 7.1).
    var items = queryItems(internal.allocator, client.jar, client.url, name) catch
        return cookie_values.rejectedInTaskWithTypeError(realm, "Failed to read cookies");
    defer freeItems(internal.allocator, &items);

    const list = try cookie_values.list(realm, items.items, internal.allocator);
    defer list.release();
    return cookie_values.resolvedInTask(realm, list.value);
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
        else => cookie_values.rejectedInTaskWithTypeError(realm, "Invalid cookie name or value"),
    };

    return cookie_values.resolvedInTask(realm, runtime.JSValue.jsUndefined);
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
        else => cookie_values.rejectedInTaskWithTypeError(realm, "Invalid cookie name"),
    };

    return cookie_values.resolvedInTask(realm, runtime.JSValue.jsUndefined);
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
    // default null. Query cookies normalizes a provided name.
    var items = queryItems(allocator, client.jar, chosen orelse client.url, options.name) catch
        return cookie_values.rejectedInTaskWithTypeError(realm, "Failed to read cookies");
    defer freeItems(allocator, &items);

    switch (answer) {
        // 8.3-8.4: null for none, else the first item.
        .first => {
            if (items.items.len == 0) return cookie_values.resolvedInTask(realm, runtime.JSValue.jsNull);
            const item = try cookie_values.listItem(realm, items.items[0]);
            defer item.release();
            return cookie_values.resolvedInTask(realm, item.value);
        },
        // 7.3: the list.
        .all => {
            const list = try cookie_values.list(realm, items.items, allocator);
            defer list.release();
            return cookie_values.resolvedInTask(realm, list.value);
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
        else => cookie_values.rejectedInTaskWithTypeError(realm, "Invalid cookie"),
    };
    return cookie_values.resolvedInTask(realm, runtime.JSValue.jsUndefined);
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
        else => cookie_values.rejectedInTaskWithTypeError(realm, "Invalid cookie"),
    };
    return cookie_values.resolvedInTask(realm, runtime.JSValue.jsUndefined);
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

/// Get the change observer for event registration
pub fn getChangeObserver(instance: *runtime.Instance) ?*CookieChangeObserver {
    if (getInternalState(instance)) |internal| {
        return &internal.change_observer;
    }
    return null;
}
