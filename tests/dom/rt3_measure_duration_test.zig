//! User Timing permits a completed measure to end at the time origin.
//! Zero remains the unset-end sentinel for other performance entries.
const std = @import("std");
const timing = @import("dom").performance_timeline;

test "a measure ending at zero has a duration while an unfinished navigation does not" {
    const cases = .{
        .{ @as(f64, 10), @as(f64, -10) },
        .{ @as(f64, -10), @as(f64, 10) },
        .{ @as(f64, 0), @as(f64, 0) },
    };
    inline for (cases) |case| {
        const entry: timing.EntryData = .{ .name = "measure", .entry_type = .measure, .start_time = case[0], .end_time = 0 };
        try std.testing.expectEqual(case[1], entry.duration());
    }
    const navigation: timing.EntryData = .{ .name = "navigation", .entry_type = .navigation, .start_time = 0 };
    try std.testing.expectEqual(@as(f64, 0), navigation.duration());
    const mark: timing.EntryData = .{ .name = "mark", .entry_type = .mark, .start_time = 10 };
    try std.testing.expectEqual(@as(f64, 0), mark.duration());
}
