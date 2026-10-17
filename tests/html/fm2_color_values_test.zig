//! HTML's color-well destination and alpha are independent of CSS parsing.
const std = @import("std");
const colors = @import("html").forms.color_values;
const testing = std.testing;

test "color wells serialize alpha and extended Display P3 values" {
    const cases = [_]struct { input: []const u8, settings: colors.Settings, expected: []const u8 }{
        .{ .input = "transparent", .settings = .{ .alpha = true }, .expected = "color(srgb 0 0 0 / 0)" },
        .{ .input = "#ffffff08", .settings = .{ .alpha = true }, .expected = "color(srgb 1 1 1 / 0.031373)" },
        .{ .input = "rgba(1,1,1,.5)", .settings = .{ .alpha = true }, .expected = "color(srgb 0.003922 0.003922 0.003922 / 0.501961)" },
        .{ .input = "white", .settings = .{ .space = .display_p3 }, .expected = "color(display-p3 1 1 1)" },
        .{ .input = "color(display-p3 3 none .2 / .6)", .settings = .{ .space = .display_p3, .alpha = true }, .expected = "color(display-p3 3 0 0.2 / 0.6)" },
        .{ .input = "invalid", .settings = .{ .space = .display_p3, .alpha = true }, .expected = "color(display-p3 0 0 0)" },
        .{ .input = "color(display-p3 1 0 0 / .2)", .settings = .{}, .expected = "#ff0000" },
    };
    for (cases) |case| {
        var value = try colors.sanitize(testing.allocator, case.input, case.settings);
        defer value.deinit(testing.allocator);
        try testing.expectEqualStrings(case.expected, value.asSlice());
    }
}

test "already serialized color values are borrowed without allocation" {
    const cases = [_]struct { input: []const u8, settings: colors.Settings }{
        .{ .input = "#123456", .settings = .{} },
        .{ .input = "#abcdef", .settings = .{} },
        .{ .input = "color(srgb 0.003922 0.003922 0.003922 / 0.501961)", .settings = .{ .alpha = true } },
        .{ .input = "color(display-p3 3 -0.2 0.2 / 0.6)", .settings = .{ .space = .display_p3, .alpha = true } },
    };
    for (cases) |case| {
        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
        var value = try colors.sanitize(failing.allocator(), case.input, case.settings);
        defer value.deinit(failing.allocator());
        try testing.expectEqualStrings(case.input, value.asSlice());
        try testing.expectEqual(case.input.ptr, value.asSlice().ptr);
    }
}

test "color syntax that looks serialized still applies destination rounding" {
    var value = try colors.sanitize(testing.allocator, "color(srgb 0.5 0 0 / 0.5)", .{ .alpha = true });
    defer value.deinit(testing.allocator);
    try testing.expectEqualStrings("color(srgb 0.501961 0 0 / 0.501961)", value.asSlice());
}
