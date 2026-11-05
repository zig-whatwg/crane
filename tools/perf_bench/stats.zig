//! The few statistics the report uses: a median (of samples, then of runs),
//! the spread around it, and the geometric mean of ratios - the one honest
//! way to average "Crane takes x of Chrome's time" over workloads of very
//! different sizes (an arithmetic mean of ratios is dominated by the
//! largest; of raw times, by the slowest workload).

const std = @import("std");
const Allocator = std.mem.Allocator;

/// The median of `values` (the mean of the middle two for an even count);
/// null for none. Sorts a copy.
pub fn median(gpa: Allocator, values: []const f64) Allocator.Error!?f64 {
    if (values.len == 0) return null;
    const copy = try gpa.dupe(f64, values);
    defer gpa.free(copy);
    std.mem.sort(f64, copy, {}, std.sort.asc(f64));
    const mid = copy.len / 2;
    return if (copy.len % 2 == 1) copy[mid] else (copy[mid - 1] + copy[mid]) / 2.0;
}

pub fn medianU64(gpa: Allocator, values: []const u64) Allocator.Error!?u64 {
    if (values.len == 0) return null;
    const copy = try gpa.dupe(u64, values);
    defer gpa.free(copy);
    std.mem.sort(u64, copy, {}, std.sort.asc(u64));
    const mid = copy.len / 2;
    return if (copy.len % 2 == 1) copy[mid] else (copy[mid - 1] + copy[mid]) / 2;
}

/// The median absolute deviation from the median, as a fraction of the
/// median: the noise figure the report prints beside each median.
pub fn relativeMad(gpa: Allocator, values: []const f64) Allocator.Error!?f64 {
    const m = (try median(gpa, values)) orelse return null;
    if (m == 0) return null;
    const dev = try gpa.alloc(f64, values.len);
    defer gpa.free(dev);
    for (values, dev) |v, *d| d.* = @abs(v - m);
    const mad = (try median(gpa, dev)).?;
    return mad / m;
}

/// The geometric mean of positive ratios; null for none. A ratio that is
/// not positive and finite is skipped (it carries no comparison).
pub fn geometricMean(ratios: []const f64) ?f64 {
    var sum: f64 = 0;
    var n: usize = 0;
    for (ratios) |r| {
        if (!(r > 0) or !std.math.isFinite(r)) continue;
        sum += @log(r);
        n += 1;
    }
    if (n == 0) return null;
    return @exp(sum / @as(f64, @floatFromInt(n)));
}

/// The least-squares slope of `ys` against their index (0, 1, ...): bytes
/// per page from a chain's footprint series, bytes per instance from an
/// instances series. Null below two points.
pub fn slope(ys: []const u64) ?f64 {
    if (ys.len < 2) return null;
    const n: f64 = @floatFromInt(ys.len);
    var sx: f64 = 0;
    var sy: f64 = 0;
    var sxx: f64 = 0;
    var sxy: f64 = 0;
    for (ys, 0..) |y, i| {
        const x: f64 = @floatFromInt(i);
        const yf: f64 = @floatFromInt(y);
        sx += x;
        sy += yf;
        sxx += x * x;
        sxy += x * yf;
    }
    const den = n * sxx - sx * sx;
    if (den == 0) return null;
    return (n * sxy - sx * sy) / den;
}

const testing = std.testing;

test "median of odd and even counts, and of none" {
    try testing.expectEqual(@as(?f64, 3), try median(testing.allocator, &.{ 5, 1, 3 }));
    try testing.expectEqual(@as(?f64, 2.5), try median(testing.allocator, &.{ 4, 1, 3, 2 }));
    try testing.expectEqual(@as(?f64, null), try median(testing.allocator, &.{}));
    try testing.expectEqual(@as(?u64, 20), try medianU64(testing.allocator, &.{ 30, 10, 20 }));
}

test "the median does not reorder its input" {
    const values = [_]f64{ 3, 1, 2 };
    _ = try median(testing.allocator, &values);
    try testing.expectEqualSlices(f64, &.{ 3, 1, 2 }, &values);
}

test "relative MAD: the spread as a fraction of the median" {
    // median 10, deviations 0 1 1 5 0 -> MAD 1 -> 0.1
    try testing.expectApproxEqAbs(@as(f64, 0.1), (try relativeMad(testing.allocator, &.{ 10, 9, 11, 15, 10 })).?, 1e-12);
    try testing.expectEqual(@as(?f64, null), try relativeMad(testing.allocator, &.{0}));
}

test "the geometric mean of ratios, skipping what compares nothing" {
    try testing.expectApproxEqAbs(@as(f64, 1.0), geometricMean(&.{ 2.0, 0.5 }).?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4.0), geometricMean(&.{ 2.0, 8.0 }).?, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2.0), geometricMean(&.{ 2.0, 0.0, std.math.inf(f64) }).?, 1e-12);
    try testing.expectEqual(@as(?f64, null), geometricMean(&.{}));
}

test "slope: bytes per step from a series" {
    try testing.expectApproxEqAbs(@as(f64, 100), slope(&.{ 1000, 1100, 1200, 1300 }).?, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0), slope(&.{ 5, 5, 5 }).?, 1e-9);
    try testing.expectEqual(@as(?f64, null), slope(&.{5}));
}
