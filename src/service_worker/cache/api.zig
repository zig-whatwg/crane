//! The steps of CacheStorage's and Cache's members (Service Workers 5.4,
//! 5.5) in a realm: what the impls call. The lists themselves are the
//! Browser's (store.zig); this side turns Request and Response objects into
//! records and back - a cached response is a new Response object each time,
//! its headers immutable - reads response bodies, and fetches for add() and
//! addAll().
//!
//! The spec's "in parallel" steps that only read or change the lists run
//! here at once, under the Browser's cache lock, and settle the promise
//! (whose reactions run as microtasks); the ones that wait - a body to be
//! read, a fetch - settle it from a promise reaction.
//!
//! Stated deviations:
//! - matchAll()'s step 5.4 (an opaque response that the cross-origin
//!   resource policy check blocks rejects) is not run: an opaque response
//!   kept here has lost the headers the check reads (Crane filters a
//!   response in place).
//! - addAll() step 5.3 (a request a service worker's Cache makes skips the
//!   service workers) waits for batch 3's Handle Fetch, which is what it
//!   skips.
//! - A store failure rejects with an "UnknownError" DOMException (as
//!   Chromium's backend errors do); the spec names none.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#cache-objects

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const html = @import("html");
const fetch = @import("fetch");
const platform = @import("platform");
const store_mod = @import("store.zig");
const records = @import("records.zig");

const Storage = store_mod.Storage;
const InternalRequest = fetch.internal.InternalRequest;
const InternalResponse = fetch.internal.InternalResponse;
const RequestInfo = @import("typedefs").RequestInfo;

const log = std.log.scoped(.service_worker);

/// A Cache object's state: the cache of its Browser's Cache Storage it
/// represents (a request response list, by id).
pub const CacheHandle = struct {
    /// The Browser's (a BrowserScope supplement: it outlives every realm).
    storage: *Storage,
    cache: u64,
};

/// What a member needs of its realm: the Browser's Cache Storage and
/// platform state, and the storage key (the relevant settings object's
/// origin).
const Scope = struct {
    realm: runtime.Context,
    storage: *Storage,
    browser: *platform.BrowserPlatform,
    /// OWNED (`realm.allocator`).
    storage_key: []u8,

    fn of(realm: runtime.Context) !Scope {
        const browser_scope = realm.browserScope() orelse return error.InvalidStateError;
        const storage = try browser_scope.of(Storage);
        const browser = html.platform_state.of(realm) orelse return error.InvalidStateError;
        const global = globalOf(realm) orelse return error.InvalidStateError;
        const settings = dom.global_settings.of(global) orelse return error.InvalidStateError;
        const origin = try settings.origin(global);
        // "Obtain a local storage bottle map": an opaque origin has no
        // storage key - a SecurityError, as Chromium and Firefox reject.
        if (std.mem.eql(u8, origin, "null")) {
            realm.allocator.free(origin);
            return error.SecurityError;
        }
        return .{ .realm = realm, .storage = storage, .browser = browser, .storage_key = @constCast(origin) };
    }

    fn deinit(self: *Scope) void {
        self.realm.allocator.free(self.storage_key);
    }
};

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

fn resolved(realm: runtime.Context, value: runtime.JSValue) !runtime.JSValue {
    return (try engine.createResolvedPromise(realm, value)).take();
}

/// The exception a store error rejects with.
fn storeException(realm: runtime.Context, err: store_mod.Error) !engine.Owned {
    return switch (err) {
        error.TypeError => engine.createSimpleException(realm, .TypeError, "The cache operation is not allowed"),
        error.InvalidStateError => engine.createDOMException(realm, "InvalidStateError", "A batch puts the same request twice"),
        error.QuotaExceeded => engine.createDOMException(realm, "QuotaExceededError", "The cache is over its quota"),
        error.OutOfMemory => error.OutOfMemory,
        error.StoreFailed => engine.createDOMException(realm, "UnknownError", "The cache storage failed"),
    };
}

fn storeError(err: store_mod.Error) anyerror {
    return switch (err) {
        error.TypeError => error.TypeError,
        error.InvalidStateError => error.InvalidStateError,
        error.QuotaExceeded => error.QuotaExceededError,
        error.OutOfMemory => error.OutOfMemory,
        error.StoreFailed => error.UnknownError,
    };
}

// ============================================================================
// Records from objects, objects from records
// ============================================================================

