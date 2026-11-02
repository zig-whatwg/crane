//! HTML "run steps after a timeout", step 4: wait until every invocation that
//! started earlier, with a timeout no longer than this one's, has completed.
//!
//! For one manager that is deadline order, with scheduling order breaking
//! ties. `poll` fired whatever was due in its hash map's iteration order, so
//! `setTimeout(a, 0); setTimeout(b, 0)` could run b first - measured "cab"
//! for the sequence below. evil-spec-example.any.js depends on the order: the
//! timer its toString() schedules must run before the one being set.
//!
//! The same test next to the code in native_timer.zig never ran: the build
//! collects tests/**/*_test.zig and nothing else.

const std = @import("std");
const clock = @import("clock");
const v8 = @import("v8");
const NativeTimerManager = v8.native_timer.NativeTimerManager;

const Order = struct {
    var seq: [8]u8 = undefined;
    var n: usize = 0;

    fn reset() void {
        n = 0;
    }

    fn mk(comptime tag: u8) fn (?*anyopaque) void {
        return struct {
            fn f(_: ?*anyopaque) void {
                seq[n] = tag;
                n += 1;
            }
        }.f;
    }

    fn got() []const u8 {
        return seq[0..n];
    }
};

/// A timer the test armed: its tag, and the deadline the manager gave it.
const Armed = struct {
    tag: u8,
    deadline_ns: i128,
};

/// Arm `tag` for `ms`, and read back the deadline it got - checked against
/// the manager's clock read around the call: `ms` after a moment within it.
fn arm(mgr: *NativeTimerManager, ms: u64, comptime tag: u8) !Armed {
    const before = mgr.nowNs();
    const id = mgr.setTimeout(ms, Order.mk(tag), null);
    const after = mgr.nowNs();
    const entry = mgr.timers.get(id) orelse return error.TestTimerNotArmed;
    const delay: i128 = @as(i128, @intCast(ms)) * std.time.ns_per_ms;
    try std.testing.expect(entry.deadline_ns >= before + delay and entry.deadline_ns <= after + delay);
    return .{ .tag = tag, .deadline_ns = entry.deadline_ns };
}

/// The order `armed` must fire in, given in the order it was armed: by
/// deadline, then in that order (a stable sort keeps it among equals).
fn deadlineOrder(armed: []Armed, out: []u8) []const u8 {
    std.sort.insertion(Armed, armed, {}, struct {
        fn lessThan(_: void, a: Armed, b: Armed) bool {
            return a.deadline_ns < b.deadline_ns;
        }
    }.lessThan);
    for (armed, 0..) |a, i| out[i] = a.tag;
    return out[0..armed.len];
}

test "due timers fire in deadline order, then in the order they were scheduled" {
    Order.reset();
    var mgr = try NativeTimerManager.init(std.testing.allocator);
    defer mgr.deinit();

    // Scheduled first but due last - when the three calls fall within 5 ms;
    // a and b due together, a scheduled first. The deadlines are what the
    // calls actually got: on a loaded host the 5 ms can pass between the
    // calls ("acb", even "cab", is then the deadline order - FLAKY in lane
    // tstate1's gates, 2026-11-02, expecting "abc" always).
    var armed = [_]Armed{
        try arm(mgr, 5, 'c'),
        try arm(mgr, 0, 'a'),
        try arm(mgr, 0, 'b'),
    };
    // Every one is due by then: the last deadline is at most 5 ms after the
    // last call.
    clock.sleep(10 * std.time.ns_per_ms);
    _ = mgr.poll();

    var expected: [armed.len]u8 = undefined;
    try std.testing.expectEqualStrings(deadlineOrder(&armed, &expected), Order.got());
}

test "many timers due together keep their scheduling order" {
    Order.reset();
    var mgr = try NativeTimerManager.init(std.testing.allocator);
    defer mgr.deinit();

    // Enough entries that any hash-order coincidence would show.
    _ = mgr.setTimeout(0, Order.mk('1'), null);
    _ = mgr.setTimeout(0, Order.mk('2'), null);
    _ = mgr.setTimeout(0, Order.mk('3'), null);
    _ = mgr.setTimeout(0, Order.mk('4'), null);
    _ = mgr.setTimeout(0, Order.mk('5'), null);
    _ = mgr.setTimeout(0, Order.mk('6'), null);
    clock.sleep(2 * std.time.ns_per_ms);
    _ = mgr.poll();

    try std.testing.expectEqualStrings("123456", Order.got());
}
