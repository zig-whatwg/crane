//! HTML §8.6 timer initialisation: the nesting level and the 4ms clamp.
//!
//! > If nesting level is greater than 5, and timeout is less than 4, then set
//! > timeout to 4.
//!
//! These steps were implemented twice and applied once. `src/browser/Context.zig`
//! had them at the WINDOW's binding layer, and `src/html/event_loop/timers.zig`
//! had them again (`MIN_NESTED_DELAY_MS`, `NESTING_LEVEL_THRESHOLD`) in an event
//! loop nothing spins. The worker binding
//! (`src/html/worker_v8_context.zig`) had neither, so a nested `setTimeout(f, 0)`
//! in a worker ran unclamped while the identical code in a window was clamped.
//!
//! The rule now lives in `v8.native_timer`, which both bindings already reach
//! because both schedule through the same manager. These tests pin the behaviour
//! there, so a future third copy is unnecessary rather than tempting.
//!
//! Pure arithmetic - no isolate, no event loop. That is the point: the window's
//! clamp only ever had coverage because it was separated from the V8 plumbing, and
//! the worker's had none because it did not exist.

const std = @import("std");
const v8 = @import("v8");
const timer = v8.native_timer;

test "the spec's constants are 4ms and level 5" {
    // Named so a change to either reads as a deliberate spec decision rather than
    // a tuning tweak.
    try std.testing.expectEqual(@as(i64, 4), timer.nested_min_delay_ms);
    try std.testing.expectEqual(@as(u32, 5), timer.nesting_threshold);
}

test "shallow nesting is never clamped" {
    // Levels 0..5 inclusive pass through untouched - the spec says "greater than
    // 5", and an off-by-one here would make a plain `setTimeout(f, 0)` cost 4ms.
    var level: u32 = 0;
    while (level <= timer.nesting_threshold) : (level += 1) {
        try std.testing.expectEqual(@as(i64, 0), timer.clampTimeout(0, level));
        try std.testing.expectEqual(@as(i64, 1), timer.clampTimeout(1, level));
        try std.testing.expectEqual(@as(i64, 3), timer.clampTimeout(3, level));
    }
}

test "deep nesting clamps only delays below 4ms" {
    const deep = timer.nesting_threshold + 1;
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(0, deep));
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(1, deep));
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(3, deep));

    // 4 and above are already compliant and must not be raised - clamping is a
    // floor, not a quantum.
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(4, deep));
    try std.testing.expectEqual(@as(i64, 5), timer.clampTimeout(5, deep));
    try std.testing.expectEqual(@as(i64, 1000), timer.clampTimeout(1000, deep));
}

test "the threshold is exclusive, not inclusive" {
    // The single most likely way to get this wrong, and it is invisible in normal
    // use - it only shows up as timers being 4ms slower than a browser's from the
    // fifth nesting level rather than the sixth.
    try std.testing.expectEqual(@as(i64, 0), timer.clampTimeout(0, timer.nesting_threshold));
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(0, timer.nesting_threshold + 1));
}

test "a negative delay becomes zero before clamping" {
    // `setTimeout(f, -1)` is legal JS. Left negative it would be cast to a huge u64
    // when handed to the timer manager.
    try std.testing.expectEqual(@as(i64, 0), timer.clampTimeout(-1, 0));
    try std.testing.expectEqual(@as(i64, 0), timer.clampTimeout(-1000, 0));

    // And at depth it still clamps up to the floor rather than to 0.
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(-1, timer.nesting_threshold + 1));
}

test "the nesting level is thread-local" {
    // A worker runs its callbacks on its own thread and must not observe the
    // window's depth. If this were a plain global, a deeply nested window timer
    // would start clamping a worker's first-level timers.
    const before = timer.nesting_level;
    defer timer.nesting_level = before;

    timer.nesting_level = 9;

    const Checker = struct {
        fn run(out: *u32) void {
            out.* = timer.nesting_level;
        }
    };
    var seen_on_other_thread: u32 = 0xFFFF_FFFF;
    var t = try std.Thread.spawn(.{}, Checker.run, .{&seen_on_other_thread});
    t.join();

    try std.testing.expectEqual(@as(u32, 0), seen_on_other_thread);
    try std.testing.expectEqual(@as(u32, 9), timer.nesting_level);
}

test "a zero-delay interval reaches the clamp by its sixth repeat" {
    // The repeat case, which is where an unclamped timer actually hurts:
    // `setInterval(f, 0)` reschedules itself, so without the level rising per
    // repeat it stays at 0ms forever and spins the loop as fast as it can
    // schedule. The spec increments the nesting level on each repeat, so it
    // settles at 4ms.
    var level: u32 = 0;
    var delay: i64 = 0;

    // Five repeats at or below the threshold stay unclamped.
    var repeat: usize = 0;
    while (repeat < timer.nesting_threshold) : (repeat += 1) {
        level +|= 1;
        delay = timer.clampTimeout(delay, level);
        try std.testing.expectEqual(@as(i64, 0), delay);
    }

    // The next one crosses it and sticks.
    level +|= 1;
    delay = timer.clampTimeout(delay, level);
    try std.testing.expectEqual(timer.nested_min_delay_ms, delay);

    level +|= 1;
    delay = timer.clampTimeout(delay, level);
    try std.testing.expectEqual(timer.nested_min_delay_ms, delay);
}

test "saturating increment cannot wrap the level back to shallow" {
    // Both bindings record `nesting_level +| 1`. A wrapping `+` would take a
    // pathologically deep chain from u32 max back to 0 and silently switch the
    // clamp off - the one failure mode where the bug gets WORSE the longer a page
    // runs.
    const at_max: u32 = std.math.maxInt(u32);
    try std.testing.expectEqual(at_max, at_max +| 1);
    try std.testing.expectEqual(@as(i64, 4), timer.clampTimeout(0, at_max +| 1));
}
