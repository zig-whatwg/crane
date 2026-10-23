//! NativeTimerManager's map of timers under a runner's churn (lane
//! hashmaps1): one manager serves a Browser's event loop for every page the
//! process loads, and every timer is a key it has never seen - ids only
//! grow - put when armed and removed when it fires or is cleared.
//!
//! std.HashMap deletes by tombstone and never counts one against its load
//! (lib/std/hash_map.zig `removeByIndex`, `growIfNeeded`), so a map whose puts
//! and removes balance never grows and never clears them. Each new key
//! that meets no tombstone on its probe takes a FREE slot and nothing gives
//! one back; once they are gone every arm, and every clearTimeout of an id
//! that already fired, walks the whole table (src/infra/tombstones.zig).

const std = @import("std");
const runtime = @import("runtime");
const tombstones = @import("webidl").utils.tombstones;
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

fn noop(_: ?*anyopaque) void {}

/// What one page does with timers, as testharness pages do: a burst armed
/// at once and fired together (a test's step_timeouts), a chain armed one
/// after another as each fires (setTimeout(f, 0) loops), timers armed and
/// cleared before they are due, and clearTimeout of ids that already fired.
fn page(mgr: *NativeTimerManager, worst: *Worst) !void {
    var burst: [48]runtime.TimerId = undefined;
    for (&burst, 0..) |*id, i| {
        id.* = mgr.setTimeout(0, noop, null);
        try testing.expect(id.* != 0);
        // The page's first insert: what the previous pages left behind.
        if (i == 0) worst.note(mgr);
    }
    _ = mgr.poll();
    // Cleared after they fired: misses.
    for (burst) |id| try testing.expect(!mgr.clearTimeout(id));
    for (0..64) |_| {
        _ = mgr.setTimeout(0, noop, null);
        _ = mgr.poll();
    }
    for (0..16) |_| try testing.expect(mgr.clearTimeout(mgr.setTimeout(60_000, noop, null)));
}

const Worst = struct {
    probe: usize = 0,
    starved: usize = 0,

    fn note(self: *Worst, mgr: *NativeTimerManager) void {
        self.probe = @max(self.probe, tombstones.meanMissProbe(&mgr.timers));
        if (!tombstones.slotCounts(&mgr.timers).halfOfUnusedFree()) self.starved += 1;
    }
};

test "a runner's pages of timers keep half the timer map's unused slots free, and its misses short" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    // An interval that lives across the pages, as a long-lived page's would.
    const resident = mgr.setTimeout(3_600_000, noop, null);
    var worst: Worst = .{};
    for (0..300) |_| try page(mgr, &worst);
    const counts = tombstones.slotCounts(&mgr.timers);
    if (worst.starved != 0 or worst.probe > 8) {
        std.debug.print("timers: {d} of 300 pages began with fewer than half the unused slots free; worst mean miss {d} slots (capacity {d}, live {d}, free {d})\n", .{ worst.starved, worst.probe, counts.capacity, counts.live, counts.free });
        return error.TombstonesFilledTheMap;
    }
    // The resident timer is still found after every rehash.
    try testing.expect(mgr.remainingMs(resident) != null);
    try testing.expect(mgr.clearTimeout(resident));
}

/// What `Rearm.callback` needs: the manager, the timers it arms, and
/// the long timers it clears to make the removals that force rehashes.
const Rearm = struct {
    var mgr: ?*NativeTimerManager = null;
    var armed: std.ArrayList(runtime.TimerId) = .empty;
    var to_clear: std.ArrayList(runtime.TimerId) = .empty;
    var fired_ids: std.ArrayList(runtime.TimerId) = .empty;
    var rehashes: usize = 0;
    var ran: usize = 0;
    var fail: bool = false;

    fn callback(data: ?*anyopaque) void {
        const id: runtime.TimerId = @intFromPtr(data);
        fired_ids.append(testing.allocator, id) catch {
            fail = true;
        };
        ran += 1;
        const m = mgr.?;
        // A removal, then an insert that may rehash - from inside poll.
        if (to_clear.pop()) |old| {
            if (!m.clearTimeout(old)) fail = true;
        }
        const before = m.guard.removals;
        const next = armed.items.len + 1_000_000;
        const new_id = m.setTimeout(0, callback, @ptrFromInt(next));
        if (new_id == 0) fail = true;
        if (m.guard.removals < before) rehashes += 1;
        armed.append(testing.allocator, @intCast(next)) catch {
            fail = true;
        };
    }
};

test "a timer callback that clears and arms timers inside poll, through rehashes, loses and repeats none" {
    // Lane hashmaps1 / the integrator's check 1: poll fires from a snapshot
    // of due ids, so the map is never iterated while a callback can insert
    // - setTimeout inside a timeout, an interval's re-arm - and a rehash
    // there moves nothing poll still reads.
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    Rearm.mgr = mgr;
    defer {
        Rearm.armed.deinit(testing.allocator);
        Rearm.to_clear.deinit(testing.allocator);
        Rearm.fired_ids.deinit(testing.allocator);
        Rearm.armed = .empty;
        Rearm.to_clear = .empty;
        Rearm.fired_ids = .empty;
        Rearm.mgr = null;
    }
    Rearm.rehashes = 0;
    Rearm.ran = 0;
    Rearm.fail = false;
    for (0..400) |_| try Rearm.to_clear.append(testing.allocator, mgr.setTimeout(3_600_000, noop, null));
    for (0..200) |i| {
        try testing.expect(mgr.setTimeout(0, Rearm.callback, @ptrFromInt(i + 1)) != 0);
    }
    // The first poll fires the 200 it found due; each arms one more.
    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 200), Rearm.ran);
    try testing.expect(Rearm.rehashes > 0);
    // The second poll fires exactly the 200 armed inside the first, once each.
    const armed_in_first = Rearm.armed.items.len;
    try testing.expectEqual(@as(usize, 200), armed_in_first);
    const first_new = try testing.allocator.dupe(runtime.TimerId, Rearm.armed.items);
    defer testing.allocator.free(first_new);
    Rearm.fired_ids.clearRetainingCapacity();
    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 200), Rearm.fired_ids.items.len);
    try testing.expectEqualSlices(runtime.TimerId, first_new, Rearm.fired_ids.items[0..200]);
    try testing.expect(!Rearm.fail);
}
