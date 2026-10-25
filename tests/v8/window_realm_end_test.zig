//! What a Window realm's end leaves of its Window (lane winslot1, step 1).
//!
//! - Every engine object that named the Window loses it before the context
//!   manager frees it: the WindowProxy and the WindowProperties object on the
//!   global's prototype chain carry the Window in internal field 0, and a
//!   member called on them unwraps that field. A realm ended with
//!   .global_detached and no hand-on - a top-level page, a retired frame
//!   realm - left it in both (only a destroyed navigable's were severed), so
//!   a getter taken from the realm and called on its kept, detached proxy
//!   reached the torn-down Window. Blink's DisposeContext clears the global's
//!   native info before DetachGlobalObject (V8DOMWrapper::ClearNativeInfo).
//! - The Window's teardown is marked (runtime.instance_lifecycle): from its
//!   first step a holder that keeps it with a generation and asks for its
//!   cleanup reads it gone, before its slot can be given back.

const std = @import("std");
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

fn windowOf(realm: runtime.Context) !*runtime.Instance {
    const record = realm.getRealm() orelse return error.NoRealm;
    return @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
}

fn field0(object: *ffi.Value) ?*anyopaque {
    const o: *ffi.Object = @ptrCast(object);
    if (ffi.v8_Object_InternalFieldCount(o) < 1) return null;
    return ffi.v8_Object_GetAlignedPointerFromInternalField(o, 0);
}

/// The realm's global proxy and the WindowProperties object behind it
/// (the hidden global's prototype chain: Window.prototype, then it), each a
/// Global the caller disposes.
const Kept = struct {
    proxy: protocol.Owned,
    window_properties: ?*ffi.Value,

    fn of(realm: runtime.Context) !Kept {
        const proxy = try protocol.evaluateClassicScript(realm, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        errdefer proxy.release();
        const proxy_value: *ffi.Value = @ptrCast(@alignCast(proxy.value.handle.ptr));
        // V8's V1 GetPrototype on a global proxy answers the hidden global.
        const hidden = ffi.v8_Object_GetPrototype(@ptrCast(proxy_value)) orelse return error.NoGlobal;
        defer ffi.v8_Global_Dispose(hidden);
        var at: *ffi.Value = hidden;
        var links: [2]?*ffi.Value = .{ null, null };
        defer for (links) |l| if (l) |v| ffi.v8_Global_Dispose(v);
        var window_properties: ?*ffi.Value = null;
        for (&links) |*slot| {
            const proto = ffi.v8_Object_GetPrototypeV2(@ptrCast(at)) orelse break;
            slot.* = proto;
            if (!ffi.v8_Value_IsObject(proto)) break;
            if (ffi.v8_Object_InternalFieldCount(@ptrCast(proto)) >= 1) {
                window_properties = ffi.v8_Global_Clone(proto);
                break;
            }
            at = proto;
        }
        return .{ .proxy = proxy, .window_properties = window_properties };
    }

    fn proxyField(self: Kept) ?*anyopaque {
        return field0(@ptrCast(@alignCast(self.proxy.value.handle.ptr)));
    }

    fn propertiesField(self: Kept) ?*anyopaque {
        return field0(self.window_properties orelse return null);
    }

    fn release(self: Kept) void {
        if (self.window_properties) |wp| ffi.v8_Global_Dispose(wp);
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
    // Both name the Window while the realm lives.
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), kept.proxyField());
    try testing.expect(kept.window_properties != null);
    try testing.expectEqual(@as(?*anyopaque, @ptrCast(window)), kept.propertiesField());

    protocol.destroyWindowRealm(realm, how);

    ffi.v8_Isolate_Enter(isolate);
    const proxy_field = kept.proxyField();
    const properties_field = kept.propertiesField();
    ffi.v8_Isolate_Exit(isolate);
    if (proxy_field != null or properties_field != null)
        std.debug.print("after the end ({s}): proxy field 0 {?*}, WindowProperties field 0 {?*}, the Window {*}\n", .{ @tagName(how), proxy_field, properties_field, window });
    try testing.expect(proxy_field == null);
    try testing.expect(properties_field == null);
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
