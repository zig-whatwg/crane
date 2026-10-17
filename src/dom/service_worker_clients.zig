//! Service worker clients made when their realms are (Service Workers 2.4,
//! 2.5): every window and worker environment is a service worker client from
//! its creation, its active service worker decided then - from the
//! navigation's or the worker's reserved client, which Handle Fetch may have
//! made controlled, or inherited from its creator for a document no fetch
//! went through HTTP for.
//!
//! Clients are the service worker module's state (a Browser's manager), and
//! the realms are made by navigation (HTMLIFrameElement) and the worker host,
//! which may not import it - so the ServiceWorkerContainer impl installs its
//! steps here, once, at process start, and those call them. The handles are
//! opaque here and to every caller: a caller only holds, hands on, or
//! releases one.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#control-and-use
//! Spec: https://html.spec.whatwg.org/multipage/browsing-the-web.html#create-navigation-params-by-fetching
//! Spec: https://html.spec.whatwg.org/multipage/workers.html#run-a-worker
//!
//! lint-impls: hook for ServiceWorkerContainer

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const fetch = @import("fetch");

/// What kind of client a realm is.
pub const ClientKind = enum { window, dedicated_worker, shared_worker };

/// A realm becoming a client: what it is, as its creator knows it.
pub const ClientInit = struct {
    kind: ClientKind,
    /// The environment's creation URL: the document's URL (a navigation's
    /// response's), the worker's script response's. BORROWED for the call.
    creation_url: []const u8,
    /// Its origin, serialized - "null" for an opaque one, which makes no
    /// client. BORROWED for the call.
    origin: []const u8,
    secure_context: bool,
    /// The handle `reserve` gave for the fetch that made this realm's
    /// document or script, TAKEN: the client adopts its reserved
    /// environment, if Handle Fetch made one. Null: no fetch went through
    /// HTTP (about:blank, about:srcdoc, data:, blob:).
    reserved: ?*anyopaque = null,
    /// A window's creator, on this thread: the realm of the document whose
    /// client's active service worker a document no fetch went through HTTP
    /// for inherits (SW 2.5.1), when same origin. Null: none.
    creator: ?runtime.Context = null,
};

/// What the service worker owner supplies.
pub const Implementation = struct {
    /// "Create navigation params by fetching" (a navigation's reserved
    /// client) and "run a worker" step 7 (a worker's inside settings, before
    /// its script is fetched), on the creator's thread: a handle the caller
    /// OWNS until it hands it to `created` or `release`s it. `url` is the
    /// URL fetched. Null: no Browser's service workers to reserve with.
    reserve: *const fn (creator: runtime.Context, kind: ClientKind, url: []const u8) ?*anyopaque,
    /// The route the reserved client's request takes to Handle Fetch.
    route_of_reserved: *const fn (reserved: *anyopaque) ?fetch.internal.ServiceWorkerRoute,
    /// `realm` is a service worker client from now on, before any of its
    /// script runs. Takes `init.reserved`.
    created: *const fn (realm: runtime.Context, init: ClientInit) void,
    /// A handle never handed to `created`: its reserved environment, if
    /// Handle Fetch made one, is discarded (HTML "environment discarding
    /// steps").
    release: *const fn (reserved: *anyopaque) void,
    /// "Populate request from client" for `global`'s settings object: the
    /// route its requests take while a service worker controls it.
    route_for_global: *const fn (global: *runtime.Instance) ?fetch.internal.ServiceWorkerRoute,
    /// How many service worker registrations the Browser whose scope is
    /// `scope` has in its registration map (the WPT runner's question: a
    /// file that leaves one gets a fresh Browser after it).
    registration_count: *const fn (scope: *runtime.BrowserScope) usize,
};

// process-wide: one function table the ServiceWorkerContainer impl installs once at process start (crane.Process), the same for every Browser and thread; the clients themselves are each Browser's (its service worker manager)
var implementation: ?Implementation = null;

/// Called by ServiceWorkerContainer's installHooks, once, at process start.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// A reserved client for a fetch from `creator`'s thread; null when there
/// is no owner.
pub fn reserve(creator: runtime.Context, kind: ClientKind, url: []const u8) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.reserve(creator, kind, url);
}

/// The route a request for the reserved client `reserved` takes.
pub fn routeOfReserved(reserved: ?*anyopaque) ?fetch.internal.ServiceWorkerRoute {
    const handle = reserved orelse return null;
    const impl = implementation orelse return null;
    return impl.route_of_reserved(handle);
}

/// `realm` is a client from now on. Takes `init.reserved`.
pub fn created(realm: runtime.Context, init: ClientInit) void {
    const impl = implementation orelse return;
    impl.created(realm, init);
}

/// Let go of a reserved client never handed to `created`.
pub fn release(reserved: ?*anyopaque) void {
    const handle = reserved orelse return;
    const impl = implementation orelse return;
    impl.release(handle);
}

/// How many service worker registrations the Browser whose scope is `scope`
/// holds; 0 with nothing installed.
pub fn registrationCount(scope: *runtime.BrowserScope) usize {
    const impl = implementation orelse return 0;
    return impl.registration_count(scope);
}

/// The route `global`'s requests take, while a service worker controls it.
pub fn routeForGlobal(global: *runtime.Instance) ?fetch.internal.ServiceWorkerRoute {
    const impl = implementation orelse return null;
    return impl.route_for_global(global);
}

test "with nothing installed, no client is reserved and no request is routed" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    var realm: runtime.ContextData = undefined;
    try std.testing.expect(reserve(&realm, .window, "https://a.test/") == null);
    try std.testing.expect(routeOfReserved(null) == null);
    release(null);
    created(&realm, .{ .kind = .window, .creation_url = "about:blank", .origin = "null", .secure_context = true });
    var scope = runtime.BrowserScope.init(std.testing.allocator);
    defer scope.deinit();
    try std.testing.expectEqual(@as(usize, 0), registrationCount(&scope));
}
