//! A worker global's map of setTimeout and setInterval IDs
//! (WorkerHost.timers) under a worker's churn (lane timerheap1; the harness
//! lane hashmaps1 lacked).
//!
//! The map is driven here exactly as WorkerHost drives it, through its own
//! field type: setTimer reserves a slot (`ensureUnusedCapacity`), takes the
//! next id from the global's counter - a `contains` that misses, since ids
//! only grow - and puts the timer (`putAssumeCapacityNoClobber`); a timer
//! that runs its last time, or is cleared, is removed. Every key is one the
//! map never saw, so std's map, which never counts a tombstone against its
//! load (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`), runs out of
//! free slots, and every setTimeout then walks the whole table. And a burst
//! leaves the map at the capacity its biggest moment needed.
//!
//! The values are never read by the map: a stand-in address serves.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const html = @import("html");
const tombstones = @import("infra").tombstones;

const Timers = @FieldType(html.worker_host.WorkerHost, "timers");
const Value = @typeInfo(@TypeOf(Timers.get)).@"fn".return_type.?;
const Ctx = @typeInfo(Value).optional.child;

const stand_in: Ctx = @ptrFromInt(0x1000);

/// The std map under `timers`, for slot counts.
fn table(timers: *Timers) *std.AutoHashMapUnmanaged(runtime.TimerId, Ctx) {
    if (@hasField(Timers, "map")) return &timers.map;
    return timers;
}

/// What WorkerHost does with its map for one global's script.
const Global = struct {
    timers: Timers = .empty,
    next_id: runtime.TimerId = 1,

    /// setTimer: reserve, take an id (timer initialization step 2), put.
    fn arm(self: *Global) !runtime.TimerId {
        try self.timers.ensureUnusedCapacity(testing.allocator, 1);
        const id = while (true) {
            const id = self.next_id;
            self.next_id += 1;
            if (!self.timers.contains(id)) break id;
        };
        self.timers.putAssumeCapacityNoClobber(id, stand_in);
        return id;
    }

    /// The trampoline after a one-shot ran, or clearTimer.
    fn remove(self: *Global, id: runtime.TimerId) void {
        _ = self.timers.remove(id);
    }

    fn deinit(self: *Global) void {
        self.timers.deinit(testing.allocator);
    }
};

test "a worker's map of timer ids keeps half its unused slots free while timers come and go" {
    var global: Global = .{};
    defer global.deinit();
    // An interval live across everything below.
    const resident = try global.arm();
    var starved: usize = 0;
    var worst: usize = 0;
    for (0..300) |_| {
        // A burst armed together and run together, then a chain of
        // setTimeout(f, 0)s, each armed as the last one runs.
        var burst: [48]runtime.TimerId = undefined;
        for (&burst, 0..) |*id, i| {
            id.* = try global.arm();
            if (i == 0) {
                if (!tombstones.slotCounts(table(&global.timers)).halfOfUnusedFree()) starved += 1;
                worst = @max(worst, tombstones.meanMissProbe(table(&global.timers)));
            }
        }
        for (burst) |id| global.remove(id);
        for (0..64) |_| global.remove(try global.arm());
    }
    if (starved != 0 or worst > 8) {
        const counts = tombstones.slotCounts(table(&global.timers));
        std.debug.print("worker timers: {d} of 300 rounds began with fewer than half the unused slots free; worst mean miss {d} (capacity {d}, live {d}, free {d})\n", .{ starved, worst, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
    try testing.expect(global.timers.contains(resident));
    global.remove(resident);
}

test "a worker's map of timer ids gives back what a burst of 5,000 took once the burst is gone" {
    var global: Global = .{};
    defer global.deinit();
    const resident = try global.arm();
    for (0..16) |_| global.remove(try global.arm());
    const before = table(&global.timers).capacity();

    var burst: [5_000]runtime.TimerId = undefined;
    for (&burst) |*id| id.* = try global.arm();
    for (burst) |id| global.remove(id);
    // The next timers the worker sets, as it goes on.
    for (0..16) |_| global.remove(try global.arm());

    const after = table(&global.timers).capacity();
    if (after > @max(before, 64)) {
        std.debug.print("worker timers: capacity {d} after a burst of 5,000 had gone, against {d} before it\n", .{ after, before });
        return error.BurstKeptItsCapacity;
    }
    try testing.expect(global.timers.contains(resident));
    global.remove(resident);
}
