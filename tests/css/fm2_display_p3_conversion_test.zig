//! CSS Color 4 §19 sample conversion data, not display gamut mapping.
const std = @import("std");
const FloatColor = @import("css").color.FloatColor;
const testing = std.testing;

test "Display P3 conversion uses extended transfer functions and the D65 matrices" {
    // Expected values evaluated independently with the specification's
    // lin_sRGB, lin_sRGB_to_XYZ, XYZ_to_lin_P3 and gam_P3 sample functions.
    const cases = [_]struct { rgb: [3]f64, expected: [3]f64 }{
        .{ .rgb = .{ 1, 0, 0 }, .expected = .{ 0.9174875573251656, 0.20028680774084695, 0.13856059121111408 } },
        .{ .rgb = .{ 1, 1, 1 }, .expected = .{ 1, 1, 1 } },
        .{ .rgb = .{ 1.4, -0.2, 0.3 }, .expected = .{ 1.2843552137273755, 0.22032518824470043, 0.35126986156658374 } },
    };
    for (cases) |case| {
        const value = FloatColor{ .rgb = case.rgb, .alpha = 0.5 };
        const actual = value.toDisplayP3();
        for (case.expected, actual) |expected, channel| try testing.expectApproxEqAbs(expected, channel, 1e-12);
        try testing.expectEqual(@as(f64, 0.5), value.alpha);
    }
}