fn headersOf(allocator: Allocator, list: *const fetch.internal.HeaderList) Allocator.Error![]records.Header {
    const items = list.iterator();
    const out = try allocator.alloc(records.Header, items.len);
    var made: usize = 0;
    errdefer {
        for (out[0..made]) |h| {
            allocator.free(h.name);
            allocator.free(h.value);
        }
        allocator.free(out);
    }
    for (items) |h| {
        const name = try allocator.dupe(u8, h.name);
        errdefer allocator.free(name);
        out[made] = .{ .name = name, .value = try allocator.dupe(u8, h.value) };
        made += 1;
    }
    return out;
}

fn intOf(value: anytype) u8 {
    return @intCast(@intFromEnum(value));
}

fn enumOf(comptime T: type, value: u8, default: T) T {
    return std.enums.fromInt(T, value) orelse default;
}

/// A request's record. OWNED.
fn storedRequestOf(allocator: Allocator, request: *const InternalRequest) Allocator.Error!records.StoredRequest {
    var out: records.StoredRequest = .{
        .url = try allocator.dupe(u8, request.currentUrl()),
        .method = &.{},
        .mode = intOf(request.mode),
        .credentials = intOf(request.credentials_mode),
        .cache = intOf(request.cache_mode),
        .redirect = intOf(request.redirect_mode),
        .referrer_policy = intOf(request.referrer_policy),
        .destination = intOf(request.destination),
        .keepalive = request.keepalive,
        .reload_navigation = request.reload_navigation,
        .history_navigation = request.history_navigation,
    };
    errdefer out.deinit(allocator);
    out.method = try allocator.dupe(u8, request.method);
    out.headers = try headersOf(allocator, &request.header_list);
    out.integrity = try allocator.dupe(u8, request.integrity_metadata);
    out.referrer = try allocator.dupe(u8, switch (request.referrer) {
        .client => "client",
        .no_referrer => "no-referrer",
        .url => |url| url,
    });
    return out;
}

/// A request from its record. OWNED.
fn internalRequestOf(allocator: Allocator, stored: *const records.StoredRequest) !*InternalRequest {
    const request = try InternalRequest.init(allocator, stored.url);
    errdefer request.deinit();
    try request.setMethod(stored.method);
    for (stored.headers) |h| try request.header_list.append(h.name, h.value);
    request.mode = enumOf(@TypeOf(request.mode), stored.mode, request.mode);
    request.credentials_mode = enumOf(@TypeOf(request.credentials_mode), stored.credentials, request.credentials_mode);
    request.cache_mode = enumOf(@TypeOf(request.cache_mode), stored.cache, request.cache_mode);
    request.redirect_mode = enumOf(@TypeOf(request.redirect_mode), stored.redirect, request.redirect_mode);
    request.referrer_policy = enumOf(@TypeOf(request.referrer_policy), stored.referrer_policy, request.referrer_policy);
    request.destination = enumOf(@TypeOf(request.destination), stored.destination, request.destination);
    try request.setIntegrityMetadata(stored.integrity);
    if (std.mem.eql(u8, stored.referrer, "client")) {
        request.setReferrer(.client);
    } else if (std.mem.eql(u8, stored.referrer, "no-referrer")) {
        request.setReferrer(.no_referrer);
    } else {
        try request.setReferrerUrl(stored.referrer);
    }
    request.keepalive = stored.keepalive;
    request.reload_navigation = stored.reload_navigation;
    request.history_navigation = stored.history_navigation;
    return request;
}

/// A response's record, without its body (put() reads it after). OWNED.
fn storedResponseOf(allocator: Allocator, response: *const InternalResponse) Allocator.Error!records.StoredResponse {
    var out: records.StoredResponse = .{
        .response_type = intOf(response.response_type),
        .status = response.status,
        .range_requested = response.range_requested,
        .request_includes_credentials = response.request_includes_credentials,
    };
    errdefer out.deinit(allocator);
    const urls = try allocator.alloc([]u8, response.url_list.items.len);
    @memset(urls, &.{});
    out.url_list = urls;
    for (response.url_list.items, urls) |url, *slot| slot.* = try allocator.dupe(u8, url);
    out.status_message = try allocator.dupe(u8, response.status_message);
    out.headers = try headersOf(allocator, &response.header_list);
    const exposed = try allocator.alloc([]u8, response.cors_exposed_header_name_list.items.len);
    @memset(exposed, &.{});
    out.cors_exposed = exposed;
    for (response.cors_exposed_header_name_list.items, exposed) |name, *slot| slot.* = try allocator.dupe(u8, name);
    return out;
}

