//! A platform object made while its realm's wrapper cache is being torn down
//! is never wrapped there, and its maker frees it (lane exitleak1).
//!
//! A realm's end frees what its wrapper cache holds (WrapperCache.deinit),
//! and an object's teardown can make another object in the same realm: a
//! response body freed there ends its fetch's body, and Resource Timing's
//! "mark resource timing" makes a PerformanceResourceTiming, asks the engine
//! to keep it (traceChild) and frees it if it is not wrapped
//! (releaseIfUnwrapped). The cache's sweep destroyed each entry it had
//! handled but left it in its map, so an object the slab gave a handled
//! entry's address found that destroyed entry - its wrapper read back from
//! freed memory, "wrapped" - and nothing freed it; and one at a new address
//! was put into the map being iterated, which the sweep might or might not
//! reach. The WPT runner reported them at exit as intermittent groups of 5
//! and 6 leaked blocks (fetch/api/basic/stream-response.any.js in its worker
//! and service worker realms; every shard holding it).
//!
//! The objects here are TextEncoders whose vtable is a copy with a hook in
//! its deinit, so that a teardown the sweep runs makes an object, as the
//! body's end does.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const v8 = @import("v8");
const interfaces = @import("interfaces");
const inline_task_loop = @import("inline_task_loop.zig");

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

/// A realm and its agent, made and ended the way a host makes and ends them:
/// a Window realm as a navigation does, or a dedicated worker's realm - whose
/// end tears its wrapper cache down with its context entered
/// (worker_realm.destroyWorkerRealmIn), as the leaking worker and service
/// worker realms of the WPT runs were.
const Page = struct {
    const Kind = enum { window, worker };

    kind: Kind,
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(kind: Kind) !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = kind == .worker, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = switch (kind) {
            .window => try protocol.createWindowRealm(&.{
                .agent = agent,
                .allocator = std.heap.c_allocator,
                .from_snapshot = false,
                .timer = null,
                .origin = "https://example.test",
                .create_global_object = WindowHost.createGlobalObject,
            }),
            .worker => (try protocol.createWorkerRealm(agent, &.{
                .url = "https://example.test/worker.js",
                .timer = null,
                .event_loop = inline_task_loop.eventLoop(),
                .allocator = std.heap.page_allocator,
            })).realm,
        };
        return .{ .kind = kind, .agent = agent, .realm = realm };
    }

    fn end(self: Page) void {
        switch (self.kind) {
            .window => protocol.destroyWindowRealm(self.realm, .global_detached),
            .worker => protocol.destroyWorkerRealm(self.realm, null, null),
        }
        protocol.destroyAgent(self.agent);
    }
};

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

