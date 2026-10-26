//! An event's target that was a Window whose realm has ended reads null,
//! never the object its reissued slot holds (lane winslot1, kinds 5-7).
//!
//! An event keeps its target as a pointer, and draws an edge to it only once
//! script can reach the event (EventState.keepTarget): an event made and
//! dispatched natively at another realm's Window, kept past that realm's end
//! and only then handed to script, named a torn-down Window - and, once the
//! Window's slot goes back, whatever the slab issued there next. The event
//! now keeps its target's slab generation beside it, and reads it through
//! that outside dispatch.
//!
//! Real V8, realms made and ended as a page's are; the reissued slot holds a
//! TextEncoder, which announces itself when script reads it.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

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

fn windowRealm(agent: *protocol.Agent) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

test "an event whose target Window's realm ended reads a null target, never the slot's next object" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    const page = try windowRealm(agent);
    const other = try windowRealm(agent);
    const record = other.getRealm() orelse return error.NoRealm;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
    const generation = runtime.SlabAllocator.generationOf(window);

    // An event of the page's realm, made natively, its target the other
    // realm's Window - no script has seen it, so nothing is traced.
    const event = try interfaces.Event.init(std.heap.c_allocator, page);
    try dom.event_construction.innerEventCreationSteps(event, runtime.DOMString.initInterned("x"), .{});
    const state = dom.event_dispatch.of(event) orelse return error.NoEventState;
    state.setTarget(event, window);

    // The other realm ends; its Window's slot goes back (as the realm's end
    // gives it back once every holder kind is safe) and is reissued.
    protocol.destroyWindowRealm(other, .global_detached);
    try testing.expect(runtime.instance_lifecycle.isCleanedUp(window) or runtime.SlabAllocator.generationOf(window) != generation);
    if (runtime.SlabAllocator.generationOf(window) == generation) runtime.gc.releaseStorage(window);
    var impostors: std.ArrayListUnmanaged(*runtime.Instance) = .empty;
    defer {
        // The ones script never reached; one it wrapped went with the page's
        // realm.
        for (impostors.items) |i| {
            if (runtime.SlabAllocator.generationOf(i) == runtime.SlabAllocator.dead_generation) continue;
            const flags = runtime.instance_lifecycle.get(i) orelse runtime.instance_lifecycle.LifecycleFlags{};
            if (!flags.wrapped) runtime.Instance.deinit(i);
        }
        impostors.deinit(testing.allocator);
    }
    while (impostors.items.len < 64) {
        const impostor = try interfaces.TextEncoder.init(std.heap.c_allocator, page);
        try impostors.append(testing.allocator, impostor);
        if (impostor == window) break;
    }
    try testing.expect(impostors.items[impostors.items.len - 1] == window);

    // Script reads the event's target.
    {
        const global = try protocol.evaluateClassicScript(page, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(page, global.value, "ev", .{ .instance = event });
    }
    const got = try protocol.evaluateClassicScriptToString(page, .{ .utf8 = "String(ev.target) + ':' + String(ev.srcElement)" }, "", null, testing.allocator, Ignored.reporter);
    defer testing.allocator.free(got);
    const ok = std.mem.eql(u8, got, "null:null");
    if (!ok) std.debug.print("ev.target:ev.srcElement = {s}\n", .{got});

    protocol.destroyWindowRealm(page, .global_detached);
    try testing.expect(ok);
}
