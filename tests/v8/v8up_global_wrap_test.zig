//! A realm's global object on V8 15.7 (lane v8up; tmp/plans/v8-global-object-design.md 2.3 and 2.6).
//!
//! V8 >= 14 gives the embedder no path to a context's JSGlobalObject (crbug.com/333672197): the V1
//! `GetPrototype` on the global proxy that Crane used to reach it is `Object.getPrototypeOf` now, and answers
//! Window.prototype. These pin what script observes of the global object, through the paths a browser has.
//!
//! 2.3 (the integrator's ruling, 2026-11-11 00:48 UTC, golden rule 2): a function made in a realm whose
//! WindowProxy went on to a later realm (a navigation that makes a new Window) reads its OWN Window's members
//! contextually - `crypto`, not `window.crypto` - as the spec says (ECMA-262 GetBindingValue of the global
//! object record: the binding object is the old global object, so WebIDL's `this` is the old Window) and as
//! Firefox 159 and Safari 27 do; `window.X` goes through the WindowProxy to the new Window. Chrome 156 reads
//! the new Window, because V8 replaces a global-object receiver by the reused proxy (objects.cc
//! GetPropertyWithAccessor). Probe: tmp/probes/v8up-detached/. The Crane test
//! tests/wpt/crane/v8up-old-realm-contextual-window.html carries the rows that need a document.
//!
//! 2.6: a realm's built-in functions (Streams' size functions, engine.globalBuiltinFunction) are kept by its
//! own global object - on its retained store, which the global keeps through its GlobalAnchor - never through
//! the WindowProxy: a private set through `context->Global()` lands on whichever global object the proxy is
//! attached to now, so after a navigation handed the proxy on the old realm read and wrote the NEW realm's
//! slot (streams/queuing-strategies-size-function-navigation.window.js 0/24; Firefox and Safari 24/24).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const no_hooks: protocol.HostHooks = .{};

fn windowRealm(agent: *protocol.Agent, global_this: protocol.GlobalThis) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://v8up.test",
        .global_this = global_this,
        .create_global_object = WindowHost.createGlobalObject,
    });
}

fn evalOwned(r: runtime.Context, source: []const u8) !protocol.Owned {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScript(r, .{ .utf8 = source }, "", null, reports.reporter());
    try testing.expectEqual(@as(usize, 0), reports.count);
    return got;
}

fn expectOk(r: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed cases: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

test "2.3: a function of a realm whose WindowProxy went on reads its own Window's members contextually" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    // The page that keeps the old realm's function, as a parent keeps a frame's.
    const keeper = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(keeper, .global_detached);

    const old = try windowRealm(agent, .new_window_proxy);
    {
        // A var of the old global, what its Window had, and a function that reads contextually there.
        const reader = try evalOwned(old,
            \\var marker = "old";
            \\var saved = { crypto, navigator, performance };
            \\(function (source) { return eval(source); })
        );
        defer reader.release();
        const keeper_global = try evalOwned(keeper, "globalThis");
        defer keeper_global.release();
        try protocol.setProperty(keeper, keeper_global.value, "reader", reader.value);
    }

    // The navigation's new Window behind the same WindowProxy; the old realm ends as a navigation's does.
    const new = try windowRealm(agent, .{ .window_proxy_of = old });
    defer protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(old, .global_detached);

    try expectOk(keeper,
        \\const failures = [];
        \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
        \\check("a var of the old global", reader("marker"), "old");
        \\for (const k of ["crypto", "navigator", "performance"]) {
        \\  check(k + " read contextually is the old Window's", reader(k + " === saved." + k), true);
        \\  check("window." + k + " is the new Window's", reader("window." + k + " === saved." + k), false);
        \\  check("self." + k + " is the new Window's", reader("self." + k + " === saved." + k), false);
        \\  check("globalThis." + k + " is the new Window's", reader("globalThis." + k + " === saved." + k), false);
        \\}
        \\check("window has no old var", reader("window.marker"), undefined);
        \\failures.join("; ") || "ok"
    );
    try expectOk(keeper, "delete globalThis.reader ? 'ok' : 'not deleted'");
}

test "2.6: a realm's count queuing strategy size function is one function, kept by its global object" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    try expectOk(realm,
        \\const a = new CountQueuingStrategy({ highWaterMark: 1 }).size;
        \\const b = new CountQueuingStrategy({ highWaterMark: 2 }).size;
        \\a === b && typeof a === "function" && Object.getPrototypeOf(a) === Function.prototype ? "ok" : "not one function of this realm"
    );
}

