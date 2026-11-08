//! A worker realm's end frees its global scope after every other object of
//! the realm, so a teardown that reads the realm's global finds it alive
//! (lane workerteardown1).
//!
//! A realm's end frees what its wrapper cache holds (WrapperCache.deinit), in
//! the cache map's hash order, and a worker realm's global scope was one of
//! those entries. An object's teardown can read the realm's global: a
//! response body freed there ends its fetch's body, and the fetch's report
//! timing steps reach the realm's Performance through its global
//! (Performance.performanceOfRealm -> dom.global_settings.of). Whenever the
//! global came first, that read was of a freed global scope - a SIGSEGV in
//! Instance.stateAs in about 3 of 90 runs of
//! fetch/api/basic/stream-response.any.js [worker], garbage the rest of the
//! time. Blink disposes a worker's global scope only after its context's
//! end has been notified and its script is gone
//! (WorkerThread::PerformShutdownOnWorkerThread, GlobalScope()->Dispose());
//! WebKit releases it after prepareForDestruction and clearScript
//! (WorkerOrWorkletThread::destroyWorkerGlobalScope).
//!
//! The readers here are TextEncoders whose vtable is a copy with a hook in
//! its deinit that reads the realm's global as a timing report does. The
//! walk's order is the map's, which the test cannot choose; it reads that
//! order instead, and draws it again until at least two readers come after
//! the global - so the case is there on every run.
//!
//! The test used to make readers until two came after the global and give
//! up at 256: in about 1 arrangement in 1,000 (3 of 3,000 measured, lane
//! crashes7) the global sat so near the end of the map that none did. The
//! give-up returned before the realm's end, the agent's end ended it after
//! `current` was cleared, and the hook's `current.?` crashed the process -
//! a crash in wrapper_cache.deinit -> gc.onObjectFreed, 1 run in 8 of a
//! shuffled tests-v8 process, whose last 40 lines of output had lost the
//! panic and the hook. Now every way out ends the realm while `current` is
//! set (`runRealm`), the hook falls through without it, and the order is
//! drawn again (the map's `rehash`, under a new seed) instead of waited for.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const dom = @import("dom");
const inline_task_loop = @import("inline_task_loop.zig");

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

/// What the hooked teardowns saw. One per test, reached from the hook
/// through `current` (this file's own state).
const Readers = struct {
    realm: runtime.Context,
    /// The realm's global scope and its slab generation when the realm was
    /// made: the slot reads another generation once it is freed.
    global: *runtime.Instance,
    global_generation: u64,
    hooked_vtable: runtime.VTable,
    original_deinit: *const fn (*runtime.Instance) void,
    made: usize = 0,
    torn_down: usize = 0,
    /// Teardowns that found the realm's global already freed.
    saw_freed_global: usize = 0,
    /// Teardowns that found it alive, and asked it what a timing report
    /// asks first: its kind of global (dom.global_settings.of).
    saw_live_global: usize = 0,

    var current: ?*Readers = null;

    fn init(self: *Readers, realm: runtime.Context, global: *runtime.Instance) void {
        const original = &interfaces.TextEncoder.vtable;
        self.* = .{
            .realm = realm,
            .global = global,
            .global_generation = runtime.SlabAllocator.generationOf(global),
            .hooked_vtable = original.*,
            .original_deinit = original.deinit.?,
        };
        self.hooked_vtable.deinit = &hookedDeinit;
    }

    /// A reader, wrapped in the realm as globalThis[`name`].
    fn make(self: *Readers, name: []const u8) !void {
        const instance = try interfaces.TextEncoder.init(std.heap.c_allocator, self.realm);
        instance.vtable = &self.hooked_vtable;
        const global = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(self.realm, global.value, name, .{ .instance = instance });
        self.made += 1;
    }

    fn hookedDeinit(instance: *runtime.Instance) void {
        // No Readers: the test that made this reader has returned, and only
        // its teardown is left. `runRealm` ends its realm before it returns,
        // so this is a bug in the test - one its counts then report.
        const self = current orelse return interfaces.TextEncoder.vtable.deinit.?(instance);
        self.torn_down += 1;
        // What a fetch's timing report reads in this teardown: the realm's
        // global object, through the realm (Performance.globalOf).
        if (self.realm.getRealm()) |record| {
            if (record.global_object) |object| {
                const global: *runtime.Instance = @ptrCast(@alignCast(object));
                if (global != self.global or runtime.SlabAllocator.generationOf(global) != self.global_generation) {
                    // Freed (or its slot reissued): reading it is the bug.
                    self.saw_freed_global += 1;
                } else {
                    _ = dom.global_settings.of(global);
                    self.saw_live_global += 1;
                }
            }
        }
        self.original_deinit(instance);
    }

    /// The realm's wrapper cache.
    fn cache(self: *const Readers) *v8.wrapper_cache_mod.WrapperCache {
        return @ptrCast(@alignCast(self.realm.getV8WrapperCacheStorage().?));
    }

    /// Readers until the walk will reach at least two after the global
    /// scope: the order a freed global was read in. The order is the map's,
    /// under a seed of its own (infra.address_map); while it puts too few
    /// readers after the global, the map draws it again (`rehash`: a new
    /// seed, every entry placed again), as its tombstone guard does. Each
    /// draw misses with about 2 chances in `readers_per_run` + 1, so
    /// `max_draws` of them never all miss.
    fn arrange(self: *Readers) !void {
        var name_buf: [16]u8 = undefined;
        while (self.made < readers_per_run) try self.make(try std.fmt.bufPrint(&name_buf, "r{d}", .{self.made}));
        var draws: usize = 0;
        while (self.readersAfterGlobal() < 2) : (draws += 1) {
            if (draws == max_draws) return error.WalkOrderNeverPutTwoReadersAfterTheGlobal;
            self.cache().cache.rehash();
        }
    }

    const readers_per_run = 8;
    const max_draws = 64;

    /// How many readers the realm's end will tear down after its global, in
    /// the order the walk visits the cache's entries (its map's).
    fn readersAfterGlobal(self: *const Readers) usize {
        const wrapper_cache = self.cache();
        var seen_global = false;
        var after: usize = 0;
        var it = wrapper_cache.cache.keyIterator();
        while (it.next()) |key| {
            const instance = key.*;
            if (instance == self.global) {
                seen_global = true;
            } else if (seen_global and instance.vtable == &self.hooked_vtable) {
                after += 1;
            }
        }
        return after;
    }
};

