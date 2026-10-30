//! Web Animations 1, 4.6-4.7: an animation effect's timing properties and
//! the calculations that turn its local time into an iteration progress.
//!
//! Pure functions of the timing properties, the local time and the
//! animation's playback direction; no engine, no state.
//!
//! Spec: https://drafts.csswg.org/web-animations-1/#animation-effects
const std = @import("std");
const easing_mod = @import("easing.zig");

const Allocator = std.mem.Allocator;
const inf = std.math.inf(f64);

/// 6.5.2 FillMode.
pub const FillMode = enum { none, forwards, backwards, both, auto };
/// 6.5.3 PlaybackDirection.
pub const Direction = enum { normal, reverse, alternate, alternate_reverse };
/// 4.6.6 the phases; `idle` when the local time is unresolved.
pub const Phase = enum { before, active, after, idle };

/// An animation effect's specified timing properties (4.6, 6.5.1).
pub const Timing = struct {
    /// The start delay, ms.
    delay: f64 = 0,
    /// The end delay, ms.
    end_delay: f64 = 0,
    fill: FillMode = .auto,
    iteration_start: f64 = 0,
    /// The iteration count: >= 0, possibly +Infinity.
    iterations: f64 = 1,
    /// The iteration duration, ms; null is "auto" (zero in this level, but
    /// getTiming() reports "auto").
    duration: ?f64 = null,
    direction: Direction = .normal,
    /// OWNED.
    easing: easing_mod.Easing = .{},

    pub fn deinit(self: *Timing, allocator: Allocator) void {
        self.easing.deinit(allocator);
    }

    pub fn clone(self: *const Timing, allocator: Allocator) Allocator.Error!Timing {
        var copy = self.*;
        copy.easing = try self.easing.clone(allocator);
        return copy;
    }

    /// The iteration duration used for timing: "auto" is zero (6.5.1).
    pub fn iterationDuration(self: *const Timing) f64 {
        return self.duration orelse 0;
    }

    /// The fill mode used for timing: "auto" is none (6.5.1).
    pub fn computedFill(self: *const Timing) FillMode {
        return if (self.fill == .auto) .none else self.fill;
    }

    /// 4.6.5.2: "iteration duration × iteration count", zero when either is.
    pub fn activeDuration(self: *const Timing) f64 {
        const duration = self.iterationDuration();
        if (duration == 0 or self.iterations == 0) return 0;
        return duration * self.iterations;
    }

    /// 4.6.5.3: "max(start delay + active duration + end delay, 0)".
    pub fn endTime(self: *const Timing) f64 {
        return @max(self.delay + self.activeDuration() + self.end_delay, 0);
    }
};

/// Everything 4.6.6-4.7.8 derive from one local time.
pub const Computed = struct {
    phase: Phase,
    /// 4.7.2; null is unresolved.
    active_time: ?f64,
    /// 4.7.3.
    overall_progress: ?f64,
    /// 4.7.4.
    simple_iteration_progress: ?f64,
    /// 4.7.5; may be +Infinity.
    current_iteration: ?f64,
    /// 4.7.6.
    directed_progress: ?f64,
    /// 4.7.7-4.7.8: the iteration progress.
    progress: ?f64,
    /// 4.7.7 step 2: the before flag the easing was evaluated with (a
    /// keyframe's easing takes it too, 5.3.4 step 15).
    before_flag: bool = false,
};

/// 4.6.6 an animation effect's phase, given its local time and whether its
/// animation plays backwards ("animation direction"). `inclusive` is the
/// endpoint-inclusive active interval flag (commit computed styles).
pub fn phase(timing: *const Timing, local_time: ?f64, backwards: bool, inclusive: bool) Phase {
    const local = local_time orelse return .idle;
    const end_time = timing.endTime();
    // "before-active boundary time: max(min(start delay, end time), 0)".
    const before_active = @max(@min(timing.delay, end_time), 0);
    // "active-after boundary time: max(min(start delay + active duration,
    // end time), 0)".
    const active_after = @max(@min(timing.delay + timing.activeDuration(), end_time), 0);
    if (local < before_active or (backwards and !inclusive and local == before_active)) return .before;
    if (local > active_after or (!backwards and !inclusive and local == active_after)) return .after;
    return .active;
}

