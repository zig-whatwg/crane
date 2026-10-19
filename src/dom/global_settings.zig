//! What the WindowOrWorkerGlobalScope mixin reads through "this's relevant
//! settings object": a global's origin, whether it is a secure context and
//! cross-origin isolated, and the objects it hands out once per global
//! (IndexedDB's factory, CacheStorage, Performance), the cookie jar it
//! reaches, and - `requestClient` - all of that as a fetch request's client.
//!
//! HTML gives every global an environment settings object, and each kind of
//! global - a Window, a WorkerGlobalScope - defines how its settings answer.
//! That state is the global's, the mixin's members are implemented once in
//! the mixin impl, and neither may reach into the other's impl - so each
//! global installs its answers here, as `range_boundaries.zig` does for the
//! range subclasses AbstractRange reads.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#windoworworkerglobalscope-mixin
//!
//! lint-impls: hook for Window, WorkerGlobalScope

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const cookiestore = @import("cookiestore");
const fetch = @import("fetch");
const storage = @import("storage");
const origin_record = @import("origin_record.zig");
const OriginRecord = origin_record.OriginRecord;

/// One kind of global's answers. Each getter is handed a global `owns`
/// accepted.
pub const Settings = struct {
    /// Whether `global` is a global of this kind.
    owns: *const fn (global: *runtime.Instance) bool,
    /// The settings object's origin, serialized. Owned by the caller,
    /// allocated with `global.ctx.allocator`.
    origin: *const fn (global: *runtime.Instance) anyerror!runtime.USVString,
    /// The settings object's origin as the object it is (dom.origin_record):
    /// a Window's is its associated Document's record, whose identity and
    /// domain `origin`'s serialization does not carry. BORROWED; null where
    /// this kind of global keeps none.
    origin_record: ?*const fn (global: *runtime.Instance) ?*OriginRecord = null,
    /// The settings object's execution environment is a secure context.
    is_secure_context: *const fn (global: *runtime.Instance) bool,
    /// The settings object's cross-origin isolated capability.
    cross_origin_isolated: *const fn (global: *runtime.Instance) bool,
    /// The global's IDBFactory; null where this kind of global has none yet.
    indexed_db: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The global's CacheStorage; null where this kind of global has none yet.
    caches: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The global's Performance; null where this kind of global has none yet.
    performance: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The settings object's time origin (HR-Time), as the global recorded
    /// it when it was made: a monotonic moment in nanoseconds, not yet
    /// coarsened. Null where this kind of global records none.
    time_origin: ?*const fn (global: *runtime.Instance) ?i64 = null,
    /// The global's Crypto, retained as a traced child of this global.
    crypto: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The global's trusted type policy factory (Trusted Types 4.1), retained
    /// as a traced child of this global.
    trusted_types: ?*const fn (global: *runtime.Instance) anyerror!*runtime.Instance = null,
    /// The user agent's cookie jar, as the global's settings object reaches
    /// it - null where there is none (a global no Browser made).
    cookie_jar: ?*const fn (global: *runtime.Instance) ?*cookiestore.CookieJar = null,
    /// The settings object's policy container (HTML 7.1.6): a Window's
    /// associated Document's, a WorkerGlobalScope's own. Borrowed; null where
    /// the global has none.
    policy_container: ?*const fn (global: *runtime.Instance) ?*const fetch.internal.PolicyContainer = null,
    /// Referrer Policy 8.3's client source. BORROWED, valid only for the
    /// requestClient call. An absent hook uses the realm's documentUrl().
    referrer_source: ?*const fn (global: *runtime.Instance) ?[]const u8 = null,
    /// The cookie URL (`cookieUrlOf`). BORROWED, valid until script runs.
    /// An absent hook uses the realm's creation URL.
    cookie_url: ?*const fn (global: *runtime.Instance) ?[]const u8 = null,
    /// The global's native Reporting queues and observer registrations.
    reporting: ?*const fn (global: *runtime.Instance) ?*@import("reporting.zig").State = null,
    /// The settings object's fetch group (Fetch 2.4): its in-flight
    /// keepalive bytes. Null where this kind of global keeps none.
    fetch_group: ?*const fn (global: *runtime.Instance) ?*@import("document_fetches.zig").FetchGroup = null,
    /// Mixed Content 4.3 for this settings object, including embedding
    /// documents. Absence means this kind of global does not prohibit.
    prohibits_mixed_security_contexts: ?*const fn (global: *runtime.Instance) error{OutOfMemory}!bool = null,
    /// Fetch "determine the network partition key" steps 1-4: the settings
    /// object's top-level origin obtained as a site (HTML "obtain a site"),
    /// serialized. OWNED by the caller, allocated with `global.ctx.allocator`.
    /// Null when there is none or it is opaque - a request with no site
    /// bypasses the partitioned stores (Codex row 44, ANSWER Q4). Null where
    /// this kind of global keeps none.
    top_level_site: ?*const fn (global: *runtime.Instance) error{OutOfMemory}!?[]u8 = null,
    /// Permissions 5.1's key input: the settings object's top-level origin,
    /// serialized and OWNED by the caller (global.ctx.allocator). Null when
    /// absent or opaque. A site or the requesting origin cannot replace it.
    top_level_origin: ?*const fn (global: *runtime.Instance) error{OutOfMemory}!?[]u8 = null,
    /// Storage "obtain a storage key for non-storage purposes" for the
    /// settings object, as `storage.StorageKey.serialize` writes it: its
    /// origin, its top-level origin obtained as a site ("null" when opaque)
    /// and its "has cross-site ancestor" (HTML 8.1.3.2). Computed once per
    /// environment and kept by the global: BORROWED, valid while the global
    /// keeps its document (a Window) or lives (a worker). Null where this
    /// kind of global keeps none.
    storage_key: ?*const fn (global: *runtime.Instance) error{OutOfMemory}!?[]const u8 = null,
};

