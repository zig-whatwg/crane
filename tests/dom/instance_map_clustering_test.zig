//! An instance-keyed map must not cluster when the slab hands back the
//! addresses a teardown freed by walking another instance-keyed map
//! (lane hashclust1; found by lane v8order1 at tests-v8 seed 0x02e77638).
//!
//! The mechanism, end to end, with the real slab and no V8:
//! 1. A realm keeps its objects in a map keyed by instance - the wrapper
//!    cache's `cache` - and its end frees them by walking that map, so in the
//!    order of their home slots.
//! 2. The slab's free list is LIFO: it issues those slots again in the
//!    reverse of that order.
//! 3. The next page's side map - the wrapper cache's `edges_before_wrap`,
//!    keyed by owners script has not seen: a burst of 2,000, then 16 a page,
//!    each taken out again - receives its keys sorted by home slot. If every
//!    table hashes an address alike (std's seed-0 Wyhash), the homes the
//!    side map gives them are the homes the walked tables gave them. Two
//!    realms that end one after the other - a page and its frame, whose table
//!    kept its size after the collector emptied most of it - hand the side
//!    map the frame's keys over every home and the page's last ones over the
//!    top of the table: more keys than slots there, so the keys, and the
//!    tombstones they leave, fill one run of contiguous slots, and every miss
//!    that starts in it walks it. A single walked table cannot do this on its
//!    own (it is at most 80% full); v8order1's replay saw 1,000 consecutive
//!    owners over 488 homes, the residue of many such ends.
//!
//! The bound is the one tests/v8/engine_pending_activity_test asserts for the
//! wrapper cache's side maps: every page begins with half the unused slots
//! free and a mean miss of at most 8 slots.

const std = @import("std");
const runtime = @import("runtime");
const tombstones = @import("infra").tombstones;

const testing = std.testing;
const Instance = runtime.Instance;

const no_methods = .{};
const vtable: runtime.VTable = .{ .name = "Clustering", .deinit = null, .methods_ptr = &no_methods };

/// The map type Crane's instance-keyed tables use.
fn InstanceMap(comptime V: type) type {
    return std.AutoHashMapUnmanaged(*Instance, V);
}

/// The worst a page of the side map began with (engine_pending_activity_test's
/// `SideWorst`).
const Worst = struct {
    probe: usize = 0,
    starved: usize = 0,

    fn note(self: *Worst, map: anytype) void {
        self.probe = @max(self.probe, tombstones.meanMissProbe(map));
        if (!tombstones.slotCounts(map).halfOfUnusedFree()) self.starved += 1;
    }
};

/// A page and its frame end, each freeing its objects by walking the table
/// that keyed them, and the next page's side map is fed from the slab:
/// `Walked` is a realm's table, `Side` the side map. Returns the worst page
/// of the side map.
fn churn(comptime Walked: type, comptime Side: type) !Worst {
    var slab = runtime.SlabAllocator.init(testing.allocator);
    defer slab.deinit();

    // The page's realm: 3,200 objects, a table of 4,096.
    var page: Walked = .empty;
    for (0..3_200) |_| try page.put(testing.allocator, try slab.alloc(&vtable), {});
    // Its frame's realm: 3,000 objects, of which the collector took 2,000
    // during the page - freed in the order they were made - so its table
    // keeps the page's capacity with 1,000 in it.
    var frame: Walked = .empty;
    var made: [3_000]*Instance = undefined;
    for (&made) |*instance| {
        instance.* = try slab.alloc(&vtable);
        try frame.put(testing.allocator, instance.*, {});
    }
    for (made[0..2_000]) |instance| {
        try testing.expect(frame.remove(instance));
        slab.free(instance);
    }
    // The page ends: each realm frees what its table holds by walking it
    // (the wrapper cache's end), the page's first, then the frame's.
    for ([_]*Walked{ &page, &frame }) |table| {
        try testing.expectEqual(@as(usize, 4_096), table.capacity());
        var it = table.keyIterator();
        while (it.next()) |instance| slab.free(instance.*);
        table.deinit(testing.allocator);
    }

    // The next page's side map, with the guard the wrapper cache's side maps
    // have: a burst of 2,000 owners, then 16 a page; every owner is taken out
    // when its wrapper is made. Every key is a slot the slab issues again,
    // the frame's last-freed first.
    var side: Side = .empty;
    defer side.deinit(testing.allocator);
    var guard: tombstones.TombstoneGuard = .{};
    var worst: Worst = .{};
    var owners: [2_000]*Instance = undefined;
    for (0..300) |page_index| {
        const per_page: usize = if (page_index == 0) owners.len else 16;
        for (owners[0..per_page], 0..) |*owner, i| {
            owner.* = try slab.alloc(&vtable);
            if (i == 0 and page_index > 0) worst.note(&side);
            guard.beforeInsert(&side);
            try side.put(testing.allocator, owner.*, 1);
        }
        if (page_index == 0) try testing.expectEqual(@as(usize, 4_096), side.capacity());
        for (owners[0..per_page]) |owner| {
            try testing.expect(side.remove(owner));
            guard.noteRemoval(&side);
        }
    }
    try testing.expectEqual(@as(usize, 0), side.count());
    return worst;
}

fn report(comptime what: []const u8, worst: Worst) void {
    std.debug.print(what ++ ": worst mean miss {d} slots, {d} of 299 pages starved\n", .{ worst.probe, worst.starved });
}

test "the control: std's seed-0 maps cluster on the slots a map-order teardown frees" {
    // Not a property to keep - the proof that the scenario reproduces the
    // defect, so the bound below is not met only because the keys are kind.
    const worst = try churn(std.AutoHashMapUnmanaged(*Instance, void), std.AutoHashMapUnmanaged(*Instance, u32));
    report("std.AutoHashMapUnmanaged", worst);
    try testing.expect(worst.probe > 8);
}

test "an instance-keyed side map keeps half its unused slots free and short misses after a map-order teardown" {
    const worst = try churn(InstanceMap(void), InstanceMap(u32));
    if (worst.starved != 0 or worst.probe > 8) report("InstanceMap", worst);
    try testing.expectEqual(@as(usize, 0), worst.starved);
    try testing.expect(worst.probe <= 8);
}