/// What the hooked teardowns saw and did. One per test, reached from the
/// hooks through `current` (a test file's own state).
const Spawner = struct {
    /// How the made object asks to be kept.
    const How = enum {
        /// engine.hasWrapper, then releaseIfUnwrapped - what a maker that
        /// never asks for a wrapper does.
        ask,
        /// engine.traceChild from the object being torn down, then
        /// releaseIfUnwrapped - what mark resource timing does (holdEntry).
        trace,
    };

    how: How,
    realm: runtime.Context,
    hooked_vtable: runtime.VTable,
    counting_vtable: runtime.VTable,
    original_deinit: *const fn (*runtime.Instance) void,
    /// Hooked objects torn down so far.
    torn_down: usize = 0,
    /// The addresses of the hooked objects torn down.
    freed: [8]usize = @splat(0),
    /// The object a teardown made, and what was seen of it.
    made: ?*runtime.Instance = null,
    made_reused_an_address: bool = false,
    made_reported_wrapped: bool = false,
    /// How often the made object was freed.
    made_freed: usize = 0,

    var current: ?*Spawner = null;

    fn init(self: *Spawner, how: How, realm: runtime.Context) void {
        const original = &interfaces.TextEncoder.vtable;
        self.* = .{
            .how = how,
            .realm = realm,
            .hooked_vtable = original.*,
            .counting_vtable = original.*,
            .original_deinit = original.deinit.?,
        };
        self.hooked_vtable.deinit = &hookedDeinit;
        self.counting_vtable.deinit = &countingDeinit;
    }

    /// A TextEncoder whose teardown runs the hook, wrapped in the realm as
    /// globalThis[name].
    fn hooked(self: *Spawner, name: []const u8) !void {
        const instance = try interfaces.TextEncoder.init(std.heap.c_allocator, self.realm);
        instance.vtable = &self.hooked_vtable;
        const global = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = "globalThis" }, "", null, Ignored.reporter);
        defer global.release();
        try protocol.setProperty(self.realm, global.value, name, .{ .instance = instance });
    }

    fn hookedDeinit(instance: *runtime.Instance) void {
        const self = current.?;
        self.original_deinit(instance);
        if (self.torn_down < self.freed.len) self.freed[self.torn_down] = @intFromPtr(instance);
        self.torn_down += 1;
        // The second hooked teardown makes an object, as a body's end makes
        // a timing entry - by then the first one's address is free again.
        if (self.torn_down == 2) self.spawn(instance);
    }

    fn countingDeinit(instance: *runtime.Instance) void {
        const self = current.?;
        self.made_freed += 1;
        self.original_deinit(instance);
    }

    fn spawn(self: *Spawner, owner: *runtime.Instance) void {
        // The object each case needs: for `ask`, one at the address of an
        // entry the sweep has already handled (a hooked object freed before
        // this teardown); for `trace`, one at an address the cache never
        // held, whose wrap would be a new entry in the map being iterated.
        // The slab hands freed slots out again; objects made on the way to
        // the one wanted are let go after.
        var fillers: [32]*runtime.Instance = undefined;
        var filled: usize = 0;
        defer for (fillers[0..filled]) |f| runtime.Instance.deinit(f);
        const made = while (true) {
            const candidate = interfaces.TextEncoder.init(std.heap.c_allocator, self.realm) catch return;
            const reused = self.wasFreed(candidate);
            if (reused == (self.how == .ask) or filled == fillers.len) break candidate;
            fillers[filled] = candidate;
            filled += 1;
        };
        made.vtable = &self.counting_vtable;
        self.made = made;
        self.made_reused_an_address = self.wasFreed(made);
        const generation = runtime.SlabAllocator.generationOf(made);
        switch (self.how) {
            .ask => {},
            .trace => protocol.traceChild(owner, made, .{ .name = "exitleak1" }),
        }
        self.made_reported_wrapped = protocol.hasWrapper(made);
        made.releaseIfUnwrapped(generation);
    }

    /// Whether `instance` has the address of a hooked object torn down
    /// before (an entry the sweep has handled).
    fn wasFreed(self: *const Spawner, instance: *runtime.Instance) bool {
        const n = @min(self.torn_down, self.freed.len);
        for (self.freed[0..n]) |address| {
            if (address == @intFromPtr(instance)) return true;
        }
        return false;
    }
};

fn expectMadeObjectFreed(kind: Page.Kind, how: Spawner.How) !void {
    const page = try Page.open(kind);
    var spawner: Spawner = undefined;
    spawner.init(how, page.realm);
    Spawner.current = &spawner;
    defer Spawner.current = null;
    try spawner.hooked("a");
    try spawner.hooked("b");
    try spawner.hooked("c");

    page.end();

    try testing.expect(spawner.torn_down >= 2);
    try testing.expect(spawner.made != null);
    // The case each test is about: the object made for `ask` has the
    // address of an entry the sweep has handled, the one made for `trace` an
    // address the cache never held.
    try testing.expectEqual(how == .ask, spawner.made_reused_an_address);
    // Not wrapped in a cache that is being torn down...
    try testing.expect(!spawner.made_reported_wrapped);
    // ...and freed, once, by the code that made it.
    try testing.expectEqual(@as(usize, 1), spawner.made_freed);
}