/// `global`'s settings object's storage key for non-storage purposes,
/// serialized (`Settings.storage_key`): BORROWED from the global. Null where
/// its kind keeps none - a global no Browser made, a kind with no hook.
pub fn serializedStorageKeyOf(global: *runtime.Instance) error{OutOfMemory}!?[]const u8 {
    const settings = of(global) orelse return null;
    const key_of = settings.storage_key orelse return null;
    return key_of(global);
}

/// Storage "obtain a storage key for non-storage purposes", given `global`'s
/// settings object: its origin, top-level site and has-cross-site-ancestor
/// bit (storage.StorageKey). BORROWED from the global, as
/// `serializedStorageKeyOf`. What the blob URL store, SharedWorker matching
/// and BroadcastChannel compare.
/// https://storage.spec.whatwg.org/#obtain-a-storage-key-for-non-storage-purposes
pub fn storageKeyForNonStoragePurposesOf(global: *runtime.Instance) error{OutOfMemory}!?storage.StorageKey {
    const serialized = (try serializedStorageKeyOf(global)) orelse return null;
    return storage.StorageKey.parse(serialized);
}

/// Storage "obtain a storage key", given `global`'s settings object: its key
/// for non-storage purposes, or null - failure - for an opaque origin, or an
/// opaque top-level site Crane cannot tell apart from another
/// (storage.obtainStorageKey). BORROWED from the global. What a storage area
/// is found by: localStorage's and sessionStorage's shelves, and IndexedDB's.
/// https://storage.spec.whatwg.org/#obtain-a-storage-key
pub fn storageKeyOf(global: *runtime.Instance) error{OutOfMemory}!?storage.StorageKey {
    const key = (try storageKeyForNonStoragePurposesOf(global)) orelse return null;
    return storage.obtainStorageKey(key);
}

pub fn topLevelOriginOf(global: *runtime.Instance) error{OutOfMemory}!?[]u8 {
    const settings = of(global) orelse return null;
    const origin_of = settings.top_level_origin orelse return null;
    return origin_of(global);
}

