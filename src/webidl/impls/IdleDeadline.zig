//! Implementation for IdleDeadline interface
//!
//! Spec: https://w3c.github.io/requestidlecallback/#the-idledeadline-interface
//!
//! What an idle callback is given: how long its idle period has left, and
//! whether it was invoked by its timeout instead. Window's idle callback
//! steps make one through dom.idle_periods (`createDeadline`), which this
//! type installs: nothing else names this impl.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const clock = @import("clock");
const hr_time = @import("hr_time");
const idle_periods = @import("dom").idle_periods;
const IdleDeadline = interfaces.IdleDeadline;

pub const State = IdleDeadline.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// An IdleDeadline's internal state.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The get deadline time algorithm (and with it the timeout: true for
    /// `.timed_out`).
    deadline: idle_periods.Deadline,
    /// For an idle period's deadline: the earliest it has been (ns). The
    /// period's deadline only ever comes earlier - a timer that brought it
    /// forward and then ran must not move it back.
    earliest_ns: i64,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md):
/// Window's idle callback steps make IdleDeadlines here.
pub fn installHooks() void {
    idle_periods.installDeadlines(.{ .create = &createDeadline });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// dom.idle_periods: a new IdleDeadline in `realm` whose get deadline time
/// algorithm is `deadline` ("invoke idle callbacks" step 3.2, "invoke idle
/// callback timeout" step 2.3). The caller's until the engine wraps it.
fn createDeadline(realm: runtime.Context, deadline: idle_periods.Deadline) anyerror!*runtime.Instance {
    const instance = try IdleDeadline.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = try realm.allocator.create(InternalState);
    internal.* = .{
        .allocator = realm.allocator,
        .deadline = deadline,
        .earliest_ns = switch (deadline) {
            .period => |period| period.end_ns,
            .timed_out => |at| at,
        },
    };
    instance.getState(State).own._internal = internal;
    return instance;
}

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Getter for didTimeout: "The didTimeout getter MUST return timeout" -
/// true only for a callback "invoke idle callback timeout" ran.
pub fn get_didTimeout(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.deadline == .timed_out;
}

/// Operation: timeRemaining
/// Spec: https://w3c.github.io/requestidlecallback/#the-timeremaining-method
pub fn call_timeRemaining(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const internal = getInternal(instance) orelse return 0;
    // 1. "Let now be a DOMHighResTimeStamp representing current high
    // resolution time in milliseconds."
    const now: i64 = @intCast(clock.monotonicNanos());
    // 2. "Let deadline be the result of calling IdleDeadline's get deadline
    // time algorithm." An idle period's is computeDeadline, asked again
    // now: a timer or an animation frame requested since brings it forward.
    const deadline_ns: i64 = switch (internal.deadline) {
        .timed_out => |at| at,
        .period => |period| blk: {
            const now_deadline = idle_periods.deadline(instance.ctx, period);
            internal.earliest_ns = @min(internal.earliest_ns, now_deadline);
            break :blk internal.earliest_ns;
        },
    };
    // 3-5: deadline - now, never negative; both coarsened as the clock
    // performance.now() reads is (HR-TIME "coarsen time"; the privacy
    // section asks it of these estimates).
    return remainingMillis(deadline_ns, now);
}

/// `deadline_ns - now_ns` in milliseconds, each coarsened, and 0 when the
/// deadline has passed.
fn remainingMillis(deadline_ns: i64, now_ns: i64) f64 {
    const deadline = hr_time.coarsenTime(deadline_ns, false);
    const now = hr_time.coarsenTime(now_ns, false);
    if (deadline <= now) return 0;
    return @as(f64, @floatFromInt(deadline - now)) / std.time.ns_per_ms;
}

// ============================================================================
// Tests
// ============================================================================

test "remaining time is the coarsened deadline less the coarsened now, in milliseconds" {
    const ms = std.time.ns_per_ms;
    try std.testing.expectEqual(@as(f64, 10), remainingMillis(1_000 * ms + 10 * ms, 1_000 * ms));
    // 100 microsecond resolution: 10.05 ms from a boundary reads 10.
    try std.testing.expectEqual(@as(f64, 10), remainingMillis(1_000 * ms + 10 * ms + 50_000, 1_000 * ms));
}

test "a deadline that has passed leaves no time" {
    const ms = std.time.ns_per_ms;
    try std.testing.expectEqual(@as(f64, 0), remainingMillis(1_000 * ms, 1_000 * ms));
    try std.testing.expectEqual(@as(f64, 0), remainingMillis(1_000 * ms, 2_000 * ms));
}
