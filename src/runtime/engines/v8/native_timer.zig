//! Timer manager with no libuv dependency.
//!
//! Drop-in replacement for `LibuvTimerManager`, same public API. libuv was linked
//! for exactly one thing - timers ("Link libuv for timer support", build.zig) - and a
//! timer queue needs nothing more than a monotonic clock and a sorted set of
//! deadlines. That is all this is.
//!
//! Why it matters beyond tidiness: the libuv dependency is what forced nine
//! hardcoded `/opt/homebrew/opt/libuv` paths into build.zig, and a host path cannot
//! satisfy an aarch64-ios or Android sysroot. Per the migration plan's M11, removing
//! libuv is a PRECONDITION for cross-compiling at all, not an optimisation.
//!
//! ## Semantics preserved from the libuv implementation
//!
//! - `setTimeout` returns a monotonically increasing id; 0 means failure.
//! - `clearTimeout` returns whether a live timer was actually cancelled. A false
//!   return means the callback may still run, which callers rely on to decide
//!   whether it is safe to free the callback's user_data (see
//!   src/browser/Context.zig).
//! - `poll` fires every timer that is due and reports whether any callback ran.
//! - `getNextTimerDeadline` returns milliseconds until the next timer is due.
//! - `getBackendTimeout` returns -1 for "wait forever", 0 for "do not wait", or a
//!   positive millisecond bound.
//!
//! ## Re-entrancy
//!
//! A timer callback may schedule or cancel timers - `setInterval` reschedules itself
//! from inside its own callback, and clearing a timer from within its callback is
//! ordinary JS. So `poll` snapshots the due ids BEFORE invoking anything, and
//! re-checks each entry still exists and is live at the moment it fires. Mutating
//! the map while iterating it would otherwise invalidate the iterator.

const std = @import("std");
const clock = @import("clock");
const runtime = @import("runtime");

const Allocator = std.mem.Allocator;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const TimerInterface = runtime.TimerInterface;
const TimerVTable = runtime.TimerVTable;

const log = std.log.scoped(.native_timer);

// ============================================================================
// HTML §8.6 timer initialisation: nesting and the 4ms clamp
// ============================================================================
//
// One implementation, shared by the window and worker bindings. It lived only in
// `src/browser/Context.zig`, which is the WINDOW's binding layer - so nested
// `setTimeout(f, 0)` in a worker was never clamped at all, while the same code in
// a window was. Both paths schedule through this manager, so this is the one place
// both can see.
//
// It is not in `src/html/event_loop/timers.zig`, which also implements these steps
// (`MIN_NESTED_DELAY_MS`, `NESTING_LEVEL_THRESHOLD`): nothing spins that event
// loop, so that copy never runs.

/// Minimum delay once nested deeper than `nesting_threshold`. HTML §8.6 step 5.
pub const nested_min_delay_ms: i64 = 4;

/// Nesting depth beyond which `nested_min_delay_ms` applies. HTML §8.6 step 5.
pub const nesting_threshold: u32 = 5;

/// The "current timer nesting level".
///
/// Zero on the event loop's own turn; while a timer callback runs it is that
/// timer's recorded level, so a timer created inside the callback nests one deeper.
/// Thread-local because a worker runs its callbacks on its own thread and must not
/// see the window's depth.
pub threadlocal var nesting_level: u32 = 0;

/// Apply the clamping half of the timer initialisation steps.
///
/// Kept separate from the nesting bookkeeping so it can be unit-tested without a V8
/// isolate - which is the only reason the window's clamp ever had test coverage.
pub fn clampTimeout(requested_ms: i64, nesting: u32) i64 {
    var timeout = requested_ms;
    if (timeout < 0) timeout = 0;
    if (nesting > nesting_threshold and timeout < nested_min_delay_ms) {
        timeout = nested_min_delay_ms;
    }
    return timeout;
}

/// A timer found due by `poll`, in firing order.
const Due = struct {
    deadline_ns: i128,
    id: TimerId,

    fn lessThan(_: void, a: Due, b: Due) bool {
        if (a.deadline_ns != b.deadline_ns) return a.deadline_ns < b.deadline_ns;
        return a.id < b.id;
    }
};