/// `global`'s settings object's top-level site, serialized and OWNED
/// (`global.ctx.allocator`); null where none is known or it is opaque.
pub fn topLevelSiteOf(global: *runtime.Instance) error{OutOfMemory}!?[]u8 {
    const settings = of(global) orelse return null;
    const site_of = settings.top_level_site orelse return null;
    return site_of(global);
}

/// `global`'s settings object's origin record (borrowed), or null where its
/// kind keeps none.
pub fn originRecordOf(global: *runtime.Instance) ?*OriginRecord {
    const settings = of(global) orelse return null;
    const get = settings.origin_record orelse return null;
    return get(global);
}

/// `global`'s settings object's origin record with its serialization
/// resolved - from the settings object's origin - for a document made with
/// that origin (new Document(), parseHTMLUnsafe()). BORROWED: the document
/// retains it. Null where the global's kind keeps no record.
pub fn shareableOriginOf(global: *runtime.Instance) error{OutOfMemory}!?*OriginRecord {
    const settings = of(global) orelse return null;
    const get = settings.origin_record orelse return null;
    const record = get(global) orelse return null;
    if (record.serialized == null) {
        const serialized = settings.origin(global) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            // Not known yet: the record stays unresolved.
            else => return record,
        };
        defer global.ctx.allocator.free(serialized);
        try record.resolve(serialized);
    }
    return record;
}

/// HTML "same origin-domain" for the origins of two globals' settings
/// objects - a Window's is its associated Document's - read from the
/// settings themselves, never through an access-checked IDL getter: the
/// serializations and the records, whose identity and domains decide. False
/// when either global's kind is unknown or its origin unreadable.
/// Spec: https://html.spec.whatwg.org/multipage/browsers.html#same-origin-domain
pub fn sameOriginDomain(a: *runtime.Instance, b: *runtime.Instance) bool {
    if (a == b) return true;
    const a_settings = of(a) orelse return false;
    const b_settings = of(b) orelse return false;
    // Step 1 before any serialization: one record is one origin, and the
    // engine asks this on every access to another realm's WindowProxy or
    // Location (cross_origin.isPlatformObjectSameOrigin).
    if (sharedRecord(a, b)) return true;
    const a_origin = a_settings.origin(a) catch return false;
    defer a.ctx.allocator.free(a_origin);
    const b_origin = b_settings.origin(b) catch return false;
    defer b.ctx.allocator.free(b_origin);
    return origin_record.sameOriginDomain(
        .{ .serialized = a_origin, .record = originRecordOf(a) },
        .{ .serialized = b_origin, .record = originRecordOf(b) },
    );
}

/// Whether both globals' settings objects hold one origin record.
fn sharedRecord(a: *runtime.Instance, b: *runtime.Instance) bool {
    const a_record = originRecordOf(a) orelse return false;
    return originRecordOf(b) == a_record;
}

pub fn reportingOf(global: *runtime.Instance) ?*@import("reporting.zig").State {
    const settings = of(global) orelse return null;
    const get = settings.reporting orelse return null;
    return get(global);
}

/// `global`'s settings object's fetch group, if its kind keeps one.
pub fn fetchGroupOf(global: *runtime.Instance) ?*@import("document_fetches.zig").FetchGroup {
    const settings = of(global) orelse return null;
    const get = settings.fetch_group orelse return null;
    return get(global);
}

/// The cookie jar `global`'s settings object reaches, if any.
pub fn cookieJarOf(global: *runtime.Instance) ?*cookiestore.CookieJar {
    const settings = of(global) orelse return null;
    const get = settings.cookie_jar orelse return null;
    return get(global);
}

