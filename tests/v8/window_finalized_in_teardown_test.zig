//! A detached realm's Window whose global the collector takes during another
//! realm's coordinated teardown is left to its own realm's end (lane
//! winslot1, a GUARD).
//!
//! A removed frame's realm is detached: it ends once the collector takes its
//! context, from a task, or with its page. The collection that takes it also
//! finalizes the realm's own Window entry in its wrapper cache - the global
//! proxy. wrapper_cache.finalizeEntry's branch for a collection that comes
//! while some realm's coordinated teardown is under way frees any instance
//! nothing has started to clean up, and excludes a realm's Window only in its
//! second arm - which read as a Window freed by its wrapper's death while its
//! realm still stood (reported as E10). Measured, not reasoned: the entry
//! reaches that branch no more - it leaves the frame's cache and nothing of
//! it is pending, but the Window's destructor never runs through its vtable
//! and its slot stays; its realm's end tears it down. Kept as the pin that it
//! stays so once the Window's slot can go back.
//!
//! The Window's vtable here is a copy that counts its destructor's runs: the
//! realm's end tears a Window down through the generated destructor
//! (context_manager.removeContextByKey), so a run counted here is a second
//! teardown.

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

/// The Window's destructor, counted.
const Counting = struct {
    var runs: usize = 0;
    var original: *const fn (*runtime.Instance) void = undefined;
    fn deinit(instance: *runtime.Instance) void {
        runs += 1;
        original(instance);
    }
};

test "a detached realm's Window collected during another realm's teardown waits for its own realm's end" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));

    const page = try windowRealm(agent, null);
    const frame = try windowRealm(agent, page);
    const record = frame.getRealm() orelse return error.NoRealm;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.NoWindow));
    var counting_vtable = window.vtable.*;
    Counting.original = window.vtable.deinit.?;
    counting_vtable.deinit = &Counting.deinit;
    Counting.runs = 0;
    window.vtable = &counting_vtable;
    const generation = runtime.SlabAllocator.generationOf(window);

    // Its navigable destroyed: detached, its end waits for the collector.
    protocol.destroyWindowRealm(frame, .navigable_destroyed);
    try testing.expect(frame.hasEngine());

    // Some realm's coordinated teardown is under way while the collector
    // takes the detached realm (a teardown allocates; a collection can come).
    {
        var coordinator = runtime.CleanupCoordinator.init(testing.allocator);
        defer coordinator.deinit();
        const previous = runtime.cleanup_coordinator.getActiveCoordinator();
        runtime.cleanup_coordinator.setActiveCoordinator(&coordinator);
        defer runtime.cleanup_coordinator.setActiveCoordinator(previous);
        coordinator.beginContextCleanup();
        var rounds: usize = 0;
        while (frame.hasEngine() and rounds < 8) : (rounds += 1) ffi.v8_Isolate_RequestGarbageCollection(isolate);
        coordinator.endContextCleanup();
        coordinator.releaseDeferredStorage();
    }
    try testing.expect(!frame.hasEngine());
    // The collection reached the Window's own entry: it is out of the
    // frame's cache, finalized.
    const cache: *v8.WrapperCache = @ptrCast(@alignCast(frame.getV8WrapperCacheStorage() orelse return error.NoCache));
    const entry_left = cache.cache.get(window) != null;
    const pending = cache.pendingFinalizerCount();
    const runs_after_collection = Counting.runs;
    const freed_by_collection = runtime.SlabAllocator.generationOf(window) != generation;

    // The page's end ends the detached frame's realm, which tears its Window
    // down - once, through context_manager.removeContextByKey (the generated
    // destructor, not the vtable's: a run counted here is a second one).
    protocol.destroyWindowRealm(page, .global_detached);
    const runs_after_end = Counting.runs;
    // Torn down - and, once every holder of a Window is safe for a reused
    // slot (runtime.window_holders), its slot given back with it.
    const torn_down = runtime.SlabAllocator.generationOf(window) != generation or
        window.getState(interfaces.Window.State).own._internal == null;

    if (entry_left or runs_after_collection != 0 or freed_by_collection or runs_after_end != 0 or !torn_down)
        std.debug.print("entry left in the frame's cache: {}; pending finalizers: {d}; vtable destructor runs after the collection: {d}; slot freed by it: {}; after the realm's end: runs {d}, torn down {}\n", .{ entry_left, pending, runs_after_collection, freed_by_collection, runs_after_end, torn_down });
    try testing.expect(!entry_left);
    try testing.expectEqual(@as(usize, 0), runs_after_collection);
    try testing.expect(!freed_by_collection);
    try testing.expectEqual(@as(usize, 0), runs_after_end);
    try testing.expect(torn_down);
}