test "2.6: after a navigation hands the WindowProxy on, each realm's size functions are its own" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    // The page that keeps the old realm's strategies, as a parent keeps a frame's.
    const keeper = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(keeper, .global_detached);

    const old = try windowRealm(agent, .new_window_proxy);
    {
        // One strategy whose size the old realm reads before the hand-on (cached), and one it reads
        // first after it (lazy), for each kind.
        const held = try evalOwned(old,
            \\({ proto: Function.prototype,
            \\   cachedCount: new CountQueuingStrategy({ highWaterMark: 1 }),
            \\   lazyCount: new CountQueuingStrategy({ highWaterMark: 1 }),
            \\   lazyBytes: new ByteLengthQueuingStrategy({ highWaterMark: 1 }),
            \\   before: new CountQueuingStrategy({ highWaterMark: 1 }).size })
        );
        defer held.release();
        const keeper_global = try evalOwned(keeper, "globalThis");
        defer keeper_global.release();
        try protocol.setProperty(keeper, keeper_global.value, "held", held.value);
    }

    // The navigation's new Window behind the same WindowProxy; the old realm ends as a navigation's does.
    const new = try windowRealm(agent, .{ .window_proxy_of = old });
    defer protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(old, .global_detached);

    // The old realm reads first (the WPT's "independent of pre-navigation instance" order) ...
    try expectOk(keeper,
        \\const failures = [];
        \\function check(name, got) { if (!got) failures.push(name); }
        \\const count = held.cachedCount.size, lazy = held.lazyCount.size, bytes = held.lazyBytes.size;
        \\check("the cached count size is the old realm's one function", count === held.before);
        \\check("a lazy count size is the old realm's one function", lazy === held.before);
        \\check("the old count size's prototype is the old realm's", Object.getPrototypeOf(count) === held.proto);
        \\check("the old byte length size's prototype is the old realm's", Object.getPrototypeOf(bytes) === held.proto);
        \\check("the old byte length size still measures", bytes({ byteLength: 17 }) === 17);
        \\failures.join("; ") || "ok"
    );
    // ... and the new realm's are its own, not the old realm's.
    try expectOk(new,
        \\const count = new CountQueuingStrategy({ highWaterMark: 1 }).size;
        \\const bytes = new ByteLengthQueuingStrategy({ highWaterMark: 1 }).size;
        \\Object.getPrototypeOf(count) === Function.prototype && Object.getPrototypeOf(bytes) === Function.prototype &&
        \\  count === new CountQueuingStrategy({ highWaterMark: 2 }).size ? "ok" : "the new realm got another realm's size function"
    );
    try expectOk(keeper,
        \\const before = held.before;
        \\delete globalThis.held;
        \\typeof before === "function" ? "ok" : "lost"
    );
}

/// A frame's Window realm, made inside its parent's script as HTML makes a navigable's (protocol.runInRealm):
/// a realm with a parent gets its interface objects lazily (global_constructor_handler), as the snapshot's do.
const FrameRealm = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    global_this: protocol.GlobalThis = .new_window_proxy,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *FrameRealm) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *FrameRealm = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://v8up.test",
            .global_this = self.global_this,
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

test "2.3 gap (b3b): a lazy interface object read contextually by a frame realm whose WindowProxy went on is that realm's" {
    // A native data property on the global (the lazy interface objects, SetLazyDataProperty) gets V8's detached
    // copy of the proxy as Holder() for a contextual read in a detached context (GetHolderForApi,
    // api-callbacks-inl.h): contextless, so lazyConstructorGetter's GetCreationContext(holder) fails and the read
    // answered undefined. The spec's answer is the old realm's interface object (its global's own property).
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const parent = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(parent, .global_detached);

    var old_frame: FrameRealm = .{ .agent = agent, .parent = parent };
    const old = try old_frame.make();
    {
        // Nothing reads DOMParser in the old realm before the navigation: its lazy property is untouched.
        const reader = try evalOwned(old, "(function (source) { return eval(source); })");
        defer reader.release();
        const parent_global = try evalOwned(parent, "globalThis");
        defer parent_global.release();
        try protocol.setProperty(parent, parent_global.value, "reader", reader.value);
    }
    var new_frame: FrameRealm = .{ .agent = agent, .parent = parent, .global_this = .{ .window_proxy_of = old } };
    const new = try new_frame.make();
    defer protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(old, .global_detached);

    try expectOk(parent,
        \\const failures = [];
        \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
        \\check("typeof DOMParser, read contextually first in the old realm", reader("typeof DOMParser"), "function");
        \\check("it is the old realm's, not the new Window's", reader("DOMParser !== window.DOMParser"), true);
        \\check("and read again, the same object", reader("DOMParser === DOMParser"), true);
        \\failures.join("; ") || "ok"
    );
    try expectOk(parent, "delete globalThis.reader ? 'ok' : 'not deleted'");
}
