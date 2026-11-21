//! A platform object made with no NewTarget gets "the interface prototype
//! object for interface in realm" (WebIDL "internally create a new object
//! implementing the interface", step 2.1) - the realm's own object, whatever
//! script has since done to the global property that once held its interface
//! object - and making it runs no script (lane gcp1).
//!
//! The wrap path read `globalThis[<Interface>]` and its `prototype` by name
//! when each wrapper was made (v8_FunctionTemplate_NewWrapper on main
//! d29206edf1d): a page that replaced the global property gave later
//! wrappers that value's `prototype`, an accessor it defined there ran inside
//! the wrap, and one that threw left its exception pending. Chrome 157,
//! Firefox 159 and Safari 27 give the realm's prototype in every case and run
//! no getter (tmp/plans/gcp1-evidence/probe-wrap-realm-prototype-3browsers.txt,
//! 2026-11-17: twelve cases - elements by createElement and by the parser, a
//! DOMTokenList, an AbortSignal, a Text, a CustomEvent, a stream reader, a
//! frame's realm). Blink takes the wrapper from a per-context cache
//! (V8PerContextData::CreateWrapperFromCache, Chromium 157.0.8103.51).
//!
//! The objects here are made inside bindings and handed to script, never by
//! `new` on their own interface: an AbortController's signal, a stream's
//! reader and controller, a URL's searchParams.
//!
//! A frame's realm builds its interface objects when script first reads
//! them (global_constructor_handler.zig). The by-name read was also what
//! built them for a wrap; a wrap there must still give a prototype with
//! everything WebIDL puts on it - the second test.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;
/// The snapshot this build generated (build.zig passes its path).
const snapshot_path = @import("test_snapshot").path;

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

/// `source`'s completion value must be "ok" (else it is the list of failed
/// checks), and it must report nothing.
fn expectOk(r: runtime.Context, source: []const u8) !void {
    var reports: Reports = .{};
    const got = try protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(got);
    try testing.expectEqual(@as(usize, 0), reports.count);
    if (!std.mem.eql(u8, got, "ok")) std.debug.print("failed checks: {s}\n", .{got});
    try testing.expectEqualStrings("ok", got);
}

const checks_prelude =
    \\const failures = [];
    \\function check(name, got, want) { if (got !== want) failures.push(name + ": " + String(got)); }
    \\
;

test "a platform object made with no NewTarget gets its realm's interface prototype whatever the global property holds, and the wrap runs no script" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = true,
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://gcp1-wrap.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    try expectOk(realm, checks_prelude ++
        \\let gets = 0;
        \\// Replaced by a data property holding another function.
        \\const signalPrototype = AbortSignal.prototype;
        \\function FakeSignal() {}
        \\FakeSignal.prototype = { fake: true };
        \\globalThis.AbortSignal = FakeSignal;
        \\const signal = new AbortController().signal;
        \\check("a signal made after AbortSignal was replaced has the realm's AbortSignal.prototype", Object.getPrototypeOf(signal) === signalPrototype, true);
        \\check("and not the replacement's", signal instanceof FakeSignal, false);
        \\// Replaced by an accessor.
        \\const readerPrototype = ReadableStreamDefaultReader.prototype;
        \\Object.defineProperty(globalThis, "ReadableStreamDefaultReader", { get() { gets++; return function Fake() {}; }, configurable: true });
        \\const reader = new ReadableStream().getReader();
        \\check("a reader made under an accessor has the realm's prototype", Object.getPrototypeOf(reader) === readerPrototype, true);
        \\check("the accessor never ran", gets, 0);
        \\// Deleted.
        \\const controllerPrototype = ReadableStreamDefaultController.prototype;
        \\delete globalThis.ReadableStreamDefaultController;
        \\let controller;
        \\new ReadableStream({ start(c) { controller = c; } });
        \\check("a controller made after its global was deleted has the realm's prototype", Object.getPrototypeOf(controller) === controllerPrototype, true);
        \\// An accessor that throws.
        \\const paramsPrototype = URLSearchParams.prototype;
        \\Object.defineProperty(globalThis, "URLSearchParams", { get() { gets++; throw new Error("the wrap ran the global's getter"); }, configurable: true });
        \\let params, thrown = null;
        \\try { params = new URL("https://gcp1-wrap.test/?a=1").searchParams; } catch (e) { thrown = e; }
        \\check("reading searchParams threw nothing", thrown === null ? "nothing" : String(thrown), "nothing");
        \\check("searchParams has the realm's URLSearchParams.prototype", params !== undefined && Object.getPrototypeOf(params) === paramsPrototype, true);
        \\check("no getter ran at all", gets, 0);
        \\failures.join("; ") || "ok"
    );
}

/// An agent restored from this build's snapshot and its page realm, restored too - the agent every page of
/// the browser and the WPT runner gets (v8up_old_realm_members_test.zig's SnapshotPage). Null (the test skips)
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
            .agent_cluster_cross_origin_isolated = true,
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://gcp1-wrap.test",
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
            .agent_cluster_cross_origin_isolated = true,
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = true,
            .timer = null,
            .origin = "https://gcp1-wrap.test",
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

test "a frame realm wraps a platform object of an interface its script never read with the whole interface prototype object" {
    const page = (try SnapshotPage.open()) orelse return error.SkipZigTest;
    defer page.close();

    var frame_maker: SnapshotFrame = .{ .agent = page.agent, .parent = page.realm };
    const frame = try frame_maker.make();
    defer protocol.destroyWindowRealm(frame, .global_detached);

    // Neither AbortSignal nor ReadableStreamDefaultReader is read in the frame before its first wrap: their
    // interface objects are built for the wrap. The reader's global is replaced before anything reads it, so
    // nothing but the wrap can build that one.
    try expectOk(frame, checks_prelude ++
        \\const signal = new AbortController().signal;
        \\const signalPrototype = Object.getPrototypeOf(signal);
        \\check("the signal's class string", Object.prototype.toString.call(signal), "[object AbortSignal]");
        \\check("its interface object's prototype property is read-only", Object.getOwnPropertyDescriptor(signalPrototype.constructor, "prototype").writable, false);
        \\check("its prototype is the global's AbortSignal.prototype, read after", signalPrototype === AbortSignal.prototype, true);
        \\globalThis.ReadableStreamDefaultReader = 1;
        \\const reader = new ReadableStream().getReader();
        \\const readerPrototype = Object.getPrototypeOf(reader);
        \\check("the reader's class string", Object.prototype.toString.call(reader), "[object ReadableStreamDefaultReader]");
        \\check("its prototype's constructor", readerPrototype.constructor.name, "ReadableStreamDefaultReader");
        \\check("that interface object's prototype property is read-only", Object.getOwnPropertyDescriptor(readerPrototype.constructor, "prototype").writable, false);
        \\check("a second reader has the same prototype", Object.getPrototypeOf(new ReadableStream().getReader()), readerPrototype);
        \\failures.join("; ") || "ok"
    );
}