/// A response from its record. OWNED.
fn internalResponseOf(allocator: Allocator, stored: *const records.StoredResponse) !*InternalResponse {
    const response = try InternalResponse.init(allocator);
    errdefer response.deinit();
    response.response_type = enumOf(@TypeOf(response.response_type), stored.response_type, .default);
    for (stored.url_list) |url| {
        const copy = try allocator.dupe(u8, url);
        response.url_list.append(allocator, copy) catch |err| {
            allocator.free(copy);
            return err;
        };
    }
    response.status = stored.status;
    try response.setStatusMessage(stored.status_message);
    for (stored.headers) |h| try response.header_list.append(h.name, h.value);
    for (stored.cors_exposed) |name| {
        const copy = try allocator.dupe(u8, name);
        response.cors_exposed_header_name_list.append(allocator, copy) catch |err| {
            allocator.free(copy);
            return err;
        };
    }
    if (stored.body) |body| response.body = try fetch.internal.Body.fromBytes(allocator, body);
    response.range_requested = stored.range_requested;
    response.request_includes_credentials = stored.request_includes_credentials;
    return response;
}

/// Wrap `object` at once: its wrapper owns it from here, so a step that fails
/// before script holds it leaves nothing behind.
fn wrapNow(realm: runtime.Context, object: *runtime.Instance) !*runtime.Instance {
    const wrapper = engine.retainValue(realm, runtime.JSValue.fromInstance(object)) catch |err| {
        object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(object));
        return err;
    };
    wrapper.release();
    return object;
}

/// "A new Response object associated with response and a new Headers object
/// whose guard is immutable", in `realm`.
fn responseObject(realm: runtime.Context, stored: *const records.StoredResponse) !*runtime.Instance {
    const internal = try internalResponseOf(realm.allocator, stored);
    const object = interfaces.Response.init(realm.allocator, realm) catch |err| {
        internal.deinit();
        return err;
    };
    if (!dom.fetch_objects.adoptResponse(object, internal, .immutable)) {
        internal.deinit();
        object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(object));
        return error.InvalidStateError;
    }
    return wrapNow(realm, object);
}

/// "A new Request object associated with request and a new associated
/// Headers object whose guard is immutable", in `realm`.
fn requestObject(realm: runtime.Context, stored: *const records.StoredRequest) !*runtime.Instance {
    const internal = try internalRequestOf(realm.allocator, stored);
    const object = interfaces.Request.init(realm.allocator, realm) catch |err| {
        internal.deinit();
        return err;
    };
    const adopted = dom.fetch_objects.adoptRequest(object, internal, .immutable) catch |err| {
        internal.deinit();
        object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(object));
        return err;
    };
    if (!adopted) {
        internal.deinit();
        object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(object));
        return error.InvalidStateError;
    }
    return wrapNow(realm, object);
}

/// A RequestInfo as a request record: a Request object's request, or the
/// request of "the initial value of Request as constructor" with a string
/// (its exception rethrown). OWNED.
fn storedRequestFromInfo(realm: runtime.Context, info: RequestInfo) !records.StoredRequest {
    switch (info) {
        .request => |object| {
            const request: *InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(object) orelse return error.TypeError));
            return storedRequestOf(realm.allocator, request);
        },
        .usvstring => {
            const object = try interfaces.Request.call_constructor(realm, info, webidl.Opt(dictionaries.RequestInit).notPassed());
            const generation = runtime.SlabAllocator.generationOf(object);
            defer object.releaseIfUnwrapped(generation);
            const request: *InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(object) orelse return error.TypeError));
            return storedRequestOf(realm.allocator, request);
        },
    }
}

fn isHttpScheme(url: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(url, "http:") or std.ascii.startsWithIgnoreCase(url, "https:");
}

/// Whether `response`'s header list has a `Vary` whose field-values include
/// "*".
fn varyHasStar(allocator: Allocator, response: *const InternalResponse) Allocator.Error!bool {
    const vary = (try response.header_list.get(allocator, "Vary")) orelse return false;
    defer allocator.free(vary);
    var fields = std.mem.splitScalar(u8, vary, ',');
    while (fields.next()) |field| {
        if (std.mem.eql(u8, std.mem.trim(u8, field, " \t"), "*")) return true;
    }
    return false;
}

fn queryOptionsOf(options: ?dictionaries.CacheQueryOptions) store_mod.QueryOptions {
    const given = options orelse return .{};
    return .{
        .ignore_search = given.ignoreSearch orelse false,
        .ignore_method = given.ignoreMethod orelse false,
        .ignore_vary = given.ignoreVary orelse false,
    };
}

// ============================================================================
// CacheStorage (5.5)
// ============================================================================

