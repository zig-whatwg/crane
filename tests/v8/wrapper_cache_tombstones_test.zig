//! A realm's wrapper cache stays cheap to miss in, however many wrappers came
//! and went (lane wrappercache1).
//!
//! The cache maps an instance's address to its entry in a std.AutoHashMap,
//! which deletes by tombstone and never counts a tombstone against its load
//! (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`). Every collected
//! wrapper takes its entry out (`unlinkCollected`), so a page that makes and
//! drops wrappers puts and removes keys it never sees again, the map never
//! grows, and growing is the only thing that clears tombstones on its own. A
//! lookup of a key that is not there probes until it meets a FREE slot: once
//! the tombstones had taken the free slots, every miss walked the whole table.
//! gc_bench's append/remove (100,000 elements made, appended, removed and
//! dropped) left ~90,000 collected nodes on the deferred teardown queue, and
//! the realm's end asked the cache about each one (`wrappedAgain`), so
//! Browser.deinit took 1.5 s in some runs and 3 s in others, as the table's
//! history fell.
//!
//! WebKit's WTF::HashTable counts deleted buckets toward its expand threshold
//! and rehashes in place when the live keys are few (HashTable.h
//! `shouldExpand`, `mustRehashInPlace`); Crane's tables bound their
//! tombstones with webidl.utils.tombstones.TombstoneGuard, and the cache now
//! does too.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const tombstones = @import("webidl").utils.tombstones;

const DeferredTeardown = runtime.gc.DeferredTeardown;
const WrapperCache = v8.wrapper_cache_mod.WrapperCache;

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
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

/// A Window realm and its agent, as a navigation makes them; with a deferred
/// teardown queue when given one, as the Browser's agents have (gc_bench's).
const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(queue: ?*DeferredTeardown) !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{
            .can_block = false,
            .from_snapshot = false,
            .hooks = &no_hooks,
            .host = null,
            .deferred_teardown = queue,
        });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    /// V8's own full collection, twice: the second pass runs synchronously
    /// for a forced one; the deferred queue keeps what it is given.
    fn collect(self: Page) void {
        const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(self.agent));
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
        v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
    }

    fn cache(self: Page) *WrapperCache {
        return @ptrCast(@alignCast(self.realm.getV8WrapperCacheStorage().?));
    }
};

/// What a lookup of an absent key costs in `map`, read off std's slot
/// metadata (one byte a slot; zero is a free slot - tombstones.slotCounts
/// reads it the same way): the slots a probe from each start visits before it
/// meets a free one, averaged over the starts - every start equally likely,
/// as for a key the hash spreads. A table with no free slot left costs its
/// whole capacity per miss.
fn meanMissProbe(map: anytype) f64 {
    const capacity = map.capacity();
    if (capacity == 0) return 0;
    const metadata: [*]const u8 = @ptrCast(map.unmanaged.metadata.?);
    const first_free = std.mem.indexOfScalar(u8, metadata[0..capacity], 0) orelse return @floatFromInt(capacity);
    // Each run of r slots that are not free costs r + (r - 1) + ... + 1 over
    // its starts; a free slot costs nothing.
    var total: u64 = 0;
    var run: u64 = 0;
    var k: usize = 1;
    while (k <= capacity) : (k += 1) {
        if (metadata[(first_free + k) % capacity] == 0) {
            total += run * (run + 1) / 2;
            run = 0;
        } else run += 1;
    }
    return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(capacity));
}

// What the guard leaves a miss to pay. At each insert at least half the
// unused slots are free, and the map is at most 80% full, so at least a
// tenth of the slots stay free from then on (removals free no slot, but they
// take none either): a linear-probing miss then costs about
// (1 + 1/(1 - 0.9)^2) / 2 = 50 slots at worst, a few when the table is
// mostly empty. Without the guard it reaches the capacity - every slot.
const miss_probe_bound: f64 = 64;

/// The guard's lasting bound: at least a tenth of the slots are free.
fn tenthFree(counts: tombstones.SlotCounts) bool {
    return counts.free * 10 >= counts.capacity;
}

