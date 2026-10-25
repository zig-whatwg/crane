//! A Window whose detached realm the collector took converts to null until
//! its realm's end runs (lane winslot1, E4).
//!
//! A removed frame's realm is detached (protocol_realms.detach): its global
//! stays attached to its WindowProxy, and the realm ends once the collector
//! takes its context - the end itself runs later, from a task
//! (realmCollected -> endCollectedRealm). The same collection finalizes the
//! Window's wrapper-cache entry, the global proxy, and disposes the handle
//! the Window's bound_v8_global names. Between that collection and the end
//! task, the Window is alive (its teardown has not run) and a native holder
//! that converts it - an event's view or source, read by script in the
//! parent - was handed back that disposed handle. realmCollected marks the
//! realm as having no engine first (engine_ctx null): a Window of such a
//! realm has no global to answer with, and converts to null.

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

test "a Window whose detached realm was collected converts to null before its realm's end runs" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));

    const page = try windowRealm(agent, null);
    const frame = try windowRealm(agent, page);
    const record = frame.getRealm() orelse return error.NoRealm;
    const frame_window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));

    // Its navigable destroyed: the realm is detached, and nothing in script
    // reaches it - only this native pointer, as an event's view would.
    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    // Detached, not ended: its realm runs while script could reach it.
    try testing.expect(frame.hasEngine());
    var rounds: usize = 0;
    while (frame.hasEngine() and rounds < 8) : (rounds += 1) ffi.v8_Isolate_RequestGarbageCollection(isolate);
    // The collector took it; this agent has no event loop, so its end waits
    // for the page's: the Window is alive, its teardown has not run, and the
    // global it was bound to went with the collection.
    try testing.expect(!frame.hasEngine());
    const state = frame_window.getState(interfaces.Window.State);
    try testing.expect(state.own._internal != null);
    // ... and it still names the handle the collection disposed.
    try testing.expect(dom.window_globals.boundGlobal(frame_window) != null);

    {
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(page, global.value, "held", .{ .instance = frame_window });
    }
    try expectEval(page, "String(held === null)", "true");

    // The page's end ends the frame's realm too.
    protocol.destroyWindowRealm(page, .global_detached);
}