/// match(request, options) (5.5.1).
pub fn storageMatch(cache_storage: *runtime.Instance, request: RequestInfo, options: ?dictionaries.MultiCacheQueryOptions) !runtime.JSValue {
    const realm = cache_storage.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    const caches = scope.storage.caches(scope.browser, allocator, scope.storage_key) catch |err| return storeError(err);
    defer {
        for (caches) |c| allocator.free(c.name);
        allocator.free(caches);
    }
    const query_options = queryOptionsOf(if (options) |o| o.base else null);
    // 1. options["cacheName"]: that cache's match(), or undefined.
    if (options) |o| if (o.cacheName) |name| {
        for (caches) |c| {
            if (!std.mem.eql(u8, c.name, name.asSlice())) continue;
            return matchIn(&scope, c.cache, request, query_options);
        }
        return resolved(realm, runtime.JSValue.jsUndefined);
    };
    // 2. Each cache in order, until one matches.
    for (caches) |c| {
        const found = try firstMatch(&scope, c.cache, request, query_options);
        if (found) |object| return resolved(realm, runtime.JSValue.fromInstance(object));
    }
    return resolved(realm, runtime.JSValue.jsUndefined);
}

/// has(cacheName) (5.5.2).
pub fn storageHas(cache_storage: *runtime.Instance, name: []const u8) !runtime.JSValue {
    const realm = cache_storage.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const found = scope.storage.hasCache(scope.browser, scope.storage_key, name) catch |err| return storeError(err);
    return resolved(realm, runtime.JSValue.fromBoolean(found));
}

/// open(cacheName) (5.5.3): a new Cache object representing the cache,
/// made when there is none.
pub fn storageOpen(cache_storage: *runtime.Instance, name: []const u8) !runtime.JSValue {
    const realm = cache_storage.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const id = scope.storage.openCache(scope.browser, scope.storage_key, name) catch |err| return storeError(err);
    const object = try wrapNow(realm, try interfaces.Cache.initWith(realm.allocator, realm, .{ .cache = CacheHandle{ .storage = scope.storage, .cache = id } }));
    return resolved(realm, runtime.JSValue.fromInstance(object));
}

/// delete(cacheName) (5.5.4).
pub fn storageDelete(cache_storage: *runtime.Instance, name: []const u8) !runtime.JSValue {
    const realm = cache_storage.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const deleted = scope.storage.deleteCache(scope.browser, scope.storage_key, name) catch |err| return storeError(err);
    return resolved(realm, runtime.JSValue.fromBoolean(deleted));
}

/// keys() (5.5.5): the map's names, in the order they were added.
pub fn storageKeys(cache_storage: *runtime.Instance) !runtime.JSValue {
    const realm = cache_storage.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    const names = scope.storage.cacheNames(scope.browser, allocator, scope.storage_key) catch |err| return storeError(err);
    defer {
        for (names) |n| allocator.free(n);
        allocator.free(names);
    }
    const values = try allocator.alloc(runtime.JSValue, names.len);
    defer allocator.free(values);
    for (names, values) |name, *value| value.* = runtime.JSValue.fromStringRef(name);
    const array = try engine.createSequenceOfValues(realm, values);
    defer array.release();
    return resolved(realm, array.borrow());
}

// ============================================================================
// Cache (5.4): the queries
// ============================================================================

/// The entries matchAll() and keys() find: every entry when `request` is
/// omitted; none for a Request object whose method is not GET without
/// ignoreMethod; Query Cache otherwise. OWNED.
fn findEntries(scope: *Scope, cache: u64, request: ?RequestInfo, options: store_mod.QueryOptions) ![]records.Entry {
    const allocator = scope.realm.allocator;
    const info = request orelse return scope.storage.query(scope.browser, allocator, cache, null, options) catch |err| return storeError(err);
    var stored = try storedRequestFromInfo(scope.realm, info);
    defer stored.deinit(allocator);
    // 2.1.2. A Request object whose method is not GET: nothing, without
    // ignoreMethod.
    if (info == .request and !options.ignore_method and !std.mem.eql(u8, stored.method, "GET")) return allocator.alloc(records.Entry, 0);
    return scope.storage.query(scope.browser, allocator, cache, store_mod.Query.of(&stored), options) catch |err| return storeError(err);
}

fn firstMatch(scope: *Scope, cache: u64, request: RequestInfo, options: store_mod.QueryOptions) !?*runtime.Instance {
    const allocator = scope.realm.allocator;
    const entries = try findEntries(scope, cache, request, options);
    defer records.freeEntries(allocator, entries);
    if (entries.len == 0) return null;
    return try responseObject(scope.realm, &entries[0].response);
}

