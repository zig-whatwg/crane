//! dom.instance_bridge.getNodeBase answers from a direct-mapped cache in
//! front of its map (Bridge.cache), and the cache's answer is always the
//! map's: what register put there, null once unregister took it out, and -
//! for an address reused without an unregister - whatever the map still
//! holds for that address. These pin each case against the answer the map
//! alone gave before the cache, through every path that writes or reads an
//! entry: a hit, a miss that fills, an unregister that clears, a freed slot,
//! a reused slot, and entries evicted by collisions.

const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");

const testing = std.testing;
const bridge = dom.instance_bridge;
const NodeBase = dom.NodeBase;
const BrowserScope = runtime.BrowserScope;

const no_methods = .{};
const vtable: runtime.VTable = .{ .name = "Bridged", .deinit = null, .methods_ptr = &no_methods };

/// A NodeBase the bridge only points at: register writes its owner_instance
/// and unregister clears it, and nothing else of it is read.
fn base() NodeBase {
    var node: NodeBase = undefined;
    node.owner_instance = null;
    return node;
}

test "a registered instance maps to its NodeBase on every read, and to null once unregistered" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var node = base();
    const instance = try scope.slab.alloc(&vtable);

    // Before register: no bridge yet, then a bridge with no entry.
    try testing.expectEqual(@as(?*NodeBase, null), bridge.getNodeBase(instance));
    try bridge.register(instance, &node);
    try testing.expectEqual(@as(?*anyopaque, instance), node.owner_instance);
    for (0..3) |_| try testing.expectEqual(@as(?*NodeBase, &node), bridge.getNodeBase(instance));

    bridge.unregister(instance);
    try testing.expectEqual(@as(?*anyopaque, null), node.owner_instance);
    for (0..3) |_| try testing.expectEqual(@as(?*NodeBase, null), bridge.getNodeBase(instance));
}

test "a null answer read before register does not outlive the register" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var other = base();
    var node = base();
    // A bridge exists (another node), and this instance is read - and its
    // null cached - before it registers.
    const first = try scope.slab.alloc(&vtable);
    try bridge.register(first, &other);
    const instance = try scope.slab.alloc(&vtable);
    try testing.expectEqual(@as(?*NodeBase, null), bridge.getNodeBase(instance));
    try testing.expectEqual(@as(?*NodeBase, null), bridge.getNodeBase(instance));
    try bridge.register(instance, &node);
    try testing.expectEqual(@as(?*NodeBase, &node), bridge.getNodeBase(instance));
    try testing.expectEqual(@as(?*NodeBase, &other), bridge.getNodeBase(first));
}

test "a slot freed and reused without an unregister answers what the map still holds" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    var stale = base();
    var fresh = base();

    const instance = try scope.slab.alloc(&vtable);
    try bridge.register(instance, &stale);
    try testing.expectEqual(@as(?*NodeBase, &stale), bridge.getNodeBase(instance));

    // Freed with its entry left in the map (no unregister - the M13 case):
    // the dead slot is never a cache hit, so the map answers, as it did
    // before the cache.
    scope.slab.free(instance);
    try testing.expectEqual(runtime.SlabAllocator.dead_generation, runtime.SlabAllocator.generationOf(instance));
    try testing.expectEqual(@as(?*NodeBase, &stale), bridge.getNodeBase(instance));

    // The slab hands the address out again under a new generation: the
    // entry cached for the old occupant does not match it, and the map's
    // stale answer is what comes back - unchanged behaviour.
    const reused = try scope.slab.alloc(&vtable);
    try testing.expectEqual(@intFromPtr(instance), @intFromPtr(reused));
    try testing.expectEqual(@as(?*NodeBase, &stale), bridge.getNodeBase(reused));
    try testing.expectEqual(@as(?*NodeBase, &stale), bridge.getNodeBase(reused));

    // The new occupant registers: its own NodeBase, then null when it goes.
    try bridge.register(reused, &fresh);
    try testing.expectEqual(@as(?*NodeBase, &fresh), bridge.getNodeBase(reused));
    bridge.unregister(reused);
    try testing.expectEqual(@as(?*NodeBase, null), bridge.getNodeBase(reused));
}

test "entries that collide evict each other and every answer stays the map's" {
    var scope = BrowserScope.init(testing.allocator);
    defer scope.deinit();
    // More instances than cache entries (1,024): addresses 32 KB apart share
    // an entry, so reads in any order evict and refill.
    const count = 3000;
    const nodes = try testing.allocator.alloc(NodeBase, count);
    defer testing.allocator.free(nodes);
    const instances = try testing.allocator.alloc(*runtime.Instance, count);
    defer testing.allocator.free(instances);
    for (nodes, instances) |*node, *instance| {
        node.owner_instance = null;
        instance.* = try scope.slab.alloc(&vtable);
        try bridge.register(instance.*, node);
    }
    // Every third one leaves.
    for (instances, 0..) |instance, i| {
        if (i % 3 == 0) bridge.unregister(instance);
    }
    // Forwards, backwards, and strided, twice each.
    for (0..2) |_| {
        for (instances, nodes, 0..) |instance, *node, i| {
            const want: ?*NodeBase = if (i % 3 == 0) null else node;
            try testing.expectEqual(want, bridge.getNodeBase(instance));
        }
        var i: usize = count;
        while (i > 0) {
            i -= 1;
            const want: ?*NodeBase = if (i % 3 == 0) null else &nodes[i];
            try testing.expectEqual(want, bridge.getNodeBase(instances[i]));
        }
        var k: usize = 0;
        while (k < count) : (k += 7) {
            const want: ?*NodeBase = if (k % 3 == 0) null else &nodes[k];
            try testing.expectEqual(want, bridge.getNodeBase(instances[k]));
        }
    }
    try testing.expectEqual(@as(usize, count - (count + 2) / 3), bridge.entryCount(&scope));
}
