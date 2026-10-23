//! NativeTimerManager after a burst of timers (lane timerheap1): one manager
//! serves a Browser's event loop, or a worker's, for as long as the loop
//! lives, and every turn of the loop asks it what is due - the next
//! deadline (how long to wait), a poll, the live count.
//!
//! The manager found what was due by walking its whole id table, and a
//! table never gives capacity back: removals leave the slots (and a
//! TombstoneGuard rehash keeps the size). So a page that once held 5,000
//! timers at once left every later turn walking 8,192 slots - the next
//! power of two above 5,000 / 0.8 - for the rest of the loop's life.
//!
//! Measured with the manager's test-build probe (`Probe`): the slots a
//! turn's search reads, before the burst and after it.

const std = @import("std");
const runtime = @import("runtime");
const NativeTimerManager = runtime.native_timer.NativeTimerManager;
const testing = std.testing;

fn noop(_: ?*anyopaque) void {}

/// One turn of a loop, as the Browser's and a worker's make them: the next
/// deadline (the wait), the poll that fires what is due, the live count
/// (whether the loop has work pending).
fn turn(mgr: *NativeTimerManager) void {
    _ = mgr.getNextTimerDeadline();
    _ = mgr.poll();
    _ = mgr.getActiveTimerCount();
}

/// Run `n` short timers one after another, each armed and then fired by
/// turns of its own, as a setTimeout(f, 0) chain does. The mean slots one
/// turn read.
fn shortTimers(mgr: *NativeTimerManager, n: usize) !u64 {
    const slots_before = mgr.probe.slots;
    const polls_before = mgr.probe.polls;
    for (0..n) |_| {
        const id = mgr.setTimeout(0, noop, null);
        try testing.expect(id != 0);
        // Due as soon as the clock moves past its deadline.
        while (mgr.remainingMs(id) != null) turn(mgr);
    }
    return (mgr.probe.slots - slots_before) / (mgr.probe.polls - polls_before);
}

const Burst = enum { cleared, fired };

/// A page arms 5,000 timers at once and they go - cleared before they are
/// due, or due together and fired by one poll - then 10,000 short timers
/// run one at a time: what one turn costs before and after.
fn burstThenShortTimers(burst: Burst) !void {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    // A long-lived page's interval, live across everything below.
    const resident = mgr.setTimeout(3_600_000, noop, null);
    try testing.expect(resident != 0);

    const before = try shortTimers(mgr, 1_000);

    var ids: [5_000]runtime.TimerId = undefined;
    for (&ids) |*id| {
        id.* = mgr.setTimeout(if (burst == .cleared) 60_000 else 0, noop, null);
        try testing.expect(id.* != 0);
    }
    switch (burst) {
        .cleared => for (ids) |id| try testing.expect(mgr.clearTimeout(id)),
        .fired => while (mgr.getActiveTimerCount() > 1) turn(mgr),
    }
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());

    const after = try shortTimers(mgr, 10_000);
    if (after > before + 2) {
        std.debug.print("timer turns after a {s} burst of 5,000: {d} slots read a turn, against {d} before it\n", .{ @tagName(burst), after, before });
        return error.BurstLeftTurnsSlow;
    }
    try testing.expect(mgr.clearTimeout(resident));
}

test "a turn of the loop reads as little after 5,000 timers were armed and cleared as before them" {
    try burstThenShortTimers(.cleared);
}

test "a turn of the loop reads as little after 5,000 timers fired together as before them" {
    try burstThenShortTimers(.fired);
}

