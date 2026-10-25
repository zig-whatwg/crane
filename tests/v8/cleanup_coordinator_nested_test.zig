//! A realm's teardown that ends another realm inside itself keeps its own
//! cleanup coordinator (lane winslot1, E9).
//!
//! context_manager.removeContextByKey makes the realm's CleanupCoordinator
//! the thread's active one for its phases: an object a phase frees whole
//! (runtime.gc.releaseOwned) hands its storage to it, to be returned after
//! the teardown's last phase - never inline, where a later step of the same
//! teardown could still read the slot, or an allocation it makes could take
//! it (lane unwrapped1's rule). A teardown can end another realm inside one
//! of its phases - a frame's Window ending a popup it owns whose realm is
//! the page's child, from Window.InternalState.deinit. That inner
//! removeContextByKey set the active coordinator to NULL when it returned,
//! not back to the outer one: for the rest of the outer teardown nothing
//! was "tearing down", every deferral was dropped (the slot kept until the
//! Browser ended), and releaseOwned freed storage inline, mid-teardown.
//!
//! The outer realm's wrapper cache holds a TextEncoder whose vtable is a
//! copy with a hook in its deinit: the sweep runs it, the hook ends the
//! inner realm, then asks what the teardown is and frees an object whole.

const std = @import("std");
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

/// What the hooked teardown did and saw.
const Nested = struct {
    outer: runtime.Context,
    inner: runtime.Context,
    hooked_vtable: runtime.VTable,
    original_deinit: *const fn (*runtime.Instance) void,
    ran: bool = false,
    /// The thread's teardown state right after the inner realm ended.
    tearing_down_after_inner: bool = false,
    /// The object the hook freed whole after the inner realm ended, and its
    /// slab generation when made.
    freed_whole: ?*runtime.Instance = null,
    freed_whole_generation: u64 = 0,
    /// Its storage was back the moment releaseOwned returned.
    released_inline: bool = false,

    var current: ?*Nested = null;

    fn hookedDeinit(instance: *runtime.Instance) void {
        const self = current.?;
        self.original_deinit(instance);
        if (self.ran) return;
        self.ran = true;
        // A realm ended inside this teardown's sweep.
        protocol.destroyWindowRealm(self.inner, .global_detached);
        self.tearing_down_after_inner = runtime.cleanup_coordinator.isContextTearingDown();
        // An object of the outer realm, never wrapped, freed whole by this
        // teardown: its storage must wait for the teardown's last phase.
        const made = interfaces.TextEncoder.init(std.heap.c_allocator, self.outer) catch return;
        self.freed_whole = made;
        self.freed_whole_generation = runtime.SlabAllocator.generationOf(made);
        runtime.gc.releaseOwned(made);
        self.released_inline = runtime.SlabAllocator.generationOf(made) != self.freed_whole_generation;
    }
};

test "a realm ended inside another realm's teardown leaves that teardown its coordinator" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    const outer = try windowRealm(agent);
    const inner = try windowRealm(agent);

    const original = &interfaces.TextEncoder.vtable;
    var nested: Nested = .{
        .outer = outer,
        .inner = inner,
        .hooked_vtable = original.*,
        .original_deinit = original.deinit.?,
    };
    nested.hooked_vtable.deinit = &Nested.hookedDeinit;
    Nested.current = &nested;
    defer Nested.current = null;

    // The hooked object, wrapped in the outer realm (its cache's sweep tears
    // it down when the outer realm ends).
    const hooked = try interfaces.TextEncoder.init(std.heap.c_allocator, outer);
    hooked.vtable = &nested.hooked_vtable;
    {
        const global = try protocol.evaluateClassicScript(outer, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(outer, global.value, "hooked", .{ .instance = hooked });
    }

    protocol.destroyWindowRealm(outer, .global_detached);

    try testing.expect(nested.ran);
    // The outer teardown was still under way after the inner one returned,
    try testing.expect(nested.tearing_down_after_inner);
    // so the object it freed whole kept its slot until the teardown's end,
    try testing.expect(!nested.released_inline);
    // and got it back then.
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(nested.freed_whole.?));
    try testing.expect(!runtime.cleanup_coordinator.isContextTearingDown());
}
