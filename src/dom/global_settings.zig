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

/// One kind of global's answers. Each getter is handed a global `owns`
/// accepted.
pub const Settings = struct {
    /// Whether `global` is a global of this kind.
    owns: *const fn (global: *runtime.Instance) bool,
    /// The settings object's origin, serialized. Owned by the caller,
    /// allocated with `global.ctx.allocator`.
    origin: *const fn (global: *runtime.Instance) anyerror!runtime.USVString,
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
    /// The user agent's cookie jar, as the global's settings object reaches
    /// it - null where there is none (a global no Browser made).
    cookie_jar: ?*const fn (global: *runtime.Instance) ?*cookiestore.CookieJar = null,
    /// The settings object's policy container (HTML 7.1.6): a Window's
    /// associated Document's, a WorkerGlobalScope's own. Borrowed; null where
    /// the global has none.
    policy_container: ?*const fn (global: *runtime.Instance) ?*const fetch.internal.PolicyContainer = null,
};

/// The cookie jar `global`'s settings object reaches, if any.
pub fn cookieJarOf(global: *runtime.Instance) ?*cookiestore.CookieJar {
    const settings = of(global) orelse return null;
    const get = settings.cookie_jar orelse return null;
    return get(global);
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
    }
};

/// Read `global`'s settings object as a request's client. A global no kind
/// owns is a client that knows nothing: the request keeps "client" for its
/// origin and referrer, has no traversable and no cookie jar.
pub fn requestClient(global: *runtime.Instance) error{OutOfMemory}!Client {
    const allocator = global.ctx.allocator;
    var client: Client = .{ .allocator = allocator };
    const settings = of(global) orelse return client;
    // The origin, serialized; one the global does not know yet is left
    // unset.
    if (settings.origin(global)) |origin| {
        if (origin.len == 0) allocator.free(origin) else client.request.origin = origin;
    } else |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
    }
    // The referrer source: the realm's document URL - a worker realm's is
    // its creation URL.
    client.request.referrer_source = global.ctx.documentUrl();
    // A Window stands in for its navigable's traversable.
    if (std.mem.eql(u8, global.vtable.name, "Window")) client.request.traversable = @ptrCast(global);
    client.request.cookie_jar = cookieJarOf(global);
    // The policy container "populate request from client" step 3 clones.
    if (settings.policy_container) |container_of| client.request.policy_container = container_of(global);
    // CSP 2.4.2: the global its requests' violations are reported to.
    client.request.csp_violation_reporter = @import("csp_violations.zig").reporterFor(global);
    // Fetch "report timing": the global its requests' resource timing is
    // marked for (Resource Timing 4).
    client.request.timing_reporter = @import("performance_timeline.zig").timingReporterFor(global);
    return client;
}

/// A Window and a WorkerGlobalScope - with room to spare for the next kind.
const capacity = 4;

var installed: [capacity]?Settings = @splat(null);

/// Called by each kind of global. Idempotent: a kind is recognised by its
/// `owns` function and installed once.
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