/// One scheduled timer.
const Entry = struct {
    callback: TimerCallback,
    user_data: ?*anyopaque,
    id: TimerId,
    /// Absolute monotonic deadline in nanoseconds. Monotonic, NOT wall clock: a
    /// wall-clock deadline moves under an NTP step and the timer fires early or
    /// never. i128 to match clock.monotonicNanos().
    deadline_ns: i128,
    cancelled: bool,
};

pub const NativeTimerManager = struct {
    const Self = @This();

    allocator: Allocator,
    timers: std.AutoHashMap(TimerId, *Entry),
    next_id: TimerId,
    callback_invoked: bool,
    initialized: bool,

    pub fn init(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .timers = std.AutoHashMap(TimerId, *Entry).init(allocator),
            // Start at 1: 0 is the "invalid id" sentinel the API returns on failure.
            .next_id = 1,
            .callback_invoked = false,
            .initialized = true,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        var iter = self.timers.iterator();
        while (iter.next()) |entry| self.allocator.destroy(entry.value_ptr.*);
        self.timers.deinit();
        self.initialized = false;
        self.allocator.destroy(self);
    }

    /// Schedule a one-shot timer. Returns 0 on failure.
    pub fn setTimeout(self: *Self, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        if (!self.initialized) return 0;

        const id = self.next_id;
        const entry = self.allocator.create(Entry) catch return 0;
        entry.* = .{
            .callback = callback,
            .user_data = user_data,
            .id = id,
            .deadline_ns = clock.monotonicNanos() + @as(i128, @intCast(ms)) * std.time.ns_per_ms,
            .cancelled = false,
        };

        self.timers.put(id, entry) catch {
            self.allocator.destroy(entry);
            return 0;
        };

        // Only consume the id once the timer is actually registered, so a failed
        // schedule does not burn one.
        self.next_id += 1;
        return id;
    }

    /// Cancel a pending timer.
    ///
    /// Returns true only if a live timer with this id was found and cancelled.
    /// False means "not mine, or already gone" - the caller must NOT assume the
    /// callback will not run, and in particular must not free its user_data.
    pub fn clearTimeout(self: *Self, id: TimerId) bool {
        if (!self.initialized) return false;
        if (id == 0) return false;

        if (self.timers.fetchRemove(id)) |kv| {
            const entry = kv.value;
            const was_live = !entry.cancelled;
            self.allocator.destroy(entry);
            return was_live;
        }
        return false;
    }

    /// Fire every timer whose deadline has passed. Returns whether any callback ran.
    pub fn poll(self: *Self) bool {
        if (!self.initialized) return false;
        self.callback_invoked = false;

        const now = clock.monotonicNanos();

        // Snapshot the due ids before invoking anything: a callback may schedule or
        // cancel timers, which would invalidate an in-flight iterator.
        var due: std.ArrayListUnmanaged(Due) = .empty;
        defer due.deinit(self.allocator);

        var iter = self.timers.iterator();
        while (iter.next()) |kv| {
            const entry = kv.value_ptr.*;
            if (entry.cancelled) continue;
            if (entry.deadline_ns <= now) {
                due.append(self.allocator, .{ .deadline_ns = entry.deadline_ns, .id = entry.id }) catch break;
            }
        }

        // HTML "run steps after a timeout" step 4: wait for every earlier
        // invocation whose timeout is no longer than this one's. Deadline
        // order, with ids - which increase in scheduling order - breaking
        // ties, is that order. The map's iteration order is not any order:
        // setTimeout(a, 0); setTimeout(b, 0) could run b first.
        std.mem.sort(Due, due.items, {}, Due.lessThan);

        for (due.items) |item| {
            const id = item.id;
            // Re-check: an earlier callback in this same batch may have cleared it.
            const entry = self.timers.get(id) orelse continue;
            if (entry.cancelled) continue;

            const cb = entry.callback;
            const data = entry.user_data;

            // Remove and free BEFORE invoking. One-shot timers must not be visible
            // to clearTimeout from inside their own callback, and the callback may
            // reschedule under a new id.
            _ = self.timers.remove(id);
            self.allocator.destroy(entry);

            self.callback_invoked = true;
            cb(data);
        }

        return self.callback_invoked;
    }

    /// Longest this backend will block the caller's event loop in one call.
    ///
    /// libuv's pollBlocking ran the WHOLE loop and returned as soon as any handle
    /// became ready, so a long timeout never starved I/O. This backend knows about
    /// timers and nothing else, so sleeping for the caller's full timeout would
    /// monopolise the loop and stall everything that is not a timer - script
    /// loading, worker message dispatch, microtask progress. Observed symptom: the
    /// test file completes with NO subtest results at all.
    ///
    /// So the wait is sliced. The caller re-drives us in its own loop, so the total
    /// wait is still honoured; it just becomes interruptible.
    const max_block_ms: u64 = 1;

    /// Wait (briefly) for a timer to come due, then fire what is due.
    pub fn pollBlocking(self: *Self, timeout_ms: u64) bool {
        if (!self.initialized) return false;
        if (timeout_ms == 0) return self.poll();

        // Anything already due: fire it now rather than sleeping first.
        if (self.poll()) return true;

        // Sleep until the earliest of: the next deadline, the caller's bound, and
        // max_block_ms - see above for why that last cap exists.
        const next = self.getNextTimerDeadline() orelse timeout_ms;
        // Explicit u64: @min against a comptime-known bound narrows the result type
        // (to u1 for max_block_ms = 1), and the ns_per_ms multiply then overflows it.
        const wait_ms: u64 = @min(@min(next, timeout_ms), max_block_ms);

        if (wait_ms > 0) clock.sleep(wait_ms *| std.time.ns_per_ms);
        return self.poll();
    }

    pub fn timerInterface(self: *Self) TimerInterface {
        return .{ .vtable = &vtable, .ctx = self };
    }

    const vtable: TimerVTable = .{
        .setTimeout = setTimeoutVTable,
        .clearTimeout = clearTimeoutVTable,
    };

    fn setTimeoutVTable(ctx: *anyopaque, ms: u64, callback: TimerCallback, user_data: ?*anyopaque) TimerId {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.setTimeout(ms, callback, user_data);
    }

    fn clearTimeoutVTable(ctx: *anyopaque, id: TimerId) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        return self.clearTimeout(id);
    }

    pub fn getPendingCount(self: *Self) usize {
        return self.getActiveTimerCount();
    }

    /// Milliseconds until the next live timer is due, or null if none. 0 means one
    /// is already due.
    pub fn getNextTimerDeadline(self: *Self) ?u64 {
        if (!self.initialized) return null;

        const now = clock.monotonicNanos();
        var min_due_in: ?u64 = null;

        var iter = self.timers.iterator();
        while (iter.next()) |kv| {
            const entry = kv.value_ptr.*;
            if (entry.cancelled) continue;
            const due_in_ns: i128 = if (entry.deadline_ns <= now) 0 else entry.deadline_ns - now;
            const due_in_ms: u64 = @intCast(@divTrunc(due_in_ns, std.time.ns_per_ms));
            if (min_due_in == null or due_in_ms < min_due_in.?) min_due_in = due_in_ms;
        }
        return min_due_in;
    }

    /// -1 = wait forever (nothing scheduled), 0 = do not wait, else millisecond bound.
    pub fn getBackendTimeout(self: *Self) c_int {
        if (!self.initialized) return 0;
        const due_in = self.getNextTimerDeadline() orelse return -1;
        if (due_in == 0) return 0;
        return std.math.cast(c_int, due_in) orelse std.math.maxInt(c_int);
    }

    pub fn getActiveTimerCount(self: *Self) usize {
        if (!self.initialized) return 0;
        var count: usize = 0;
        var iter = self.timers.iterator();
        while (iter.next()) |kv| {
            if (!kv.value_ptr.*.cancelled) count += 1;
        }
        return count;
    }

    /// Present for API compatibility. libuv needed extra loop turns to run close
    /// callbacks for its handles; there are no handles here, so nothing to drain.
    pub fn drainCloseCallbacks(self: *Self) u32 {
        _ = self;
        return 0;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

var fired: usize = 0;
var fired_ids: [8]u64 = undefined;

fn countingCallback(data: ?*anyopaque) void {
    _ = data;
    fired += 1;
}

test "setTimeout ids are non-zero and increasing; 0 is the failure sentinel" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    const a = mgr.setTimeout(10, countingCallback, null);
    const b = mgr.setTimeout(10, countingCallback, null);
    try testing.expect(a != 0);
    try testing.expect(b > a);
}