fn matchIn(scope: *Scope, cache: u64, request: RequestInfo, options: store_mod.QueryOptions) !runtime.JSValue {
    const found = try firstMatch(scope, cache, request, options);
    return resolved(scope.realm, if (found) |object| runtime.JSValue.fromInstance(object) else runtime.JSValue.jsUndefined);
}

/// match(request, options) (5.4.1): matchAll()'s first response, or
/// undefined.
pub fn match(cache_object: *runtime.Instance, handle: CacheHandle, request: RequestInfo, options: ?dictionaries.CacheQueryOptions) !runtime.JSValue {
    var scope = try Scope.of(cache_object.ctx);
    defer scope.deinit();
    return matchIn(&scope, handle.cache, request, queryOptionsOf(options));
}

/// matchAll(request, options) (5.4.2): a new Response object for each
/// matching response, in a frozen array.
pub fn matchAll(cache_object: *runtime.Instance, handle: CacheHandle, request: ?RequestInfo, options: ?dictionaries.CacheQueryOptions) !runtime.JSValue {
    const realm = cache_object.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    const entries = try findEntries(&scope, handle.cache, request, queryOptionsOf(options));
    defer records.freeEntries(allocator, entries);
    const values = try allocator.alloc(runtime.JSValue, entries.len);
    defer allocator.free(values);
    for (entries, values) |*entry, *value| value.* = runtime.JSValue.fromInstance(try responseObject(realm, &entry.response));
    const array = try engine.createFrozenArray(realm, values);
    defer array.release();
    return resolved(realm, array.borrow());
}

/// keys(request, options) (5.4.7): a new Request object for each matching
/// request, in a frozen array.
pub fn keys(cache_object: *runtime.Instance, handle: CacheHandle, request: ?RequestInfo, options: ?dictionaries.CacheQueryOptions) !runtime.JSValue {
    const realm = cache_object.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    const entries = try findEntries(&scope, handle.cache, request, queryOptionsOf(options));
    defer records.freeEntries(allocator, entries);
    const values = try allocator.alloc(runtime.JSValue, entries.len);
    defer allocator.free(values);
    for (entries, values) |*entry, *value| value.* = runtime.JSValue.fromInstance(try requestObject(realm, &entry.request));
    const array = try engine.createFrozenArray(realm, values);
    defer array.release();
    return resolved(realm, array.borrow());
}

/// delete(request, options) (5.4.6): true when Batch Cache Operations
/// removed something.
pub fn delete(cache_object: *runtime.Instance, handle: CacheHandle, request: RequestInfo, options: ?dictionaries.CacheQueryOptions) !runtime.JSValue {
    const realm = cache_object.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    const query_options = queryOptionsOf(options);
    var stored = try storedRequestFromInfo(realm, request);
    defer stored.deinit(allocator);
    // 2.2. A Request object whose method is not GET: false, without
    // ignoreMethod.
    if (request == .request and !query_options.ignore_method and !std.mem.eql(u8, stored.method, "GET")) return resolved(realm, runtime.JSValue.fromBoolean(false));
    // 4-12. One delete operation.
    const removed = scope.storage.batch(scope.browser, handle.cache, &.{.{ .kind = .delete, .request = &stored, .options = query_options }}) catch |err| return storeError(err);
    return resolved(realm, runtime.JSValue.fromBoolean(removed > 0));
}

// ============================================================================
// Cache (5.4): put(), add(), addAll()
// ============================================================================

/// put(request, response) (5.4.5).
pub fn put(cache_object: *runtime.Instance, handle: CacheHandle, request: RequestInfo, response: *runtime.Instance) !runtime.JSValue {
    const realm = cache_object.ctx;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const allocator = realm.allocator;
    // 1-3. innerRequest.
    var stored_request = try storedRequestFromInfo(realm, request);
    errdefer stored_request.deinit(allocator);
    // 4. An http(s) URL, GET.
    if (!isHttpScheme(stored_request.url) or !std.mem.eql(u8, stored_request.method, "GET")) return error.TypeError;
    // 5. innerResponse.
    const inner: *InternalResponse = @ptrCast(@alignCast(dom.fetch_objects.responseOf(response) orelse return error.TypeError));
    // 6. A partial response.
    if (inner.status == 206) return error.TypeError;
    // 7. Vary: *.
    if (try varyHasStar(allocator, inner)) return error.TypeError;
    // 8. A body that is disturbed or locked.
    if (try interfaces.Response.get_bodyUsed(response)) return error.TypeError;
    if (try interfaces.Response.get_body(response)) |stream| {
        if (try interfaces.ReadableStream.get_locked(stream)) return error.TypeError;
    }
    // 9. clonedResponse, its body still to come.
    var stored_response = try storedResponseOf(allocator, inner);
    errdefer stored_response.deinit(allocator);
    const op = try PutOp.create(realm, handle, &.{stored_request}, &.{stored_response});
    stored_request = undefined;
    stored_response = undefined;
    defer op.release();
    // 10-11. A non-null body: read all its bytes - which locks and disturbs
    // the response's body - then 19, the batch.
    if (inner.body != null) {
        const read = try interfaces.Response.call_arrayBuffer(response);
        try op.readBody(read, 0);
    } else {
        op.slots[0].read = true;
        op.slots[0].response.?.body = null;
    }
    op.maybeCommit();
    return op.promise();
}

