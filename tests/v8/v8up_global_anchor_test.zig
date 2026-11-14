//! A realm's global on V8 15.7: the GlobalAnchor every realm global is attached with (lane v8up b3c;
//! tmp/plans/v8-global-object-design.md 2.1-2.5 and its 2.3 ruling).
//!
//! V8 >= 14 gives the embedder no handle to a context's JSGlobalObject (crbug.com/333672197). Blink's model,
//! which Crane follows: `Object::WrapGlobal` sets ONE CppHeap pointer - a GlobalAnchor - on the global proxy
//! AND its hidden global object (LocalWindowProxy::SetupWindowPrototypeChain, local_window_proxy.cc 405-449 at
//! Chromium 157.0.8103.51), and WindowProperties gets the same native info (:434-437). A navigation that
//! hands the WindowProxy to a new realm clears the PROXY's pointer only (DisposeContext step 2,
//! ClearNativeInfo); the old hidden global keeps the old anchor - so the old WindowProperties still names the
//! old Window - and the new realm's attach re-wraps the proxy. A realm's end clears its anchor before its
//! Window is freed (one write for proxy, hidden global and WindowProperties).
//!
//! And THE Window-receiver rule (the integrator's ruling, 2026-11-11 00:48 UTC): a Window member used
//! CONTEXTUALLY by a realm whose WindowProxy went on acts on that realm's OWN Window - EventTarget's members
//! too, whose receiver used to be read from the reused proxy's field 0, the NEW Window.

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

fn windowOf(realm: runtime.Context) !*runtime.Instance {
    const record = realm.getRealm() orelse return error.NoRealm;
    return @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
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

/// The instance of the anchor `object` (an engine value: a global proxy or a WindowProperties object) carries.
fn anchorInstance(isolate: *ffi.Isolate, object: protocol.JSValue, check_global: bool) ?*anyopaque {
    ffi.v8_Isolate_Enter(isolate);
    defer ffi.v8_Isolate_Exit(isolate);
    return ffi.v8_Debug_GlobalAnchorInstanceOf(@ptrCast(@alignCast(object.handle.ptr)), check_global);
}

/// The WindowProperties object on a realm's global's prototype chain, read in `r` (contextually: in a realm
/// whose WindowProxy went on, its own global's chain, through its own `Window.prototype`).
const window_properties_source =
    \\(() => {
    \\  for (let o = Object.getPrototypeOf(Window.prototype); o; o = Object.getPrototypeOf(o)) {
    \\    const d = Object.getOwnPropertyDescriptor(o, Symbol.toStringTag);
    \\    if (d && d.value === "WindowProperties") return o;
    \\  }
    \\  return null;
    \\})()
;

test "2.1: a Window realm's global proxy and hidden global carry one GlobalAnchor naming its Window, and so does its WindowProperties" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const realm = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    const window = try windowOf(realm);

    const proxy = try evalOwned(realm, "globalThis");
    defer proxy.release();
    // CheckGlobalWrappable: the proxy's and the hidden global's anchors are one.
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), anchorInstance(isolate, proxy.value, true));
    const properties = try evalOwned(realm, window_properties_source);
    defer properties.release();
    try testing.expect(properties.value == .handle);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), anchorInstance(isolate, properties.value, false));
}

test "2.3: a navigation hands the WindowProxy on: the proxy carries the new Window's anchor, the old realm's WindowProperties keeps the old Window" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const keeper = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(keeper, .global_detached);

    const old = try windowRealm(agent, .new_window_proxy);
    const old_window = try windowOf(old);
    const reader = try evalOwned(old, "(function (source) { return eval(source); })");
    defer reader.release();
    {
        const keeper_global = try evalOwned(keeper, "globalThis");
        defer keeper_global.release();
        try protocol.setProperty(keeper, keeper_global.value, "reader", reader.value);
    }

    const new = try windowRealm(agent, .{ .window_proxy_of = old });
    defer protocol.destroyWindowRealm(new, .global_detached);
    const new_window = try windowOf(new);
    protocol.destroyWindowRealm(old, .global_detached);

    const proxy = try evalOwned(new, "globalThis");
    defer proxy.release();
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(new_window)), anchorInstance(isolate, proxy.value, true));
    // The old realm's own WindowProperties, reached through its own Window.prototype.
    const old_properties = try evalOwned(keeper, "reader(" ++ "`" ++ window_properties_source ++ "`" ++ ")");
    defer old_properties.release();
    try testing.expect(old_properties.value == .handle);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(old_window)), anchorInstance(isolate, old_properties.value, false));
    try expectOk(keeper, "delete globalThis.reader ? 'ok' : 'not deleted'");
}

