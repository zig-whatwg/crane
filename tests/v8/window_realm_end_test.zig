//! What a Window realm's end leaves of its Window (lane winslot1, step 1).
//!
//! - Every engine object that named the Window loses it before the context
//!   manager frees it: the WindowProxy carries the Window in internal field 0,
//!   and the proxy, its hidden global and the WindowProperties object on the
//!   global's prototype chain carry the realm's GlobalAnchor (lane v8up b3c),
//!   and a member called on them unwraps those. A realm ended with
//!   .global_detached and no hand-on - a top-level page, a retired frame
//!   realm - left it in both (only a destroyed navigable's were severed), so
//!   a getter taken from the realm and called on its kept, detached proxy
//!   reached the torn-down Window. Blink's DisposeContext clears the global's
//!   native info before DetachGlobalObject (V8DOMWrapper::ClearNativeInfo).
//! - The Window's teardown is marked (runtime.instance_lifecycle): from its
//!   first step a holder that keeps it with a generation and asks for its
//!   cleanup reads it gone, before its slot can be given back.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const v8 = @import("v8");
const ffi = v8.ffi;
const interfaces = @import("interfaces");
const dom = @import("dom");

/// The host's Window, bound to the global the engine made for its realm, as
/// the hosts bind it (dom.window_globals).
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

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
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

fn windowOf(realm: runtime.Context) !*runtime.Instance {
    const record = realm.getRealm() orelse return error.NoRealm;
    return @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
}

fn field0(object: *ffi.Value) ?*anyopaque {
    const o: *ffi.Object = @ptrCast(object);
    if (ffi.v8_Object_InternalFieldCount(o) < 1) return null;
    return ffi.v8_Object_GetAlignedPointerFromInternalField(o, 0);
}

/// The realm's global proxy and the WindowProperties object on its prototype
/// chain, each held for the test. Never the hidden global object: V8 >= 14
/// gives no handle to it (crbug.com/333672197; the V1 GetPrototype read here
/// answers Object.getPrototypeOf on 15.7, design 2.8). What names the Window
/// is read as V8 keeps it: the proxy's field 0, and the GlobalAnchor the
/// proxy, the hidden global and WindowProperties are wrapped with
/// (realm_global.attach; v8_Debug_GlobalAnchorInstanceOf).
const Kept = struct {
    proxy: protocol.Owned,
    window_properties: protocol.Owned,

    fn of(realm: runtime.Context) !Kept {
        const proxy = try protocol.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        errdefer proxy.release();
        const window_properties = try protocol.evaluateClassicScript(realm, .{ .utf8 =
            \\(() => {
            \\  for (let o = Object.getPrototypeOf(globalThis); o; o = Object.getPrototypeOf(o)) {
            \\    const d = Object.getOwnPropertyDescriptor(o, Symbol.toStringTag);
            \\    if (d && d.value === "WindowProperties") return o;
            \\  }
            \\  return null;
            \\})()
        }, "", null, Ignored.reporter);
        return .{ .proxy = proxy, .window_properties = window_properties };
    }

    fn proxyField(self: Kept) ?*anyopaque {
        return field0(@ptrCast(@alignCast(self.proxy.value.handle.ptr)));
    }

    /// The Window of the proxy's anchor - the proxy's and the hidden
    /// global's, which `check_global` (an attached proxy only) checks agree.
    fn proxyAnchor(self: Kept, check_global: bool) ?*anyopaque {
        return ffi.v8_Debug_GlobalAnchorInstanceOf(@ptrCast(@alignCast(self.proxy.value.handle.ptr)), check_global);
    }

    fn propertiesAnchor(self: Kept) ?*anyopaque {
        if (self.window_properties.value != .handle) return null;
        return ffi.v8_Debug_GlobalAnchorInstanceOf(@ptrCast(@alignCast(self.window_properties.value.handle.ptr)), false);
    }

    fn release(self: Kept) void {
        self.window_properties.release();
        self.proxy.release();
    }
};