/// Objects made in a page's realm - TextEncoders - and kept allocated until
/// `deinit`, so the slab never hands a freed address back: every one is a key
/// the cache has never seen. Each is wrapped as it is made (its entry goes
/// into the cache), and its wrapper is kept reachable from script - in
/// `pinned` for good, or in `kept` until `release` - so the collector never
/// takes it and frees the object behind the test's back.
const Maker = struct {
    page: Page,
    kept: protocol.Owned,
    pinned: protocol.Owned,
    kept_len: usize = 0,
    pinned_len: usize = 0,
    made: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    fn init(page: Page) !Maker {
        var reports: Reports = .{};
        const kept = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = "globalThis.kept = []" }, "", null, reports.reporter());
        errdefer kept.release();
        const pinned = try protocol.evaluateClassicScript(page.realm, .{ .utf8 = "globalThis.pinned = []" }, "", null, reports.reporter());
        try testing.expectEqual(@as(usize, 0), reports.count);
        return .{ .page = page, .kept = kept, .pinned = pinned };
    }

    fn deinit(self: *Maker) void {
        // The objects go first: the realm's end then finds each entry's slot
        // freed (slotReissued) and leaves it alone.
        for (self.made.items) |instance| runtime.Instance.deinit(instance);
        self.made.deinit(testing.allocator);
        self.kept.release();
        self.pinned.release();
    }

    fn make(self: *Maker, into: protocol.JSValue, len: *usize) !*runtime.Instance {
        try self.made.ensureUnusedCapacity(testing.allocator, 1);
        const instance = try interfaces.TextEncoder.init(std.heap.c_allocator, self.page.realm);
        self.made.appendAssumeCapacity(instance);
        var name_buf: [24]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "{d}", .{len.*});
        try protocol.setProperty(self.page.realm, into, name, .{ .instance = instance });
        len.* += 1;
        return instance;
    }

    /// A new object, wrapped, its wrapper kept until `release`.
    fn wrapped(self: *Maker) !*runtime.Instance {
        return self.make(self.kept.value, &self.kept_len);
    }

    /// A new object, wrapped, its wrapper kept for the whole test.
    fn pinnedWrapped(self: *Maker) !*runtime.Instance {
        return self.make(self.pinned.value, &self.pinned_len);
    }

    /// Let the wrappers `wrapped` kept go - once their entries are out of
    /// the cache (`remove` disposes the handle: no weak callback is left).
    fn release(self: *Maker) !void {
        try self.page.run("kept.length = 0;");
        self.kept_len = 0;
    }

    /// Wrap `count` new objects and take their entries out again
    /// (WrapperCache.remove): `count` tombstones' worth of churn.
    fn churn(self: *Maker, cache: *WrapperCache, count: usize) !void {
        const first = self.made.items.len;
        for (0..count) |_| _ = try self.wrapped();
        for (self.made.items[first..]) |instance| try testing.expect(cache.remove(instance));
        try self.release();
    }
};

/// Whether `cache`'s next insert rehashes it: the guard's count of removals
/// could take half its unused slots (tombstones.TombstoneGuard.beforeInsert).
fn nextInsertRehashes(cache: *WrapperCache) bool {
    const unused = cache.cache.capacity() - cache.cache.count();
    return cache.guard.capacity == cache.cache.capacity() and cache.guard.removals * 2 >= unused;
}

test "wrappers put and taken out, round after round, at addresses never used before, leave half the cache's unused slots free" {
    // The cache's own removal (WrapperCache.remove), so every round's keys
    // are new - the shape of a page whose collected nodes wait on the
    // deferred teardown queue.
    const rounds = 24;
    const per_round = 2048;

    const page = try Page.open(null);
    defer page.close();
    const cache = page.cache();
    var maker = try Maker.init(page);
    defer maker.deinit();

    for (0..rounds) |round| {
        const first = maker.made.items.len;
        for (0..per_round) |i| {
            _ = try maker.wrapped();
            if (i == 0 and round > 0) {
                const counts = tombstones.slotCounts(&cache.cache);
                if (!counts.halfOfUnusedFree()) {
                    std.debug.print("round {d}: capacity {d}, live {d}, free {d}\n", .{ round, counts.capacity, counts.live, counts.free });
                    return error.TestExpectedHalfOfUnusedFree;
                }
            }
        }
        for (maker.made.items[first..]) |instance| try testing.expect(cache.remove(instance));
        try maker.release();
    }
    try testing.expect(meanMissProbe(&cache.cache) <= miss_probe_bound);
}

test "an entry read from the cache before an insert rehashes it is the entry the cache answers for its instance after" {
    // A rehash moves the map's slots, never the entries: each CacheEntry is
    // its own allocation, and the map holds pointers to them. So a
    // `*CacheEntry` read before - by finalizeEntry, wrappedAgain, or any
    // `get` - still answers for its instance after an insert rehashed.
    const page = try Page.open(null);
    defer page.close();
    const cache = page.cache();
    var maker = try Maker.init(page);
    defer maker.deinit();

    const kept = try maker.pinnedWrapped();
    const entry = cache.cache.get(kept).?;
    const wrapper = cache.get(kept).?;

    // Churn until the next insert rehashes, then make that insert.
    var rounds: usize = 0;
    while (!nextInsertRehashes(cache)) : (rounds += 1) {
        if (rounds == 64) return error.TestNeverReachedTheRehash;
        try maker.churn(cache, 512);
    }
    const free_before = tombstones.slotCounts(&cache.cache).free;
    _ = try maker.wrapped();
    // It did rehash: the guard's count restarted, and tombstones became
    // free slots again.
    try testing.expectEqual(@as(usize, 0), cache.guard.removals);
    try testing.expect(tombstones.slotCounts(&cache.cache).free > free_before);

    try testing.expectEqual(entry, cache.cache.get(kept).?);
    try testing.expectEqual(kept, entry.instance);
    try testing.expectEqual(wrapper, cache.get(kept).?);
}