test "a due timer fires exactly once and is then gone" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    _ = mgr.setTimeout(0, countingCallback, null);
    try testing.expectEqual(@as(usize, 1), mgr.getActiveTimerCount());

    try testing.expect(mgr.poll());
    try testing.expectEqual(@as(usize, 1), fired);
    try testing.expectEqual(@as(usize, 0), mgr.getActiveTimerCount());

    // Polling again must not re-fire it.
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 1), fired);
}

test "a not-yet-due timer does not fire" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    _ = mgr.setTimeout(60_000, countingCallback, null);
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 0), fired);
}

test "clearTimeout reports whether it actually cancelled something" {
    fired = 0;
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    const id = mgr.setTimeout(60_000, countingCallback, null);

    // A live timer: true, and it must not fire afterwards.
    try testing.expect(mgr.clearTimeout(id));
    try testing.expect(!mgr.poll());
    try testing.expectEqual(@as(usize, 0), fired);

    // Already cleared, unknown id, and the 0 sentinel: all false. Callers use this
    // to decide whether freeing the callback's user_data is safe.
    try testing.expect(!mgr.clearTimeout(id));
    try testing.expect(!mgr.clearTimeout(99999));
    try testing.expect(!mgr.clearTimeout(0));
}

test "a callback may schedule another timer without corrupting the map" {
    // setInterval reschedules from inside its own callback, so this must be safe.
    const Rescheduler = struct {
        var mgr_ptr: ?*NativeTimerManager = null;
        var rounds: usize = 0;
        fn cb(data: ?*anyopaque) void {
            _ = data;
            rounds += 1;
            if (rounds < 3) {
                if (mgr_ptr) |m| _ = m.setTimeout(0, cb, null);
            }
        }
    };

    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();
    Rescheduler.mgr_ptr = mgr;
    Rescheduler.rounds = 0;

    _ = mgr.setTimeout(0, Rescheduler.cb, null);
    // Each poll fires the batch that was due when it started; the reschedule lands
    // in the next one.
    _ = mgr.poll();
    _ = mgr.poll();
    _ = mgr.poll();
    try testing.expectEqual(@as(usize, 3), Rescheduler.rounds);
}