/// 4.7.2 the active time.
pub fn activeTime(timing: *const Timing, local_time: ?f64, the_phase: Phase) ?f64 {
    const local = local_time orelse return null;
    const fill = timing.computedFill();
    return switch (the_phase) {
        .before => if (fill == .backwards or fill == .both) @max(local - timing.delay, 0) else null,
        .active => local - timing.delay,
        .after => if (fill == .forwards or fill == .both) @max(@min(local - timing.delay, timing.activeDuration()), 0) else null,
        .idle => null,
    };
}

/// 4.6.6-4.7.8 for `local_time`.
pub fn compute(timing: *const Timing, local_time: ?f64, backwards: bool, inclusive: bool) Computed {
    const the_phase = phase(timing, local_time, backwards, inclusive);
    const active_time = activeTime(timing, local_time, the_phase);
    const overall = overallProgress(timing, active_time, the_phase);
    const simple = simpleIterationProgress(timing, overall, active_time, the_phase);
    const iteration = currentIteration(timing, active_time, the_phase, simple, overall);
    const forwards = currentDirectionIsForwards(timing, iteration);
    const directed: ?f64 = if (simple) |s| (if (forwards) s else 1.0 - s) else null;
    var progress: ?f64 = null;
    var before_flag = false;
    if (directed) |d| {
        // 4.7.7 step 2: "the before flag is set if the animation effect is in
        // the before phase and going forwards is true; or if the animation
        // effect is in the after phase and going forwards is false."
        before_flag = (the_phase == .before and forwards) or (the_phase == .after and !forwards);
        progress = timing.easing.evaluate(d, before_flag);
    }
    return .{
        .phase = the_phase,
        .active_time = active_time,
        .overall_progress = overall,
        .simple_iteration_progress = simple,
        .current_iteration = iteration,
        .directed_progress = directed,
        .progress = progress,
        .before_flag = before_flag,
    };
}

/// 4.7.3 the overall progress.
fn overallProgress(timing: *const Timing, active_time: ?f64, the_phase: Phase) ?f64 {
    // 1. "If the active time is unresolved, return unresolved."
    const active = active_time orelse return null;
    // 2.
    const duration = timing.iterationDuration();
    const overall = if (duration == 0)
        (if (the_phase == .before) 0 else timing.iterations)
    else
        active / duration;
    // 3. "Return overall progress + iteration start."
    return overall + timing.iteration_start;
}

/// 4.7.4 the simple iteration progress.
fn simpleIterationProgress(timing: *const Timing, overall_progress: ?f64, active_time: ?f64, the_phase: Phase) ?f64 {
    // 1.
    const overall = overall_progress orelse return null;
    // 2. "If overall progress is infinity, let the simple iteration progress
    // be iteration start % 1.0; otherwise, overall progress % 1.0."
    var simple = if (std.math.isInf(overall)) @mod(timing.iteration_start, 1.0) else @mod(overall, 1.0);
    // 3. The end of an iteration that is the end of the active interval
    // holds the endpoint.
    if (simple == 0 and (the_phase == .active or the_phase == .after) and
        active_time.? == timing.activeDuration() and timing.iterations != 0) simple = 1.0;
    return simple;
}

/// 4.7.5 the current iteration index.
fn currentIteration(timing: *const Timing, active_time: ?f64, the_phase: Phase, simple: ?f64, overall: ?f64) ?f64 {
    // 1.
    _ = active_time orelse return null;
    // 2.
    if (the_phase == .after and std.math.isInf(timing.iterations)) return inf;
    // 3-4.
    if (simple.? == 1.0) return @floor(overall.?) - 1;
    return @floor(overall.?);
}