fn expectSevered(how: protocol.WindowRealmEnd) !void {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));

    const realm = try windowRealm(agent, null);
    const window = try windowOf(realm);
    const kept = try Kept.of(realm);
    // The realm's end exits the isolate it entered: the reads after it, and
    // the release, enter it again.
    defer {
        ffi.v8_Isolate_Enter(isolate);
        kept.release();
        ffi.v8_Isolate_Exit(isolate);
    }
    // All three name the Window while the realm lives.
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), kept.proxyField());
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), kept.proxyAnchor(true));
    try testing.expect(kept.window_properties.value == .handle);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), kept.propertiesAnchor());

    protocol.destroyWindowRealm(realm, how);

    ffi.v8_Isolate_Enter(isolate);
    const proxy_field = kept.proxyField();
    // A detached proxy (.global_detached) has no hidden global to compare.
    const proxy_anchor = kept.proxyAnchor(how == .navigable_destroyed);
    const properties_anchor = kept.propertiesAnchor();
    ffi.v8_Isolate_Exit(isolate);
    if (proxy_field != null or proxy_anchor != null or properties_anchor != null)
        std.debug.print("after the end ({s}): proxy field 0 {?*}, proxy anchor {?*}, WindowProperties anchor {?*}, the Window {*}\n", .{ @tagName(how), proxy_field, proxy_anchor, properties_anchor, window });
    try testing.expect(proxy_field == null);
    try testing.expect(proxy_anchor == null);
    try testing.expect(properties_anchor == null);
}

test "a realm's end with its global detached severs the proxy and WindowProperties from its Window" {
    try expectSevered(.global_detached);
}

test "a realm's end with its navigable destroyed severs the proxy and WindowProperties from its Window" {
    try expectSevered(.navigable_destroyed);
}

test "a realm's end marks its Window's teardown" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    const realm = try windowRealm(agent, null);
    const window = try windowOf(realm);
    const generation = runtime.SlabAllocator.generationOf(window);
    try testing.expect(!runtime.instance_lifecycle.isCleanupStarted(window));

    protocol.destroyWindowRealm(realm, .global_detached);

    // Its slot, while it is still the Window's (until every holder is safe
    // for a reused slot, it stays issued), says its teardown ran to the end.
    if (runtime.SlabAllocator.generationOf(window) == generation) {
        try testing.expect(runtime.instance_lifecycle.isCleanupStarted(window));
        try testing.expect(runtime.instance_lifecycle.isCleanedUp(window));
    }
}

test "while a holder kind is unsafe, a realm's end keeps its Window's slot" {
    // The switch (runtime.window_holders.reusable) is off until every holder
    // kind reads a Window through a generation check; until then the Window
    // keeps its slot, torn down, as it always has.
    if (runtime.window_holders.reusable) return error.SkipZigTest;
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, null);
    const window = try windowOf(realm);
    const generation = runtime.SlabAllocator.generationOf(window);
    protocol.destroyWindowRealm(realm, .global_detached);
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(window));
}

test "releaseSevered returns a torn-down instance's storage now, or after the teardown under way" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, null);
    defer protocol.destroyWindowRealm(realm, .global_detached);

    const Made = struct {
        fn tornDown(r: runtime.Context) !struct { instance: *runtime.Instance, generation: u64 } {
            const instance = try interfaces.TextEncoder.init(std.heap.c_allocator, r);
            const generation = runtime.SlabAllocator.generationOf(instance);
            try testing.expect(runtime.instance_lifecycle.markCleanupStarted(instance));
            instance.vtable.deinit.?(instance);
            runtime.instance_lifecycle.markCleanupComplete(instance);
            return .{ .instance = instance, .generation = generation };
        }
    };

    // No teardown under way: back at once.
    const now = try Made.tornDown(realm);
    runtime.gc.releaseSevered(now.instance, now.generation);
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(now.instance));

    // Inside a coordinated teardown: after its last phase, not before.
    const later = try Made.tornDown(realm);
    {
        var coordinator = runtime.CleanupCoordinator.init(testing.allocator);
        defer coordinator.deinit();
        const previous = runtime.cleanup_coordinator.getActiveCoordinator();
        runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
        defer runtime.cleanup_coordinator.setActiveCoordinator(previous);
        coordinator.beginContextCleanup();
        runtime.gc.releaseSevered(later.instance, later.generation);
        try testing.expectEqual(later.generation, runtime.SlabAllocator.generationOf(later.instance));
        coordinator.endContextCleanup();
        coordinator.releaseDeferredStorage();
    }
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(later.instance));

    // Not torn down, or already reissued: nothing.
    const live = try interfaces.TextEncoder.init(std.heap.c_allocator, realm);
    const live_generation = runtime.SlabAllocator.generationOf(live);
    runtime.gc.releaseSevered(live, live_generation);
    try testing.expectEqual(live_generation, runtime.SlabAllocator.generationOf(live));
    runtime.gc.releaseSevered(live, live_generation + 1);
    try testing.expectEqual(live_generation, runtime.SlabAllocator.generationOf(live));
    runtime.Instance.deinit(live);
}

test "once every holder kind is safe, a realm's end gives its Window's slot back" {
    if (!runtime.window_holders.reusable) return error.SkipZigTest;
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const realm = try windowRealm(agent, null);
    const window = try windowOf(realm);
    protocol.destroyWindowRealm(realm, .global_detached);
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(window));
}