/// The URL document.cookie and the Cookie Store API read and write cookies
/// for: the settings object's creation URL - the document's URL when it was
/// made, which a same-document change (pushState, replaceState, a fragment
/// navigation) leaves - or, for an about:blank or about:srcdoc document, its
/// creator's. The spec text says the creation URL (Cookie Store's get() step
/// 4, "process cookie changes" 1.1), which is about:blank for such a frame;
/// the browsers inherit the creator's, by golden rule 2: Blink
/// DocumentInit::GetCookieUrl (the owner document's CookieURL for
/// about:blank and srcdoc), WebKit Document::initSecurityContext
/// (setCookieURL(ownerDocument->cookieURL())), Gecko the principal inherited
/// from the creator (all three pass
/// cookiestore/cookieStore_get_set_across_frames.https.html, wpt.fyi stable
/// 2026-10). BORROWED, valid until script runs; null for none.
pub fn cookieUrlOf(global: *runtime.Instance) ?[]const u8 {
    if (of(global)) |settings| if (settings.cookie_url) |get| return get(global);
    return global.ctx.creationUrl() orelse global.ctx.documentUrl();
}

/// `global`'s settings object as a request's client: what
/// `fetch.internal.populateRequestFromClient` reads. `deinit` frees the
/// origin it owns; the rest is borrowed from the global.
pub const Client = struct {
    request: fetch.internal.RequestClient = .{},
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Client) void {
        if (self.request.origin) |origin| self.allocator.free(origin);
        self.request.origin = null;
        if (self.request.top_level_site) |site| self.allocator.free(site);
        self.request.top_level_site = null;
    }
};

/// Read `global`'s settings object as a request's client. A global no kind
/// owns is a client that knows nothing: the request keeps "client" for its
/// origin and referrer, has no traversable and no cookie jar.
pub fn requestClient(global: *runtime.Instance) error{OutOfMemory}!Client {
    const allocator = global.ctx.allocator;
    var client: Client = .{ .allocator = allocator };
    errdefer client.deinit();
    const settings = of(global) orelse return client;
    // The origin, serialized; one the global does not know yet is left
    // unset.
    if (settings.origin(global)) |origin| {
        if (origin.len == 0) allocator.free(origin) else client.request.origin = origin;
    } else |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
    }
    // Fetch "determine the network partition key": the top-level site.
    if (settings.top_level_site) |site_of| client.request.top_level_site = try site_of(global);
    // A srcdoc Window walks to its ancestor document; a worker's realm
    // document URL is already its creation URL (Referrer Policy 8.3).
    client.request.referrer_source = if (settings.referrer_source) |source_of| source_of(global) else global.ctx.documentUrl();
    // A Window stands in for its navigable's traversable.
    if (std.mem.eql(u8, global.vtable.name, "Window")) client.request.traversable = @ptrCast(global);
    client.request.cookie_jar = cookieJarOf(global);
    // The blob URL store a blob: request's blob is obtained from: the
    // global's Browser's (its realm's scope).
    client.request.blob_url_store = @ptrCast(@import("browser_state.zig").blobURLStoreOf(global.ctx));
    // What a blob: request obtains its blob for (Fetch scheme fetch "blob"
    // steps 3-5): the settings object's storage key, BORROWED from the
    // global; and, for a top-level Window, its creation URL - a fetch of it
    // is "top-level-self-fetch".
    client.request.storage_key = try serializedStorageKeyOf(global);
    if (isTopLevelWindow(global)) client.request.top_level_creation_url = global.ctx.creationUrl();
    client.request.network = @import("browser_state.zig").networkOf(global.ctx);
    // The policy container "populate request from client" step 3 clones.
    if (settings.policy_container) |container_of| client.request.policy_container = container_of(global);
    // Mixed Content 4.3 is captured by value, like the policy snapshot.
    if (settings.prohibits_mixed_security_contexts) |prohibits| client.request.prohibits_mixed_security_contexts = try prohibits(global);
    // CSP 2.4.2: the global its requests' violations are reported to.
    client.request.csp_violation_reporter = @import("csp_violations.zig").reporterFor(global);
    // Fetch "report timing": the global its requests' resource timing is
    // marked for (Resource Timing 4).
    client.request.timing_reporter = @import("performance_timeline.zig").timingReporterFor(global);
    // Service Workers "Handle Fetch" step 10: the route of a controlled
    // client's requests to its active service worker.
    client.request.service_worker = @import("service_worker_clients.zig").routeForGlobal(global);
    client.request.integrity_violation_reporter = @import("sri_reporting.zig").reporterFor(global);
    return client;
}

