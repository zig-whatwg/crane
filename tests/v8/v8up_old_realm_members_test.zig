//! What code of a realm whose WindowProxy went on (a navigation that made a new Window) gets from the members it
//! uses (lane v8up b3e; tmp/plans/v8-global-object-design.md 2.3, the integrator's rulings of 2026-11-11).
//!
//! The Crane test tests/wpt/crane/v8up-old-realm-contextual-window.html failed four cases in a real page while
//! v8up_global_wrap_test's 2.3 cases passed: the receiver rule was right (the members act on the OLD Window), and
//! what failed was what the members then did. These pin the engine's share of that, through the paths a page has:
//!
//! - A DOMException a binding throws there is the OLD realm's (WebIDL "create a DOMException" in the function's
//!   realm). The binding made it by reading `DOMException` and `Reflect` off the context's Global() - for a
//!   navigated-away realm that is the reused WindowProxy, so it got the NEW Window's (lesson
//!   architecture-after-detachglobal-the-old-context-s-global-is-the-new-window-s-proxy.md); and its `stack` by a
//!   script that set a global property through that proxy and read it back in the old global, which has none.
//!   Browser probe tmp/probes/v8up-oldwin3/ (2026-11-11, Chrome 157, Firefox 159, Safari 27): all three throw the
//!   old realm's DOMException for a contextual atob('*') and for the old History's length read from the parent;
//!   Firefox and Safari also for a contextual history.length (Chrome reads the new Window there). Blink makes a
//!   DOMException from its realm's own interface object (V8PerContextData::ConstructorForType) and gives it a
//!   stack with v8::Exception::CaptureStackTrace (V8ThrowDOMException::AttachStackProperty).
//! - A lazy interface object read contextually for the first time there is the OLD realm's (Firefox 159 and
//!   Safari 27 "function"; Chrome 157 undefined, by the V8 mechanism Crane shares - the majority, the
//!   integrator's ruling). The lazy data property's getter gets V8's detached copy of the global proxy as
//!   Holder() (GetHolderForApi), and in a page that copy KEPT the old context as its creation context
//!   (DetachGlobal's ForceSetPrototype gives the proxy a new map and makes only that one contextless): the
//!   receiver rule took it for no Window, and the read was undefined. v8up_global_wrap_test's 2.3 gap case,
//!   whose realms are made afresh, passed; here the agent and every realm are restored from the snapshot, as
//!   a page's frames are.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

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
const ffi = @import("v8").ffi;
/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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

test "a DOMException a binding throws in a realm whose WindowProxy went on is that realm's, with a stack" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    // The page that keeps the old realm's function, as a parent keeps a frame's.
    const keeper = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(keeper, .global_detached);

    const old = try windowRealm(agent, .new_window_proxy);
    {
        const reader = try evalOwned(old,
            \\var savedDOMException = DOMException;
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
        \\function thrown(run) { try { run(); return null; } catch (e) { return e; } }
        \\// The control, in a realm whose WindowProxy is its own.
        \\const live = thrown(() => atob("*"));
        \\check("the live realm's atob('*') throws its own DOMException", live && live.constructor === DOMException, true);
        \\check("with a stack", live && typeof live.stack, "string");
        \\// A binding's error in the old realm: atob is a Window operation used contextually there.
        \\const oldDOMException = reader("savedDOMException");
        \\const e = thrown(() => reader("atob('*')"));
        \\check("the old realm's atob('*') throws", e !== null, true);
        \\check("an InvalidCharacterError", e && e.name, "InvalidCharacterError");
        \\check("made by the old realm's DOMException", e && e.constructor === oldDOMException, true);
        \\check("not the new Window's", e && e.constructor === reader("window.DOMException"), false);
        \\check("with a stack", e && typeof e.stack, "string");
        \\// A DOMException the old realm's script makes itself.
        \\const made = reader("new DOMException('m', 'DataError')");
        \\check("new DOMException in the old realm is its own", made.constructor === oldDOMException, true);
        \\check("and has a stack", typeof made.stack, "string");
        \\check("nothing was left on the new Window", reader("Object.getOwnPropertyNames(window).filter(n => n.startsWith('__domex')).join()"), "");
        \\failures.join("; ") || "ok"
    );
    try expectOk(keeper, "delete globalThis.reader ? 'ok' : 'not deleted'");
}

/// An agent restored from this build's snapshot and its page realm, restored too - the agent every page of
/// the browser and the WPT runner gets (new_global_snapshot_test.zig's SnapshotPage). Null (the test skips)
/// when V8 was started in this process before this test: restoring the snapshot then crashes inside V8.
const SnapshotPage = struct {
    bytes: []u8,
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !?SnapshotPage {
        if (ffi.v8_Platform_IsInitialized()) {
            std.log.warn("skipping: V8 was started in this process before this test; run it in a process of its own", .{});
            return null;
        }
        const io = std.testing.io;
        const file = try std.Io.Dir.cwd().openFile(io, snapshot_path, .{});
        defer file.close(io);
        const size = (try file.stat(io)).size;
        const bytes = try std.heap.c_allocator.alloc(u8, size);
        errdefer std.heap.c_allocator.free(bytes);
        _ = try file.readPositionalAll(io, bytes, 0);
        try test_process.startSnapshot(bytes);
        errdefer test_process.endSnapshot();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = true, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        if (!ffi.v8_Isolate_IsFromSnapshot(@ptrCast(@alignCast(agent)))) return error.AgentNotRestoredFromSnapshot;
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://v8up.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .bytes = bytes, .agent = agent, .realm = realm };
    }

    fn close(self: SnapshotPage) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        test_process.endSnapshot();
        std.heap.c_allocator.free(self.bytes);
    }
};

/// A frame's Window realm restored from the snapshot, made inside its parent's script as HTML makes a
/// navigable's (protocol.runInRealm): a realm with a parent gets its interface objects lazily.
const SnapshotFrame = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    global_this: protocol.GlobalThis = .new_window_proxy,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *SnapshotFrame) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *SnapshotFrame = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
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

test "a lazy interface object read contextually first by a snapshot-restored frame realm whose WindowProxy went on is that realm's" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();

    var old_frame: SnapshotFrame = .{ .agent = page.agent, .parent = page.realm };
    const old = try old_frame.make();
    {
        // Nothing reads DOMParser or TextDecoder in the old realm before the navigation: their lazy properties
        // are untouched. The page keeps a function of the old realm, as the Crane test's parent does.
        const reader = try evalOwned(old, "(function (source) { return eval(source); })");
        defer reader.release();
        const parent_global = try evalOwned(page.realm, "globalThis");
        defer parent_global.release();
        try protocol.setProperty(page.realm, parent_global.value, "reader", reader.value);
    }
    var new_frame: SnapshotFrame = .{ .agent = page.agent, .parent = page.realm, .global_this = .{ .window_proxy_of = old } };
    const new = try new_frame.make();
    defer protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(old, .global_detached);

    try expectOk(page.realm,
        \\const failures = [];
        \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
        \\check("typeof DOMParser, read contextually first in the old realm", reader("typeof DOMParser"), "function");
        \\check("it is the old realm's, not the new Window's", reader("DOMParser !== window.DOMParser"), true);
        \\check("and read again, the same object", reader("DOMParser === DOMParser"), true);
        \\check("TextDecoder, read first as a value", typeof reader("TextDecoder"), "function");
        \\failures.join("; ") || "ok"
    );
    try expectOk(page.realm, "delete globalThis.reader ? 'ok' : 'not deleted'");
}
