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
//! order instead, and makes readers until at least one comes after the
//! global - so the case is there on every run.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const dom = @import("dom");
const inline_task_loop = @import("inline_task_loop.zig");

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
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
        const self = current.?;
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

    /// How many readers the realm's end will tear down after its global, in
    /// the order the walk visits the cache's entries (its map's).
    fn readersAfterGlobal(self: *const Readers) usize {
        const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(self.realm.getV8WrapperCacheStorage().?));
        var seen_global = false;
        var after: usize = 0;
        var it = cache.cache.keyIterator();
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

test "a worker realm's end frees its global scope last: every teardown that reads the realm's global finds it alive" {
    try setup();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const made = try protocol.createWorkerRealm(agent, &.{
        .url = "https://example.test/worker.js",
        .timer = null,
        .event_loop = inline_task_loop.eventLoop(),
        .allocator = std.heap.page_allocator,
    });

    var readers: Readers = undefined;
    readers.init(made.realm, made.global_scope);
    Readers.current = &readers;
    defer Readers.current = null;

    // Readers until the walk will reach one after the global scope: the
    // order a freed global was read in.
    var name_buf: [16]u8 = undefined;
    while (readers.readersAfterGlobal() < 2) {
        if (readers.made == 256) return error.WalkOrderNeverPutAReaderAfterTheGlobal;
        try readers.make(try std.fmt.bufPrint(&name_buf, "r{d}", .{readers.made}));
    }

    protocol.destroyWorkerRealm(made.realm, null, null);

    // Every reader was torn down by the realm's end...
    try testing.expectEqual(readers.made, readers.torn_down);
    // ...and none of them found the global scope freed: it went last.
    try testing.expectEqual(@as(usize, 0), readers.saw_freed_global);
    try testing.expectEqual(readers.made, readers.saw_live_global);
    // The global scope was freed with the realm all the same.
    try testing.expect(runtime.SlabAllocator.generationOf(made.global_scope) != readers.global_generation);
}
