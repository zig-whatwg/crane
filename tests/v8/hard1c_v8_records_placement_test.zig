//! Allocator hardening, batch C, item 1: the V8 adapter's per-Browser /
//! per-agent Zig records (AgentRecord, WrapperCache chunks & peers,
//! WindowRealms, WorldRealm) live in the Browser's heap `.objects` partition
//! rather than `std.heap.c_allocator`.
//!
//! Design: tmp/plans/allocator-hardening-design.md §§1.2 rows 31-33, 3.1,
//! 7 Batch C item 1 and red test "a wrapper-cache record and a realm record
//! are in the objects range".
//!
//! RED on main `7cec3d819`:
//! - `AgentRecord` (which holds `caches`, `window_realms`, `worlds`, `realms`)
//!   is allocated on `std.heap.c_allocator` (`protocol_agents.zig:730`);
//! - `WrapperCache.peers` (`Caches`) grows on `caches_allocator = c_allocator`
//!   (`wrapper_cache.zig:853`);
//! - `protocol_realms` (`WindowRealms`) and `protocol_worlds` (`WorldRealm`)
//!   allocate on `std.heap.c_allocator`.

const std = @import("std");
const testing = std.testing;
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");

const BrowserScope = runtime.BrowserScope;
const Heap = BrowserScope.Heap;

const Range = enum { outside, cage, objects, bytes, metadata };

fn rangeOf(heap: *const Heap.BrowserHeap, ptr: *const anyopaque) Range {
    const address = @intFromPtr(ptr);
    if (address < heap.reserved.base or address - heap.reserved.base >= heap.reserved.size) return .outside;
    const offset: u64 = address - heap.window_base;
    const l = Heap.layout;
    if (offset >= l.cage.offset and offset < l.cage.end()) return .cage;
    if (offset >= l.objects.offset and offset < l.objects.end()) return .objects;
    if (offset >= l.bytes.offset and offset < l.bytes.end()) return .bytes;
    return .metadata;
}

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(r.allocator, r) catch null;
    }
};

const NoopReporter = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
};

test "item 1: V8 agent record, wrapper-cache chunks & peers, and realm records live in .objects" {
    test_process.start();

    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    const heap_engine = try scope.heapEngine();
    const heap = scope.heap orelse return error.NoHeap;
    if (!heap.general_pools) return error.SkipZigTest;

    const agent_cache = try heap_engine.attachAgent();
    defer heap_engine.detachAgent(agent_cache);
    scope.useGeneralAllocator(agent_cache.allocator());

    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .hooks = &no_hooks,
        .allocator = scope.allocator,
    });
    defer protocol.destroyAgent(agent);

    const realm = try protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = true,
        .agent = agent,
        .allocator = scope.allocator,
        .browser_scope = &scope,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    // Evaluate script creating a non-node platform object (Event) so
    // WrapperCache allocates a Chunk and registers in AgentRecord.caches.
    const result = try protocol.evaluateClassicScriptToString(
        realm,
        .{ .utf8 = "globalThis.__ev = new Event('hard1c'); globalThis.__ev.type" },
        "",
        null,
        testing.allocator,
        .{ .report = NoopReporter.report, .host = null },
    );
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("hard1c", result);

    // 1. The realm record (`ContextData`) lives in `.objects`.
    try testing.expectEqual(Range.objects, rangeOf(heap, realm));

    // 2. The WrapperCache, its Cell chunk pool, AgentRecord (via `peers`), and
    //    `AgentRecord.caches` backing array all live in `.objects`.
    const raw_cache = realm.getV8WrapperCacheStorage() orelse return error.NoWrapperCache;
    const cache: *v8.WrapperCache = @ptrCast(@alignCast(raw_cache));
    try testing.expectEqual(Range.objects, rangeOf(heap, cache));
    const chunk = cache.chunks orelse return error.NoChunk;
    try testing.expectEqual(Range.objects, rangeOf(heap, chunk));
    const peers = cache.peers orelse return error.NoPeers;
    // `&record.caches` is inside `AgentRecord`.
    try testing.expectEqual(Range.objects, rangeOf(heap, peers));
    try testing.expect(peers.items.len >= 1);
    try testing.expectEqual(Range.objects, rangeOf(heap, @ptrCast(peers.items.ptr)));

    // 3. Creating an isolated world allocates its WorldRealm record & maps in
    //    `.objects` (observable via `general_objects.live_blocks` rising).
    const before_world = heap_engine.stats().general_objects.live_blocks;
    const world = try protocol.createWorldRealm(realm, &.{ .world = 1, .name = "hard1c-world" });
    const after_world = heap_engine.stats().general_objects.live_blocks;
    try testing.expect(after_world > before_world);
    try testing.expectEqual(Range.objects, rangeOf(heap, world));
}