test "2.3: an EventTarget member used contextually by a realm whose WindowProxy went on acts on that realm's own Window" {
    // The ruling: contextual uses see the OLD Window - `addEventListener(...)` as much as `crypto`. Its receiver
    // was read from `this`'s field 0 (operationReceiver's thisInstance), and `this` is the reused proxy, which
    // names the NEW Window: the old realm's listener landed on the new Window.
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const keeper = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(keeper, .global_detached);

    const old = try windowRealm(agent, .new_window_proxy);
    {
        const reader = try evalOwned(old, "(function (source, arg) { return eval(source); })");
        defer reader.release();
        const keeper_global = try evalOwned(keeper, "globalThis");
        defer keeper_global.release();
        try protocol.setProperty(keeper, keeper_global.value, "reader", reader.value);
    }
    const new = try windowRealm(agent, .{ .window_proxy_of = old });
    defer protocol.destroyWindowRealm(new, .global_detached);
    protocol.destroyWindowRealm(old, .global_detached);

    try expectOk(keeper,
        \\let heard = 0;
        \\const listener = () => { heard++; };
        \\reader("addEventListener('v8up-ping', arg)", listener);
        \\const proxy = reader("window");
        \\proxy.dispatchEvent(new Event("v8up-ping"));
        \\const failures = [];
        \\if (heard !== 0) failures.push("the old realm's contextual addEventListener reached the new Window: " + heard);
        \\proxy.addEventListener("v8up-pong", listener);
        \\proxy.dispatchEvent(new Event("v8up-pong"));
        \\if (heard !== 1) failures.push("window.addEventListener did not reach the new Window: " + heard);
        \\delete globalThis.reader;
        \\failures.join("; ") || "ok"
    );
}

test "2.4: a realm's end clears its anchor: the proxy, the hidden global and WindowProperties name no Window" {
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    const realm = try windowRealm(agent, .new_window_proxy);
    const window = try windowOf(realm);
    const proxy = try evalOwned(realm, "globalThis");
    const properties = try evalOwned(realm, window_properties_source);
    defer {
        ffi.v8_Isolate_Enter(isolate);
        properties.release();
        proxy.release();
        ffi.v8_Isolate_Exit(isolate);
    }
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), anchorInstance(isolate, properties.value, false));

    protocol.destroyWindowRealm(realm, .navigable_destroyed);

    // The proxy stays attached (a destroyed navigable's, Blink kFrameIsDetached): CheckGlobalWrappable holds.
    try testing.expectEqual(@as(?*anyopaque, null), anchorInstance(isolate, proxy.value, true));
    try testing.expectEqual(@as(?*anyopaque, null), anchorInstance(isolate, properties.value, false));
}

test "2.2: a Window's traced edges live while its realm does: a full collection keeps `crypto` and `performance` the same objects" {
    // Window keeps them by traced edges (same_object.Traced: engine.traceChild with the Window as owner), which
    // hang on the realm's retained store - which only the realm's GlobalAnchor traces. An anchor that did not
    // trace it would lose them in the first full collection, and each would be a new object after it.
    test_process.start();
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, .new_window_proxy);
    defer protocol.destroyWindowRealm(realm, .global_detached);
    try expectOk(realm,
        \\crypto.v8upExpando = 42;
        \\performance.v8upExpando = 43;
        \\"ok"
    );
    protocol.requestGarbageCollection(agent);
    protocol.requestGarbageCollection(agent);
    try expectOk(realm,
        \\const failures = [];
        \\if (crypto.v8upExpando !== 42) failures.push("crypto was collected");
        \\if (performance.v8upExpando !== 43) failures.push("performance was collected");
        \\failures.join("; ") || "ok"
    );
}