test "an object made at a freed entry's address while a Window realm's wrapper cache is torn down is not wrapped, and is freed" {
    try expectMadeObjectFreed(.window, .ask);
}

test "an object made at a freed entry's address while a worker realm's wrapper cache is torn down is not wrapped, and is freed" {
    try expectMadeObjectFreed(.worker, .ask);
}

test "an object traced while a worker realm's wrapper cache is torn down is not put in it, and its maker frees it" {
    try expectMadeObjectFreed(.worker, .trace);
}

// ============================================================================
// A worker global scope's lazily made Performance, freed by the scope only
// while the slot still holds it
// ============================================================================

/// A TextEncoder vtable copy whose deinit counts (the object that takes a
/// freed Performance's slot).
const Reissued = struct {
    var freed: usize = 0;
    var vtable: runtime.VTable = undefined;

    fn countingDeinit(instance: *runtime.Instance) void {
        freed += 1;
        interfaces.TextEncoder.vtable.deinit.?(instance);
    }
};

test "a worker global scope's wrapped Performance freed before the scope's own teardown is left alone: its slot's next object is never freed by the scope" {
    // The order the scope's guard is for: a worker's global scope is freed
    // inside its realm's wrapper cache sweep, in hash order, so a wrapped
    // Performance may be freed before the scope's deinit runs, and its slab
    // slot handed out again. Forced here: the scope's Performance is made and
    // wrapped, then freed first - its cache entry dropped and the object torn
    // down, as the sweep does - its slot reissued, and only then the scope
    // torn down.
    const page = try Page.open(.window);
    defer page.end();
    const scope = try interfaces.DedicatedWorkerGlobalScope.initWith(std.heap.c_allocator, page.realm, .{ .url = "https://example.test/worker.js" });
    const performance = try interfaces.WorkerGlobalScope.get_performance(scope);
    try testing.expect(protocol.hasWrapper(performance));
    const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage().?));
    try testing.expect(cache.remove(performance));
    runtime.Instance.deinit(performance);

    Reissued.freed = 0;
    Reissued.vtable = interfaces.TextEncoder.vtable;
    Reissued.vtable.deinit = &Reissued.countingDeinit;
    const reissued = try interfaces.TextEncoder.init(std.heap.c_allocator, page.realm);
    reissued.vtable = &Reissued.vtable;
    // The case: the slab hands the freed slot out again (last freed, first
    // out).
    try testing.expectEqual(@intFromPtr(performance), @intFromPtr(reissued));

    runtime.Instance.deinit(scope);
    // The scope's deinit left the slot's new object alone...
    try testing.expectEqual(@as(usize, 0), Reissued.freed);
    // ...which is still its maker's to free, once.
    runtime.Instance.deinit(reissued);
    try testing.expectEqual(@as(usize, 1), Reissued.freed);
}

test "a worker global scope frees the Performance it made that never got a wrapper" {
    // What the guard frees: a Performance native code made through the
    // scope's settings while no wrapper could be made for it.
    const page = try Page.open(.window);
    defer page.end();
    const scope = try interfaces.DedicatedWorkerGlobalScope.initWith(std.heap.c_allocator, page.realm, .{ .url = "https://example.test/worker.js" });
    const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(page.realm.getV8WrapperCacheStorage().?));
    // No wrapper is made while the cache says it is torn down.
    cache.is_tearing_down = true;
    const performance = try interfaces.WorkerGlobalScope.get_performance(scope);
    cache.is_tearing_down = false;
    try testing.expect(!protocol.hasWrapper(performance));
    const generation = runtime.SlabAllocator.generationOf(performance);
    runtime.Instance.deinit(scope);
    // Freed with the scope: its slot has moved on.
    try testing.expect(runtime.SlabAllocator.generationOf(performance) != generation);
}