/// How a run of the realm below goes: to its end, or failing once its
/// readers exist - what the arrangement's old bound did, about 1 run in
/// 1,000.
const Run = enum { to_the_end, fail_after_readers };

/// A worker realm of `agent` with `readers` in it, arranged and ended. The
/// realm ends before this returns, on every path: its readers' teardowns
/// count into `readers` while it is `current`.
fn runRealm(readers: *Readers, agent: *protocol.Agent, run: Run) !void {
    const made = try protocol.createWorkerRealm(agent, &.{
        .url = "https://example.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.c_allocator,
    });

    readers.init(made.realm, made.global_scope);
    Readers.current = readers;
    defer Readers.current = null;
    // Declared after `current`'s defer, so it runs first: a failed step ends
    // the realm here, while the hook can still count, not in the agent's end.
    var ended = false;
    defer if (!ended) protocol.destroyWorkerRealm(made.realm, null, null);

    if (run == .fail_after_readers) {
        var name_buf: [16]u8 = undefined;
        while (readers.made < 3) try readers.make(try std.fmt.bufPrint(&name_buf, "r{d}", .{readers.made}));
        return error.ArrangementFailed;
    }

    try readers.arrange();

    protocol.destroyWorkerRealm(made.realm, null, null);
    ended = true;
}

test "a worker realm's end frees its global scope last: every teardown that reads the realm's global finds it alive" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    var readers: Readers = undefined;
    try runRealm(&readers, agent, .to_the_end);

    // Every reader was torn down by the realm's end...
    try testing.expectEqual(readers.made, readers.torn_down);
    // ...and none of them found the global scope freed: it went last.
    try testing.expectEqual(@as(usize, 0), readers.saw_freed_global);
    try testing.expectEqual(readers.made, readers.saw_live_global);
    // The global scope was freed with the realm all the same.
    try testing.expect(runtime.SlabAllocator.generationOf(readers.global) != readers.global_generation);
}

test "a run that fails once its readers exist ends its realm before it returns: the test fails by name, its process does not crash" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    var readers: Readers = undefined;
    try testing.expectError(error.ArrangementFailed, runRealm(&readers, agent, .fail_after_readers));
    // The realm ended on the way out, while the readers' hook could still
    // count them - not later, in the agent's end, with `current` gone.
    try testing.expectEqual(@as(usize, 3), readers.made);
    try testing.expectEqual(readers.made, readers.torn_down);
    try testing.expectEqual(@as(usize, 0), readers.saw_freed_global);
}
