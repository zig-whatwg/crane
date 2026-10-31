//! Lane flaky2: a scheduled event time is compared at the precision of time
//! values (Web Animations 1 8.1, microseconds), so a finish event and a cancel
//! event scheduled at the same moment in the model compare equal and keep
//! their queue order (4.4 step 6), whichever way the double round trip of
//! finish() rounds.
const std = @import("std");
const dom = @import("dom");
const atTimePrecision = dom.animations.registry.atTimePrecision;

const testing = std.testing;

/// The finish event's scheduled time after finish() at timeline time `time`:
/// the start time is (time - end / rate), and the effect end converts back as
/// (end * (1 / rate) + start) - model.zig's finish() and
/// animationTimeToTimelineTime.
fn finishRoundTrip(time: f64, end: f64, rate: f64) f64 {
    const start = time - end / rate;
    return end * (1 / rate) + start;
}

test "a round trip that rounds up compares equal to the timeline time at microsecond precision" {
    // Timeline times on the old 0.1 ms grid, k * 0.1 ms. hr_time's grid is now
    // binary (k * 0.125 ms), where this round trip is exact for a whole effect
    // end - but not for every end or rate script can set (crane/
    // fk2-animation-event-time-rounding.html picks ones that round up).
    var found_up: usize = 0;
    var found_down: usize = 0;
    var k: u64 = 1000;
    while (k < 60_000) : (k += 1) {
        const time = @as(f64, @floatFromInt(k * 100_000)) / 1e6;
        for ([_]f64{ 1, 2, 0.5 }) |rate| {
            const scheduled = finishRoundTrip(time, 100_000, rate);
            if (scheduled > time) found_up += 1;
            if (scheduled < time) found_down += 1;
            try testing.expectEqual(atTimePrecision(time), atTimePrecision(scheduled));
        }
    }
    // The bug's precondition is real: the bit-for-bit comparison goes both ways.
    try testing.expect(found_up > 1000);
    try testing.expect(found_down > 1000);
}

test "times a microsecond apart stay apart" {
    const time: f64 = 1234.5;
    try testing.expect(atTimePrecision(time + 0.001) > atTimePrecision(time));
    try testing.expect(atTimePrecision(time + 0.003) > atTimePrecision(time + 0.001));
    try testing.expect(atTimePrecision(time - 0.001) < atTimePrecision(time));
}

test "non-finite times pass through" {
    try testing.expect(std.math.isPositiveInf(atTimePrecision(std.math.inf(f64))));
    try testing.expect(std.math.isNegativeInf(atTimePrecision(-std.math.inf(f64))));
    try testing.expect(std.math.isNan(atTimePrecision(std.math.nan(f64))));
}
