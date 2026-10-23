//! dom.InstanceStateMap - the side table HTMLOptionElement and
//! HTMLTextAreaElement keep their state in - under a runner's churn (lane
//! hashmaps1): the table is its Browser's, alive for every page, and each
//! page's elements of the type enter it at addresses it never saw and leave
//! it at their teardown; every element's init and deinit also look its own
//! address up and miss. std's map never grows while puts and removes
//! balance and never clears its tombstones (src/infra/tombstones.zig).

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const tombstones = @import("infra").tombstones;

const State = struct {
    selectedness: bool = false,
    dirtiness: bool = false,
};
const Map = dom.InstanceStateMap(State);

/// Keys are addresses: 64-byte steps, as a slab hands out instances.
fn at(address: usize) *const runtime.Instance {
    return @ptrFromInt(address);
}

test "a Browser's element state table keeps half its unused slots free page after page, and its misses short" {
    var map = Map.init(testing.allocator);
    defer map.deinit();
    // A page with a big select writes to 1,000 options at once.
    var next: usize = 0x10_0000;
    for (0..1_000) |_| {
        try map.put(at(next), .{ .selectedness = true });
        next += 64;
    }
    var key: usize = 0x10_0000;
    while (key < next) : (key += 64) _ = map.remove(at(key));
    // Then 400 pages, each with 12 options script selects, made and torn
    // down - every construction and teardown also a miss.
    var starved: usize = 0;
    var worst: usize = 0;
    for (0..400) |_| {
        const first = next;
        for (0..12) |i| {
            _ = map.remove(at(next)); // initOwn: a stale entry at a reissued address?
            const state = try map.getOrPut(at(next));
            state.selectedness = true;
            if (i == 0) {
                if (!tombstones.slotCounts(&map.map).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, tombstones.meanMissProbe(&map.map));
            }
            next += 64;
        }
        key = first;
        while (key < next) : (key += 64) _ = map.remove(at(key)); // deinitOwn
    }
    if (starved != 0 or worst > 8) {
        const counts = tombstones.slotCounts(&map.map);
        std.debug.print("InstanceStateMap: {d} of 400 pages began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
}

const Owning = struct {
    bytes: ?[]u8 = null,
    pub fn deinit(self: *Owning) void {
        if (self.bytes) |bytes| testing.allocator.free(bytes);
        self.bytes = null;
    }
};

test "a state with a deinit is deinit'd by clear and by the table's end; one taken out is the caller's" {
    var map = dom.InstanceStateMap(Owning).init(testing.allocator);
    defer map.deinit();
    try map.put(at(0x1000), .{ .bytes = try testing.allocator.dupe(u8, "a") });
    try map.put(at(0x1040), .{ .bytes = try testing.allocator.dupe(u8, "b") });
    var taken = map.remove(at(0x1000)).?;
    taken.deinit();
    map.clear();
    try testing.expectEqual(@as(usize, 0), map.map.count());
    (try map.getOrPut(at(0x1080))).bytes = try testing.allocator.dupe(u8, "c");
    // The end frees "c" (testing.allocator reports a leak otherwise).
}
