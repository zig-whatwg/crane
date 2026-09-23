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

test "due timers fire in deadline order, then in the order they were scheduled" {
    Order.reset();
    var mgr = try NativeTimerManager.init(std.testing.allocator);
    defer mgr.deinit();

    // Scheduled first but due last; a and b due together, a scheduled first.
    _ = mgr.setTimeout(5, Order.mk('c'), null);
    _ = mgr.setTimeout(0, Order.mk('a'), null);
    _ = mgr.setTimeout(0, Order.mk('b'), null);
    clock.sleep(10 * std.time.ns_per_ms);
    _ = mgr.poll();

    try std.testing.expectEqualStrings("abc", Order.got());
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