const WalkProbe = struct {
    maker: *Maker,
    cache: *WrapperCache,
    residents: []const *runtime.Instance,
    visits: []usize,
    removals_at_start: usize,
    inserted: bool = false,
    rehashed_during_walk: bool = false,

    fn visit(self: *WalkProbe, instance: *runtime.Instance) anyerror!void {
        for (self.residents, 0..) |resident, i| {
            if (resident == instance) self.visits[i] += 1;
        }
        // The first entry the walk meets wraps new objects, as a teardown
        // that a walk runs can - more than enough inserts to rehash, were
        // they allowed to.
        if (self.inserted) return;
        self.inserted = true;
        for (0..8) |_| _ = try self.maker.wrapped();
        // A rehash restarts the count; a collection meanwhile only adds to it.
        if (self.cache.guard.removals < self.removals_at_start) self.rehashed_during_walk = true;
    }
};

test "an insert made while a walk over the cache is under way does not rehash it: the walk meets every entry once, and the next insert rehashes" {
    const page = try Page.open(null);
    defer page.close();
    const cache = page.cache();
    var maker = try Maker.init(page);
    defer maker.deinit();

    // Entries the walk must meet, each exactly once.
    var residents: [64]*runtime.Instance = undefined;
    for (&residents) |*resident| resident.* = try maker.pinnedWrapped();
    // Churn until the next insert would rehash.
    var rounds: usize = 0;
    while (!nextInsertRehashes(cache)) : (rounds += 1) {
        if (rounds == 64) return error.TestNeverReachedTheRehash;
        try maker.churn(cache, 512);
    }
    // Room for the walk's inserts without growing: growth moves the slots
    // too, and is not what this pins.
    try testing.expect(cache.cache.count() + 8 < cache.cache.capacity() * 8 / 10);

    var visits: [64]usize = @splat(0);
    var probe: WalkProbe = .{
        .maker = &maker,
        .cache = cache,
        .residents = &residents,
        .visits = &visits,
        .removals_at_start = cache.guard.removals,
    };
    try cache.walkEntriesForTest(&probe, WalkProbe.visit);

    try testing.expect(probe.inserted);
    try testing.expect(!probe.rehashed_during_walk);
    for (visits) |count| try testing.expectEqual(@as(usize, 1), count);
    // The walk is over: the next insert rehashes.
    try testing.expect(nextInsertRehashes(cache));
    _ = try maker.wrapped();
    try testing.expectEqual(@as(usize, 0), cache.guard.removals);
    try testing.expect(tombstones.slotCounts(&cache.cache).halfOfUnusedFree());
}

test "a page that makes and drops wrapped elements leaves its realm's end cheap misses for every node it queued" {
    // gc_bench's append/remove, shortened: each round makes elements,
    // appends each to a connected host and removes it again, and drops it;
    // V8 collects their wrappers (unlinkCollected takes each entry out) and
    // the deferred teardown queue keeps the nodes - so every round's keys are
    // new. The realm's end then asks the cache about every queued node
    // (drainDeferred -> wrappedAgain): each a miss.
    const rounds = 24;

    var queue = DeferredTeardown.init(testing.allocator);
    defer queue.deinit();
    const page = try Page.open(&queue);
    defer page.close();
    const cache = page.cache();

    try page.run("globalThis.doc = new Document(); globalThis.host = doc.appendChild(doc.createElement('div'));");
    for (0..rounds) |_| {
        try page.run("for (let i = 0; i < 2048; i++) { const e = doc.createElement('div'); host.appendChild(e); void host.removeChild(e); }");
        page.collect();
    }

    // The shape: the collected nodes wait on the queue, alive.
    try testing.expect(queue.pendingNodes() >= rounds * 1024);
    // Checked after the last collection, not at an insert: its removals
    // made tombstones of live slots, so "half the unused slots free" no
    // longer applies - the tenth that the last insert left free does.
    const counts = tombstones.slotCounts(&cache.cache);
    if (!tenthFree(counts)) {
        std.debug.print("capacity {d}, live {d}, free {d}, mean miss probe {d:.1}\n", .{ counts.capacity, counts.live, counts.free, meanMissProbe(&cache.cache) });
        return error.TestExpectedATenthFree;
    }
    try testing.expect(meanMissProbe(&cache.cache) <= miss_probe_bound);
}

test "meanMissProbe: an empty table costs nothing per miss, a loaded one some slots but fewer than its capacity" {
    var map: std.AutoHashMap(usize, void) = .init(testing.allocator);
    defer map.deinit();
    try testing.expectEqual(@as(f64, 0), meanMissProbe(&map));
    try map.ensureTotalCapacity(1000);
    try testing.expectEqual(@as(f64, 0), meanMissProbe(&map));
    var key: usize = 1;
    while (map.count() < map.capacity() * 8 / 10) : (key += 1) map.putAssumeCapacity(key, {});
    const loaded = meanMissProbe(&map);
    try testing.expect(loaded > 0);
    try testing.expect(loaded < @as(f64, @floatFromInt(map.capacity())));
}
