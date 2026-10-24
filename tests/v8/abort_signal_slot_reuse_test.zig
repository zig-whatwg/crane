//! A controller that frees its signal whole frees it before the signal's own
//! collected wrapper is finalized: that finalizer must leave whatever takes
//! the slot in between (lane abortsig1, the integrator's condition).
//!
//! An AbortController owns a signal no wrapper owns, and its teardown now
//! frees it whole - its destructor chain AND its slab slot
//! (runtime.Instance.deinit) - where it used to run only the chain and strand
//! the slot. One case reaches that branch with a wrapper behind the signal:
//! the controller's wrapper and the signal's die in ONE collection (the
//! controller's keeps the signal's, and nothing keeps the controller's), the
//! first pass takes both out of the cache, and the controller's teardown runs
//! before the signal's - or a walk holds the agent's teardowns and they run
//! in its release's order. The controller then finds the signal with no
//! wrapper, frees it, and the slot goes back to the slab, whose free list is
//! LIFO: the next allocation of any type lands there. The signal's finalizer
//! must recognise the slot as no longer the one it was made for (the slot's
//! generation: wrapper_cache.slotReissued) and touch nothing of the newcomer.
//!
//! The order is forced: a hold (engine.holdTeardowns) keeps every collected
//! entry waiting, and the test arranges the list its release pops - the
//! controller first, then a mock whose teardown fills the slots freed after
//! the signal's and allocates an impostor AbortSignal, then the signal's own
//! entry. The impostor takes the signal's slot AND its state block (both
//! free lists are LIFO), so the vtable and state comparisons see the object
//! the finalizer was made for, and only the slot's generation does not. It
//! announces itself (docs/lessons/debugging-give-the-objects-that-reissue-a-
//! freed-slot-a-voice.md): it holds an abort algorithm whose drop step
//! counts, so a finalizer that tore it down is caught by the count; and the
//! controller, the signal and the impostor live on std.testing.allocator,
//! so a double teardown is caught by the allocator.
//!
//! Real V8, a real agent (protocol.createAgent: the holds are its record's)
//! and a Window realm of it, as tests/v8/rangeuaf_deferred_teardown_test.zig.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const dom = @import("dom");
const ffi = v8.ffi;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try engine.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: engine.HostHooks = .{};