/// Whether `global` is a Window whose navigable is a top-level traversable
/// (its browsing context has no parent).
fn isTopLevelWindow(global: *runtime.Instance) bool {
    if (!std.mem.eql(u8, global.vtable.name, "Window")) return false;
    const context = @import("browser_state.zig").browsingContextOf(global) orelse return false;
    return context.parent == null;
}

/// A Window and a WorkerGlobalScope - with room to spare for the next kind.
const capacity = 4;

var installed: [capacity]?Settings = @splat(null);

/// Called by each kind of global. Idempotent: a kind is recognised by its
/// `owns` function and installed once.
///
/// Keyed by a function pointer, and safe so: a release build folds functions
/// with identical code into one (LLVM), so two `owns` checks distinct in Debug
/// can share an address there, and the second install is dropped - but `of`
/// answers with the FIRST kind whose check accepts the global, so in Debug
/// that second kind, with the same check, is never reached either. (Where a
/// table dispatches to every entry, or keeps the last, keying by one function
/// is wrong: form_controls, activation, document_fetches.)
pub fn install(settings: Settings) void {
    process_start.assertInstalling();
    for (&installed) |*slot| {
        if (slot.*) |existing| {
            if (existing.owns == settings.owns) return;
            continue;
        }
        slot.* = settings;
        return;
    }
    std.debug.panic("global_settings: more than {d} kinds of global", .{capacity});
}

/// The answers for `global`'s kind, or null when no installed kind owns it.
pub fn of(global: *runtime.Instance) ?Settings {
    for (installed) |slot| {
        const settings = slot orelse return null;
        if (settings.owns(global)) return settings;
    }
    return null;
}

var test_owned: runtime.Instance = undefined;

fn testOwns(global: *runtime.Instance) bool {
    return @intFromPtr(global) == @intFromPtr(&test_owned);
}

fn testOrigin(global: *runtime.Instance) anyerror!runtime.USVString {
    _ = global;
    return error.Unexpected;
}

fn testFalse(global: *runtime.Instance) bool {
    _ = global;
    return false;
}

fn testTrue(global: *runtime.Instance) bool {
    _ = global;
    return true;
}

test "kinds that share an owns check: the first installed answers, as a Debug build's table does" {
    // In a release build two kinds' `owns` checks with the same body are one
    // function. The answer must still be the first kind's.
    const saved = installed;
    defer installed = saved;
    installed = @splat(null);
    const global = &test_owned;
    install(.{ .owns = &testOwns, .origin = &testOrigin, .is_secure_context = &testFalse, .cross_origin_isolated = &testFalse });
    install(.{ .owns = &testOwns, .origin = &testOrigin, .is_secure_context = &testTrue, .cross_origin_isolated = &testFalse });
    const settings = of(global) orelse return error.TestExpectedSettings;
    try std.testing.expect(!settings.is_secure_context(global));
}

test "a global no kind owns has no settings, and a kind installs once" {
    const saved = installed;
    defer installed = saved;
    installed = @splat(null);

    // Never dereferenced: `owns` compares the address only.
    const global = &test_owned;
    try std.testing.expect(of(global) == null);

    const settings: Settings = .{ .owns = &testOwns, .origin = &testOrigin, .is_secure_context = &testFalse, .cross_origin_isolated = &testFalse };
    install(settings);
    install(settings);
    try std.testing.expect(of(global) != null);
    try std.testing.expect(installed[1] == null);
}