/// add(request) (5.4.3): addAll([request]), resolving with undefined.
pub fn add(cache_object: *runtime.Instance, handle: CacheHandle, request: RequestInfo) !runtime.JSValue {
    return addRequests(cache_object, handle, &.{request});
}

/// addAll(requests) (5.4.4), `requests` the script's sequence<RequestInfo>.
pub fn addAll(cache_object: *runtime.Instance, handle: CacheHandle, requests: runtime.JSValue) !runtime.JSValue {
    const realm = cache_object.ctx;
    const allocator = realm.allocator;
    const values = try engine.convertToSequence(realm, requests, allocator);
    defer {
        for (values) |v| v.release();
        allocator.free(values);
    }
    const infos = try allocator.alloc(RequestInfo, values.len);
    defer allocator.free(infos);
    var strings: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (strings.items) |s| allocator.free(s);
        strings.deinit(allocator);
    }
    for (values, infos) |value, *info| {
        if (engine.convertToPlatformObject(realm, value.value)) |object| {
            if (object.stateAs(interfaces.Request.State) != null) {
                info.* = .{ .request = object };
                continue;
            }
        }
        const text = try engine.convertToUSVString(realm, value.value, allocator);
        try strings.append(allocator, text);
        info.* = .{ .usvstring = text };
    }
    return addRequests(cache_object, handle, infos);
}

fn addRequests(cache_object: *runtime.Instance, handle: CacheHandle, requests: []const RequestInfo) !runtime.JSValue {
    const realm = cache_object.ctx;
    const allocator = realm.allocator;
    var scope = try Scope.of(realm);
    defer scope.deinit();
    const global = globalOf(realm) orelse return error.InvalidStateError;
    // 3. A Request object whose URL is not http(s), or whose method is not
    // GET: TypeError.
    for (requests) |info| {
        if (info != .request) continue;
        const request: *InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(info.request) orelse return error.TypeError));
        if (!isHttpScheme(request.currentUrl()) or !std.mem.eql(u8, request.method, "GET")) return error.TypeError;
    }
    // 5.1-5.4. Each request, made anew with Request's constructor: its URL
    // must be http(s); requestList keeps its request.
    const objects = try allocator.alloc(*runtime.Instance, requests.len);
    defer allocator.free(objects);
    var made: usize = 0;
    const stored = try allocator.alloc(records.StoredRequest, requests.len);
    var stored_made: usize = 0;
    defer {
        for (stored[0..stored_made]) |*s| s.deinit(allocator);
        allocator.free(stored);
    }
    for (requests) |info| {
        const object = try interfaces.Request.call_constructor(realm, info, webidl.Opt(dictionaries.RequestInit).notPassed());
        // Wrapped at once: fetch() is handed it, and the collector owns it.
        const wrapper = engine.retainValue(realm, runtime.JSValue.fromInstance(object)) catch |err| {
            object.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(object));
            return err;
        };
        wrapper.release();
        objects[made] = object;
        made += 1;
        const request: *InternalRequest = @ptrCast(@alignCast(dom.fetch_objects.requestOf(object) orelse return error.TypeError));
        if (!isHttpScheme(request.currentUrl())) return error.TypeError;
        stored[stored_made] = try storedRequestOf(allocator, request);
        stored_made += 1;
    }
    const op = try PutOp.create(realm, handle, stored[0..stored_made], null);
    // The op has the requests now.
    stored_made = 0;
    defer op.release();
    // 5.6. Fetch each; its response checked, then its body read.
    for (objects[0..made], 0..) |object, index| {
        const fetched = interfaces.WindowOrWorkerGlobalScope.call_fetch(global, .{ .request = object }, webidl.Opt(dictionaries.RequestInit).notPassed()) catch |err| {
            op.failWith(err);
            break;
        };
        op.reactToFetch(fetched, index) catch |err| {
            op.failWith(err);
            break;
        };
    }
    op.maybeCommit();
    return op.promise();
}