/// An instance as (address, slab generation): a freed slot is reissued.
const Made = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Made {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn alive(self: Made) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// An agent, a Window realm of it entered, and its wrapper cache.
const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,
    isolate: *ffi.Isolate,
    cache: *v8.WrapperCache,

    fn open() !Page {
        try setup();
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
        const storage = realm.getV8WrapperCacheStorage() orelse return error.NoWrapperCache;
        ffi.v8_Isolate_Enter(isolate);
        ffi.v8_Context_Enter(@ptrCast(realm.engine_ctx.?));
        return .{ .agent = agent, .realm = realm, .isolate = isolate, .cache = @ptrCast(@alignCast(storage)) };
    }

    fn close(self: *Page) void {
        ffi.v8_Context_Exit(@ptrCast(self.realm.engine_ctx.?));
        ffi.v8_Isolate_Exit(self.isolate);
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    /// Give `instance` a wrapper the cache owns, as the binding leaves an
    /// object script has seen; nothing else holds it.
    fn wrap(self: *Page, instance: *runtime.Instance) !void {
        const wrapper = ffi.v8_Object_New(self.isolate) orelse return error.ObjectFailed;
        try self.cache.set(instance, @ptrCast(wrapper), self.isolate);
    }

    /// A full collection: every first pass runs before it returns (and
    /// every second pass, unless a hold makes it wait).
    fn collect(self: *Page) void {
        ffi.v8_Isolate_RequestGarbageCollection(self.isolate);
    }

    fn holds(self: *Page) *v8.wrapper_cache_mod.TeardownHolds {
        return v8.protocol_agents.teardownHoldsOf(self.isolate).?;
    }
};

/// What the mock's teardown and the impostor's drop step saw. tests/v8
/// shares a process and its tests run in turn on its main thread.
const Impostors = struct {
    /// The freed signal's slot and state block, as they were before.
    target: ?Made = null,
    target_state: ?*anyopaque = null,
    page: ?*Page = null,
    /// Slots taken ahead of the impostor, so it lands in the signal's.
    fillers: [8]*runtime.Instance = undefined,
    filler_count: usize = 0,
    /// The impostor, if it took the signal's slot.
    impostor: ?Made = null,
    /// Whether it took the signal's state block too: then only the slot's
    /// generation tells it from the signal the finalizer was made for.
    same_state: bool = false,
    /// Whether the slot was free when the mock's teardown ran: the
    /// controller freed the signal before the signal's own finalizer.
    slot_free_before_finalizer: bool = false,
    /// Abort algorithms dropped - the impostor torn down.
    dropped: usize = 0,
    allocation_failed: bool = false,
};

var seen: Impostors = .{};

/// The impostor's abort algorithm: never runs (it is never aborted);
/// dropped only when the impostor is torn down.
const Voice = struct {
    fn run(_: *anyopaque) void {}
    fn drop(_: *anyopaque) void {
        seen.dropped += 1;
    }
};
var voice_ctx: u8 = 0;

fn fillerDeinit(_: *runtime.Instance) void {}
const filler_methods: u8 = 0;
/// A slot with no state, to take the slots freed after the signal's.
const filler_vtable = runtime.VTable{
    .name = "MockSlotFiller",
    .deinit = fillerDeinit,
    .methods_ptr = &filler_methods,
};

/// The mock's teardown: runs after the controller's and before the signal's
/// finalizer. The slab's free list is LIFO, and the controller's own slot -
/// freed after its teardown freed the signal - is on top: stateless fillers
/// take the slots ahead of the signal's, then a new AbortSignal - speaking -
/// takes the signal's slot and, the arena's free list being LIFO too, its
/// state block.
fn impostorDeinit(_: *runtime.Instance) void {
    const target = seen.target.?;
    const page = seen.page.?;
    const slab = &runtime.BrowserScope.standalone().?.slab;
    seen.slot_free_before_finalizer = runtime.SlabAllocator.generationOf(target.instance) == runtime.SlabAllocator.dead_generation;
    // The slot was never given back: no impostor can take it.
    if (!seen.slot_free_before_finalizer) return;
    while (seen.filler_count < seen.fillers.len) {
        const filler = slab.alloc(&filler_vtable) catch {
            seen.allocation_failed = true;
            return;
        };
        if (filler == target.instance) {
            // The signal's slot is next: give it back, on top.
            slab.free(filler);
            break;
        }
        filler.state = @ptrCast(&mock_state);
        filler.ctx = page.realm;
        seen.fillers[seen.filler_count] = filler;
        seen.filler_count += 1;
    } else return;
    const impostor = interfaces.AbortSignal.init(testing.allocator, page.realm) catch {
        seen.allocation_failed = true;
        return;
    };
    dom.abort_algorithms.add(impostor, .{ .ctx = &voice_ctx, .run = Voice.run, .drop = Voice.drop }) catch {
        seen.allocation_failed = true;
    };
    if (impostor == target.instance) {
        seen.impostor = Made.of(impostor);
        seen.same_state = @as(?*anyopaque, @ptrCast(impostor.state)) == seen.target_state;
    } else {
        runtime.Instance.deinit(impostor);
        seen.dropped = 0;
    }
}

const mock_methods: u8 = 0;
/// An interface nobody owns: its wrapper takes the weak default.
const mock_vtable = runtime.VTable{
    .name = "MockImpostorMaker",
    .deinit = impostorDeinit,
    .methods_ptr = &mock_methods,
};
var mock_state: u64 = 0;

/// Move the waiting entries of `first`, `second` and `third` to the end of
/// the hold's list, so its release - which pops - runs them in that order;
/// every other entry keeps its place before them.
fn arrange(holds: *v8.wrapper_cache_mod.TeardownHolds, first: *runtime.Instance, second: *runtime.Instance, third: *runtime.Instance) !void {
    const items = holds.deferred.items;
    const Entry = @TypeOf(items[0]);
    const wanted = [_]*runtime.Instance{ third, second, first };
    var picked: [3]?Entry = .{ null, null, null };
    var kept: usize = 0;
    for (items) |entry| {
        const k = std.mem.indexOfScalar(*runtime.Instance, &wanted, entry.instance) orelse {
            items[kept] = entry;
            kept += 1;
            continue;
        };
        if (picked[k] != null) return error.EntryWaitingTwice;
        picked[k] = entry;
    }
    for (picked, 0..) |entry, k| items[kept + k] = entry orelse return error.EntryNotWaiting;
}

test "a signal its controller frees whole is left alone by its own pending finalizer, whoever takes the slot" {
    var page = try Page.open();
    defer page.close();
    seen = .{ .page = &page };

    // A controller and its signal, both wrapped - as `controller.signal` read
    // by script leaves them: the controller's wrapper first, then the getter,
    // which wraps the signal in its realm and draws the edge from the
    // controller's wrapper to it. Nothing keeps the controller's.
    const controller = try interfaces.AbortController.init(testing.allocator, page.realm);
    try page.wrap(controller);
    const signal = try interfaces.AbortController.get_signal(controller);
    try testing.expect(page.cache.get(signal) != null);
    const controller_made = Made.of(controller);
    const signal_made = Made.of(signal);
    seen.target = signal_made;
    seen.target_state = @ptrCast(signal.state);

    // The mock whose teardown, between the two, allocates the impostors.
    const mock = try runtime.BrowserScope.standalone().?.slab.alloc(&mock_vtable);
    mock.state = @ptrCast(&mock_state);
    mock.ctx = page.realm;
    try page.wrap(mock);
    const mock_made = Made.of(mock);

    {
        const hold = engine.holdTeardowns(page.realm);
        defer hold.release();
        page.collect();
        page.collect();
        // Collected - out of the cache, so the controller sees a signal with
        // no wrapper - and torn down not yet.
        try testing.expect(page.cache.get(controller) == null);
        try testing.expect(page.cache.get(signal) == null);
        try testing.expect(!engine.hasWrapper(signal));
        try testing.expect(controller_made.alive());
        try testing.expect(signal_made.alive());
        try testing.expect(mock_made.alive());
        // The release pops: the controller, the mock, the signal.
        try arrange(page.holds(), controller, mock, signal);
    }

    // The controller went, and freed its signal whole before the signal's
    // finalizer ran.
    try testing.expect(!controller_made.alive());
    try testing.expect(!mock_made.alive());
    try testing.expect(!seen.allocation_failed);
    try testing.expect(seen.slot_free_before_finalizer);
    // An impostor took the slot: the same type in the same slot with the
    // same state block - only the slot's generation tells it from the
    // signal the finalizer was made for.
    const impostor = seen.impostor orelse return error.SlotNotReused;
    try testing.expect(impostor.instance == signal_made.instance);
    try testing.expect(impostor.generation != signal_made.generation);
    try testing.expect(seen.same_state);

    // The signal's finalizer has run (the release emptied the list) and
    // touched nothing of the impostor: not torn down, still itself.
    try testing.expectEqual(@as(usize, 0), page.holds().deferredCount());
    try testing.expectEqual(@as(usize, 0), seen.dropped);
    try testing.expect(impostor.alive());
    try testing.expect(!try interfaces.AbortSignal.get_aborted(impostor.instance));

    // Freed by its owner - this test - once: its drop speaks once, and the
    // allocator sees every block freed exactly once.
    runtime.Instance.deinit(impostor.instance);
    try testing.expectEqual(@as(usize, 1), seen.dropped);
    for (seen.fillers[0..seen.filler_count]) |filler| runtime.Instance.deinit(filler);
    seen = .{};
}