/// The model the random test checks the manager against: each timer's
/// timeout, whether it is still armed, and the armed ones of each short
/// timeout in the order they were armed.
const Model = struct {
    const short_timeouts = 4;
    var ms_of: std.AutoHashMapUnmanaged(runtime.TimerId, u64) = .empty;
    var armed: std.AutoHashMapUnmanaged(runtime.TimerId, void) = .empty;
    var by_timeout: [short_timeouts]std.ArrayListUnmanaged(runtime.TimerId) = @splat(.empty);
    var heads: [short_timeouts]usize = @splat(0);
    var fired: usize = 0;
    var wrong: ?[]const u8 = null;

    fn reset() void {
        ms_of.deinit(testing.allocator);
        armed.deinit(testing.allocator);
        for (&by_timeout) |*list| list.deinit(testing.allocator);
        ms_of = .empty;
        armed = .empty;
        by_timeout = @splat(.empty);
        heads = @splat(0);
        fired = 0;
        wrong = null;
    }

    /// The earliest still armed of those armed with timeout `ms`.
    fn firstArmed(ms: usize) ?runtime.TimerId {
        const list = by_timeout[ms].items;
        while (heads[ms] < list.len and !armed.contains(list[heads[ms]])) heads[ms] += 1;
        return if (heads[ms] < list.len) list[heads[ms]] else null;
    }

    fn fire(data: ?*anyopaque) void {
        const id: runtime.TimerId = @intFromPtr(data);
        if (!armed.remove(id)) {
            wrong = "a timer fired that was not armed";
            return;
        }
        fired += 1;
        // "Run steps after a timeout" step 4.2: every timer armed before
        // this one with a timeout no longer than its own has run (or was
        // cleared) by now.
        const ms = ms_of.get(id).?;
        for (0..@min(ms + 1, short_timeouts)) |shorter| {
            if (firstArmed(shorter)) |earlier| if (earlier < id) {
                wrong = "a timer fired before an earlier one with a timeout no longer than its own";
            };
        }
    }
};

test "random arms, clears and polls: the heap and the map agree, and due timers fire in the spec's order" {
    Model.reset();
    defer Model.reset();
    var prng = std.Random.DefaultPrng.init(0x7173_6865_6170);
    const random = prng.random();
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    var cleared: usize = 0;
    var known: std.ArrayListUnmanaged(runtime.TimerId) = .empty;
    defer known.deinit(testing.allocator);
    var long_ids: std.ArrayListUnmanaged(runtime.TimerId) = .empty;
    defer long_ids.deinit(testing.allocator);

    for (0..12_000) |step| {
        const roll = random.uintLessThan(u8, 100);
        if (roll < 45) {
            // Mostly short timeouts, some never due during the test; now and
            // then a burst.
            const n: usize = if (random.uintLessThan(u8, 200) == 0) 500 else 1;
            for (0..n) |_| {
                const long = random.uintLessThan(u8, 10) == 0;
                const ms: u64 = if (long) 60_000 else random.uintLessThan(u64, Model.short_timeouts);
                const next = mgr.next_id;
                const id = mgr.setTimeout(ms, Model.fire, @ptrFromInt(next));
                try testing.expectEqual(next, id);
                try Model.ms_of.put(testing.allocator, id, ms);
                try Model.armed.put(testing.allocator, id, {});
                if (long) try long_ids.append(testing.allocator, id) else try Model.by_timeout[ms].append(testing.allocator, id);
                try known.append(testing.allocator, id);
            }
        } else if (roll < 75) {
            // clearTimeout of any id this manager handed out: true exactly
            // when it was still armed.
            if (known.items.len == 0) continue;
            // A third among the latest armed, a third among the long
            // timers (mostly still armed, anywhere in the heap), a third
            // among all (mostly fired).
            const id = switch (random.uintLessThan(u8, 3)) {
                0 => known.items[known.items.len - 1 - random.uintLessThan(usize, @min(known.items.len, 16))],
                1 => if (long_ids.items.len == 0) continue else long_ids.items[random.uintLessThan(usize, long_ids.items.len)],
                else => known.items[random.uintLessThan(usize, known.items.len)],
            };
            const was_armed = Model.armed.remove(id);
            try testing.expectEqual(was_armed, mgr.clearTimeout(id));
            if (was_armed) cleared += 1;
        } else {
            if (random.uintLessThan(u8, 20) == 0) @import("clock").sleep(std.time.ns_per_ms);
            _ = mgr.poll();
        }
        if (Model.wrong) |what| {
            std.debug.print("step {d}: {s}\n", .{ step, what });
            return error.WrongOrder;
        }
        try testing.expect(mgr.isConsistent());
        try testing.expectEqual(@as(usize, Model.armed.count()), mgr.getActiveTimerCount());
    }
    // The test reached what it is about: timers fired in batches, and
    // others were cleared.
    if (Model.fired < 5_000 or cleared < 500) {
        std.debug.print("the random test fired {d} timers and cleared {d}\n", .{ Model.fired, cleared });
        return error.TestMissedItsPoint;
    }
}
