//! Lane flaky2: hr_time's coarsening grid makes DOMHighResTimeStamp sums
//! exact. Every coarsened moment is a multiple of 2^-3 ms (2^-6 ms cross-origin
//! isolated), which a double holds exactly, so a page's
//! `performance.timeOrigin + performance.now()` equals a worker's timeOrigin
//! taken at the same coarse moment - hr-time/timeOrigin.html's ">=" holds by
//! arithmetic. On the 0.1 ms grid it did not: the sum rounded one step above
//! for about 1 pair in 5.
const std = @import("std");
const hr_time = @import("hr_time");
const dom = @import("dom");

const testing = std.testing;
const Ns = hr_time.Nanoseconds;

/// A realistic estimated monotonic time of the Unix epoch: the monotonic
/// clock's reading (an uptime) less the wall clock's (about 1.79e18 ns, late
/// 2026), coarsened.
fn randomEpoch(random: std.Random, coi: bool) Ns {
    const uptime: Ns = random.intRangeAtMost(i64, 1, 400 * std.time.ns_per_day);
    const wall: Ns = random.intRangeAtMost(i64, 1_700_000_000 * std.time.ns_per_s, 1_900_000_000 * std.time.ns_per_s);
    return hr_time.coarsenTime(uptime - wall, coi);
}

/// What the page computes - timeOrigin + now() - and the worker's timeOrigin
/// taken in the same coarse moment as that now(), through hr_time's own
/// conversions (TimeOrigin, coarsenTime, toMilliseconds).
const Sample = struct { sum: f64, worker_origin: f64 };

fn sample(random: std.Random, coi: bool, coarsen: *const fn (Ns, bool) Ns, to_ms: *const fn (Ns) f64) Sample {
    const epoch = randomEpoch(random, coi);
    const origin_unsafe: Ns = random.intRangeAtMost(i64, std.time.ns_per_s, 400 * std.time.ns_per_day);
    const origin = coarsen(origin_unsafe, coi);
    const now_unsafe = origin_unsafe + random.intRangeAtMost(i64, 0, 600 * std.time.ns_per_s);
    const now = coarsen(now_unsafe, coi);
    const window_origin = to_ms(origin - epoch); // performance.timeOrigin
    const before = to_ms(now - origin); // performance.now()
    // A worker created in the same coarse moment as that now().
    const worker_origin = to_ms(coarsen(now_unsafe, coi) - epoch);
    return .{ .sum = window_origin + before, .worker_origin = worker_origin };
}

fn gridCoarsen(ns: Ns, coi: bool) Ns {
    return hr_time.coarsenTime(ns, coi);
}

fn gridToMs(ns: Ns) f64 {
    return hr_time.toMilliseconds(ns);
}

/// The old grid and conversion, for the red half: 100 us (5 us isolated),
/// nanoseconds converted to a double whole.
fn oldCoarsen(ns: Ns, coi: bool) Ns {
    const resolution: Ns = if (coi) 5_000 else 100_000;
    return @divFloor(ns, resolution) * resolution;
}

fn oldToMs(ns: Ns) f64 {
    return @as(f64, @floatFromInt(ns)) / std.time.ns_per_ms;
}

test "on the grid, timeOrigin + now() is exactly the timeOrigin of the same coarse moment" {
    var prng = std.Random.DefaultPrng.init(0xF1A2);
    const random = prng.random();
    for ([_]bool{ false, true }) |coi| {
        var i: usize = 0;
        while (i < 200_000) : (i += 1) {
            const s = sample(random, coi, &gridCoarsen, &gridToMs);
            try testing.expectEqual(s.worker_origin, s.sum);
        }
    }
}

test "on the old 0.1 ms grid the same sum misses the exact value (the red half)" {
    var prng = std.Random.DefaultPrng.init(0xF1A2);
    const random = prng.random();
    var above: usize = 0;
    var i: usize = 0;
    while (i < 200_000) : (i += 1) {
        const s = sample(random, false, &oldCoarsen, &oldToMs);
        // hr-time/timeOrigin.html: assert_greater_than_equal(workerOrigin, windowOrigin + before)
        if (s.worker_origin < s.sum) above += 1;
    }
    // About 1 in 5 (lane flaky2's simulation: 21%); far more than none.
    try testing.expect(above > 20_000);
}

test "coarsening is monotonic: a <= b gives coarsen(a) <= coarsen(b), in ns and in ms" {
    var prng = std.Random.DefaultPrng.init(0xC0A5);
    const random = prng.random();
    for ([_]bool{ false, true }) |coi| {
        var i: usize = 0;
        while (i < 200_000) : (i += 1) {
            const a: Ns = random.intRangeAtMost(i64, -2_000_000_000 * std.time.ns_per_s, 2_000_000_000 * std.time.ns_per_s);
            const b = a + random.intRangeAtMost(i64, 0, 2 * std.time.ns_per_ms);
            const ca = hr_time.coarsenTime(a, coi);
            const cb = hr_time.coarsenTime(b, coi);
            try testing.expect(ca <= cb);
            try testing.expect(hr_time.toMilliseconds(ca) <= hr_time.toMilliseconds(cb));
            // Coarsening a time already in milliseconds lands on the same grid.
            const ms = hr_time.toMilliseconds(ca);
            try testing.expectEqual(ms, hr_time.coarsen.coarsenMilliseconds(ms, coi));
        }
    }
}

test "the grid's resolutions are what HR-Time allows: no finer than 100 us, 5 us isolated" {
    try testing.expect(hr_time.DEFAULT_RESOLUTION_NS >= 100 * std.time.ns_per_us);
    try testing.expect(hr_time.CROSS_ORIGIN_ISOLATED_RESOLUTION_NS >= 5 * std.time.ns_per_us);
    try testing.expectEqual(@as(f64, 0.125), hr_time.toMilliseconds(hr_time.DEFAULT_RESOLUTION_NS));
    try testing.expectEqual(@as(f64, 0.015625), hr_time.toMilliseconds(hr_time.CROSS_ORIGIN_ISOLATED_RESOLUTION_NS));
}

test "a Web Animations round trip on the grid is exact: (t - end) + end == t" {
    var prng = std.Random.DefaultPrng.init(0xA41);
    const random = prng.random();
    var i: usize = 0;
    while (i < 200_000) : (i += 1) {
        const t = hr_time.toMilliseconds(hr_time.coarsenTime(random.intRangeAtMost(i64, 0, 400 * std.time.ns_per_day), false));
        const end: f64 = @floatFromInt(random.intRangeAtMost(u32, 1, 1_000_000));
        try testing.expectEqual(t, (t - end) + end);
    }
}

test "the process's estimated monotonic time of the Unix epoch is one value once estimated" {
    // The estimate is a hook slot, written only by a start: here the
    // sanctioned test start (process_start.installForTest).
    dom.process_start.installForTest(hr_time.time_origin.estimateAtProcessStart);
    const first = hr_time.time_origin.estimatedMonotonicTimeOfUnixEpoch();
    dom.process_start.installForTest(hr_time.time_origin.estimateAtProcessStart); // a second call keeps the first estimate
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        try testing.expectEqual(first, hr_time.time_origin.estimatedMonotonicTimeOfUnixEpoch());
        try testing.expectEqual(first, hr_time.TimeOrigin.init(false).estimated_epoch);
    }
}
