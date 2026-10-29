//! A Window whose realm has ended converts to null, and that null is nobody's
//! to release (lane leaks1, 2026-10-29).
//!
//! conversions.instanceToV8Checked answers a platform object with its wrapper
//! cache's Global - BORROWED - and every caller (the protocol's
//! relevantWrapper, the binding's getters, ownHandle) treats a result that is
//! not undefined as borrowed. windowProxyOrNull answered a Window with no
//! realm left with a NEW v8_Null, OWNED, which every one of those callers
//! cloned or kept and none released: nav2 C2's leak hunt found it on
//! Window.deliverPostedMessage -> MessageEvent.holdSource -> engine.traceValue
//! -> ownGlobal -> relevantWrapper, a posted message whose source window's
//! realm ended before its delivery (16 B a time). Blink's DOMWindow::Wrap
//! answers v8::Null - a Local, nothing to release - for a window with no
//! frame (core/frame/dom_window.cc); here the null is the isolate's, borrowed
//! like a wrapper, so no caller acquires anything.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

/// The host's Window, bound to the global the engine made for its realm, as
/// a frame's host binds it (HTMLIFrameElement, dom.window_globals).
const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = host;
        const window = interfaces.Window.init(std.heap.c_allocator, r) catch return null;
        switch (global_this) {
            .handle => |h| dom.window_globals.bind(window, h.ptr),
            else => {},
        }
        return window;
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

fn windowRealm(agent: *protocol.Agent, parent: ?runtime.Context) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = parent,
        .create_global_object = WindowHost.createGlobalObject,
    });
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, Ignored.reporter);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

fn windowOf(realm: runtime.Context) !*runtime.Instance {
    const record = realm.getRealm() orelse return error.NoRealm;
    return @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
}

/// The bytes one Global takes in V8's global handle table.
fn oneHandleBytes(isolate: *ffi.Isolate) usize {
    const start = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const one = ffi.v8_Number_New(isolate, 1);
    const with_one = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    ffi.v8_Value_Dispose(@ptrCast(one));
    return with_one - start;
}

test "a Window whose realm ended converts to a null nobody releases, on every path that converts it" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));

    const page = try windowRealm(agent, null);
    defer protocol.destroyWindowRealm(page, .global_detached);
    const frame = try windowRealm(agent, page);
    const page_window = try windowOf(page);
    const frame_window = try windowOf(frame);

    // The frame is removed and the collector takes its detached realm, as
    // between a postMessage from the frame and the message's delivery to the
    // page: the source Window is alive (a native holder keeps it), its realm
    // has no engine left.
    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    var rounds: usize = 0;
    while (frame.hasEngine() and rounds < 8) : (rounds += 1) ffi.v8_Isolate_RequestGarbageCollection(isolate);
    try testing.expect(!frame.hasEngine());

    // Script still sees null for it.
    {
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(page, global.value, "held", .{ .instance = frame_window });
    }
    try expectEval(page, "String(held === null)", "true");
    try expectEval(page, "delete globalThis.held", "true");

    const handle_bytes = oneHandleBytes(isolate);
    const slot: protocol.TracedSlot = .{ .name = "source" };
    const round = struct {
        fn run(r: runtime.Context, owner: *runtime.Instance, window: *runtime.Instance, s: protocol.TracedSlot) !void {
            // MessageEvent.holdSource's call, as it makes it: the source
            // Window as an instance, borrowed for the call.
            protocol.traceValue(owner, .{ .instance = window }, s);
            if (protocol.tracedValue(owner, s)) |read| read.release();
            protocol.forgetTracedChild(owner, s);
            // ownGlobal's other users: a retained value, released once.
            const held = try protocol.retainValue(r, .{ .instance = window });
            held.release();
        }
    }.run;
    // The first round makes what every later one reuses.
    try round(page, page_window, frame_window, slot);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const repeats = 32;
    for (0..repeats) |_| try round(page, page_window, frame_window, slot);
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after -| before >= handle_bytes) {
        std.debug.print("global handles {d} -> {d} bytes over {d} rounds ({d} bytes a handle)\n", .{ before, after, repeats, handle_bytes });
        return error.HandlesLeaked;
    }

    // The conversion itself, as the binding's getters call it: a result that
    // is not undefined is the caller's to keep, never to release - so the
    // null must cost nothing however often it is answered.
    const converted_before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..repeats) |_| {
        const value = v8.conversions.instanceToV8(isolate, frame_window);
        try testing.expect(ffi.v8_Value_IsNull(value));
        try testing.expect(!ffi.v8_Value_IsUndefined(value));
    }
    const converted_after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (converted_after -| converted_before >= handle_bytes) {
        std.debug.print("instanceToV8: global handles {d} -> {d} bytes over {d} conversions\n", .{ converted_before, converted_after, repeats });
        return error.HandlesLeaked;
    }
}