/// put()'s and addAll()'s wait: each response's checks and body, then one
/// Batch Cache Operations of put operations, then the promise settled.
/// Reference counted, on its realm's thread: the creator holds one, each
/// pending reaction one.
const PutOp = struct {
    allocator: Allocator,
    realm: runtime.Context,
    handle: CacheHandle,
    capability: engine.PromiseCapability,
    /// The promise, held for the caller.
    held: ?engine.Owned,
    refs: u32 = 1,
    slots: []Slot,
    settled: bool = false,

    const Slot = struct {
        request: records.StoredRequest,
        response: ?records.StoredResponse = null,
        read: bool = false,
    };

    /// An op for `requests` (taken) and, for put(), their `responses`
    /// (taken; addAll()'s come from its fetches).
    fn create(realm: runtime.Context, handle: CacheHandle, requests: []const records.StoredRequest, responses: ?[]const records.StoredResponse) !*PutOp {
        const allocator = realm.allocator;
        const self = try allocator.create(PutOp);
        errdefer allocator.destroy(self);
        const slots = try allocator.alloc(Slot, requests.len);
        errdefer allocator.free(slots);
        var capability = try engine.createPromise(realm);
        errdefer engine.releasePromiseCapability(&capability);
        const held = try engine.retainValue(realm, capability.promise);
        errdefer held.release();
        try handle.storage.retain(handle.cache);
        for (requests, slots, 0..) |request, *slot, i| slot.* = .{ .request = request, .response = if (responses) |r| r[i] else null };
        self.* = .{ .allocator = allocator, .realm = realm, .handle = handle, .capability = capability, .held = held, .slots = slots };
        return self;
    }

    fn retain(self: *PutOp) *PutOp {
        self.refs += 1;
        return self;
    }

    fn release(self: *PutOp) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        for (self.slots) |*slot| {
            slot.request.deinit(self.allocator);
            if (slot.response) |*r| r.deinit(self.allocator);
        }
        self.allocator.free(self.slots);
        engine.releasePromiseCapability(&self.capability);
        if (self.held) |h| h.release();
        self.handle.storage.release(self.handle.cache);
        self.allocator.destroy(self);
    }

    /// The promise, for the caller (taken once).
    fn promise(self: *PutOp) runtime.JSValue {
        const held = self.held.?;
        self.held = null;
        return held.take();
    }

    fn reject(self: *PutOp, reason: runtime.JSValue) void {
        if (self.settled) return;
        self.settled = true;
        engine.rejectPromise(&self.capability, reason) catch {};
    }

    fn rejectWithTypeError(self: *PutOp, message: []const u8) void {
        if (self.settled) return;
        const exception = engine.createSimpleException(self.realm, .TypeError, message) catch return;
        defer exception.release();
        self.reject(exception.borrow());
    }

    /// An error from a step of ours (not a promise's reason).
    fn failWith(self: *PutOp, err: anyerror) void {
        log.debug("a cache put failed: {s}", .{@errorName(err)});
        self.rejectWithTypeError("The cache operation failed");
    }

    /// Every slot has its response and body: Batch Cache Operations, then
    /// the promise settled (put() step 19.2.3, addAll() step 7.6.3).
    fn maybeCommit(self: *PutOp) void {
        if (self.settled) return;
        for (self.slots) |slot| if (!slot.read) return;
        self.settled = true;
        const operations = self.allocator.alloc(store_mod.Operation, self.slots.len) catch {
            self.settled = false;
            return self.failWith(error.OutOfMemory);
        };
        defer self.allocator.free(operations);
        for (self.slots, operations) |*slot, *operation| operation.* = .{ .kind = .put, .request = &slot.request, .response = &slot.response.? };
        const browser = html.platform_state.of(self.realm) orelse {
            self.settled = false;
            return self.failWith(error.InvalidStateError);
        };
        _ = self.handle.storage.batch(browser, self.handle.cache, operations) catch |err| {
            const exception = storeException(self.realm, err) catch return;
            defer exception.release();
            engine.rejectPromise(&self.capability, exception.borrow()) catch {};
            return;
        };
        engine.resolvePromise(&self.capability, runtime.JSValue.jsUndefined) catch {};
    }

    /// One reaction of the op: to a fetch, then to its response's body.
    const Item = struct {
        op: *PutOp,
        index: usize,

        fn destroy(self: *Item) void {
            const op = self.op;
            op.allocator.destroy(self);
            op.release();
        }
    };

    const fetch_steps: engine.PromiseReactionSteps = .{
        .fulfilled = fetched,
        .rejected = rejected,
        .dropped = dropped,
    };

    const body_steps: engine.PromiseReactionSteps = .{
        .fulfilled = bodyRead,
        .rejected = rejected,
        .dropped = dropped,
    };

    fn reactTo(self: *PutOp, promise_value: runtime.JSValue, index: usize, steps: *const engine.PromiseReactionSteps) !void {
        const item = try self.allocator.create(Item);
        item.* = .{ .op = self.retain(), .index = index };
        engine.reactToPromise(self.realm, promise_value, steps, item) catch |err| {
            item.destroy();
            return err;
        };
    }

    /// addAll() step 5.6: fetch's promise, `promise_value` (taken).
    fn reactToFetch(self: *PutOp, promise_value: runtime.JSValue, index: usize) !void {
        defer releaseValue(self.realm, promise_value);
        try self.reactTo(promise_value, index, &fetch_steps);
    }

    /// put() step 11: the body's bytes, from `promise_value` (taken).
    fn readBody(self: *PutOp, promise_value: runtime.JSValue, index: usize) !void {
        defer releaseValue(self.realm, promise_value);
        try self.reactTo(promise_value, index, &body_steps);
    }

    /// addAll()'s processResponse: a network error, a status that is not ok
    /// or 206, or Vary: * rejects; otherwise the body is read.
    fn fetched(data: ?*anyopaque, value: runtime.JSValue) void {
        const item: *Item = @ptrCast(@alignCast(data.?));
        const op = item.op;
        const index = item.index;
        if (op.settled) return item.destroy();
        const response = engine.convertToPlatformObject(op.realm, value) orelse {
            op.rejectWithTypeError("fetch() did not give a Response");
            return item.destroy();
        };
        const inner: *InternalResponse = @ptrCast(@alignCast(dom.fetch_objects.responseOf(response) orelse {
            op.rejectWithTypeError("fetch() did not give a Response");
            return item.destroy();
        }));
        if (inner.response_type == .@"error" or inner.status < 200 or inner.status > 299 or inner.status == 206) {
            op.rejectWithTypeError("The response is not ok, or is partial");
            return item.destroy();
        }
        if (varyHasStar(op.allocator, inner) catch true) {
            op.rejectWithTypeError("The response varies on *");
            return item.destroy();
        }
        op.slots[index].response = storedResponseOf(op.allocator, inner) catch {
            op.failWith(error.OutOfMemory);
            return item.destroy();
        };
        if (inner.body == null) {
            op.slots[index].read = true;
            item.destroy();
            return op.maybeCommit();
        }
        // processResponseEndOfBody: the body, read to its end.
        const read = interfaces.Response.call_arrayBuffer(response) catch |err| {
            op.failWith(err);
            return item.destroy();
        };
        defer releaseValue(op.realm, read);
        engine.reactToPromise(op.realm, read, &body_steps, item) catch |err| {
            op.failWith(err);
            return item.destroy();
        };
    }

    fn bodyRead(data: ?*anyopaque, value: runtime.JSValue) void {
        const item: *Item = @ptrCast(@alignCast(data.?));
        const op = item.op;
        const index = item.index;
        defer item.destroy();
        if (op.settled) return;
        const bytes = engine.borrowArrayBufferBytes(op.realm, value) orelse &.{};
        const copy = op.allocator.dupe(u8, bytes) catch return op.failWith(error.OutOfMemory);
        if (op.slots[index].response) |*response| {
            if (response.body) |old| op.allocator.free(old);
            response.body = copy;
        } else op.allocator.free(copy);
        op.slots[index].read = true;
        op.maybeCommit();
    }

    /// A fetch or a body read rejected: so does the op, with its reason.
    fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
        const item: *Item = @ptrCast(@alignCast(data.?));
        const op = item.op;
        defer item.destroy();
        op.reject(reason);
    }

    fn dropped(data: ?*anyopaque) void {
        const item: *Item = @ptrCast(@alignCast(data.?));
        item.destroy();
    }
};

/// Release a promise an IDL member handed back (a hold of the caller's).
fn releaseValue(realm: runtime.Context, value: runtime.JSValue) void {
    const owned: engine.Owned = .{ .value = value };
    _ = realm;
    owned.release();
}