/// 4.7.6 step 2: whether the current direction is forwards.
fn currentDirectionIsForwards(timing: *const Timing, iteration: ?f64) bool {
    return switch (timing.direction) {
        .normal => true,
        .reverse => false,
        .alternate, .alternate_reverse => blk: {
            var d = iteration orelse break :blk true;
            if (timing.direction == .alternate_reverse) d += 1;
            if (std.math.isInf(d)) break :blk true;
            break :blk @mod(d, 2) == 0;
        },
    };
}

test "an effect's phases follow 4.6.6" {
    const timing: Timing = .{ .delay = 100, .duration = 1000, .fill = .both };
    try std.testing.expectEqual(Phase.before, phase(&timing, 50, false, false));
    try std.testing.expectEqual(Phase.active, phase(&timing, 100, false, false));
    try std.testing.expectEqual(Phase.after, phase(&timing, 1100, false, false));
    // Playing backwards, the start boundary belongs to the before phase.
    try std.testing.expectEqual(Phase.before, phase(&timing, 100, true, false));
    try std.testing.expectEqual(Phase.active, phase(&timing, 1100, true, false));
    // Endpoint-inclusive: the boundaries are active.
    try std.testing.expectEqual(Phase.active, phase(&timing, 1100, false, true));
    try std.testing.expectEqual(Phase.idle, phase(&timing, null, false, false));
}

test "progress fills, repeats and alternates (4.7)" {
    var timing: Timing = .{ .duration = 1000, .iterations = 2, .fill = .forwards, .direction = .alternate };
    const mid_first = compute(&timing, 250, false, false);
    try std.testing.expectEqual(@as(f64, 0.25), mid_first.progress.?);
    try std.testing.expectEqual(@as(f64, 0), mid_first.current_iteration.?);
    const mid_second = compute(&timing, 1250, false, false);
    try std.testing.expectEqual(@as(f64, 0.75), mid_second.progress.?);
    try std.testing.expectEqual(@as(f64, 1), mid_second.current_iteration.?);
    // The end of the active interval holds the endpoint of the last iteration.
    const ended = compute(&timing, 5000, false, false);
    try std.testing.expectEqual(Phase.after, ended.phase);
    try std.testing.expectEqual(@as(f64, 0), ended.progress.?);
    try std.testing.expectEqual(@as(f64, 1), ended.current_iteration.?);
    // No fill: nothing outside the active interval.
    timing.fill = .none;
    try std.testing.expect(compute(&timing, 5000, false, false).progress == null);
    try std.testing.expect(compute(&timing, -1, false, false).active_time == null);
}

test "zero durations and infinite iterations (4.7.3, 4.7.5)" {
    const zero: Timing = .{ .iterations = 3, .fill = .both };
    try std.testing.expectEqual(@as(f64, 0), zero.activeDuration());
    const after = compute(&zero, 0, false, false);
    try std.testing.expectEqual(Phase.after, after.phase);
    try std.testing.expectEqual(@as(f64, 1), after.progress.?);
    try std.testing.expectEqual(@as(f64, 2), after.current_iteration.?);
    const forever: Timing = .{ .iterations = inf, .fill = .forwards };
    const done = compute(&forever, 0, false, false);
    try std.testing.expectEqual(inf, done.current_iteration.?);
    // 4.7.4 step 3: an active interval ending at an iteration's end holds it.
    try std.testing.expectEqual(@as(f64, 1), done.progress.?);
    const endless: Timing = .{ .duration = 100, .iterations = inf };
    try std.testing.expectEqual(inf, endless.activeDuration());
    try std.testing.expectEqual(inf, endless.endTime());
    try std.testing.expectEqual(@as(f64, 0.5), compute(&endless, 1050, false, false).progress.?);
}