test "getNextTimerDeadline and getBackendTimeout agree about emptiness" {
    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    // Nothing scheduled: no deadline, and "wait forever".
    try testing.expectEqual(@as(?u64, null), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(c_int, -1), mgr.getBackendTimeout());

    _ = mgr.setTimeout(0, countingCallback, null);
    // Already due.
    try testing.expectEqual(@as(?u64, 0), mgr.getNextTimerDeadline());
    try testing.expectEqual(@as(c_int, 0), mgr.getBackendTimeout());
}

test "timers fire in deadline order, not insertion order" {
    const Order = struct {
        var seq: [4]u8 = .{ 0, 0, 0, 0 };
        var n: usize = 0;
        fn mk(comptime tag: u8) fn (?*anyopaque) void {
            return struct {
                fn f(_: ?*anyopaque) void {
                    seq[n] = tag;
                    n += 1;
                }
            }.f;
        }
    };
    Order.n = 0;

    var mgr = try NativeTimerManager.init(testing.allocator);
    defer mgr.deinit();

    // Scheduled c first but due last; a and b due together, in the order they
    // were scheduled. One poll fires all three - in that order, as HTML's "run
    // steps after a timeout" requires, whatever order the map iterates in.
    _ = mgr.setTimeout(5, Order.mk('c'), null);
    _ = mgr.setTimeout(0, Order.mk('a'), null);
    _ = mgr.setTimeout(0, Order.mk('b'), null);
    clock.sleep(10 * std.time.ns_per_ms);
    _ = mgr.poll();
    try testing.expectEqual(@as(usize, 3), Order.n);
    try testing.expectEqualStrings("abc", Order.seq[0..3]);
}

test "deinit frees pending timers without leaking" {
    // std.testing.allocator fails the test if anything is left allocated.
    var mgr = try NativeTimerManager.init(testing.allocator);
    _ = mgr.setTimeout(60_000, countingCallback, null);
    _ = mgr.setTimeout(60_000, countingCallback, null);
    mgr.deinit();
}
