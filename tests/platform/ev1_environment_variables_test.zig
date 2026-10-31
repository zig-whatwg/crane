//! CSS environment values are supplied by the host, per Browser until the
//! platform recipes step 7 supplies document-to-TabId plumbing (row 121 Q3).
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

test "environment values: every defined headless scalar default is available" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    inline for (.{
        .safe_area_inset_top,     .safe_area_inset_right,     .safe_area_inset_bottom,     .safe_area_inset_left,
        .safe_area_max_inset_top, .safe_area_max_inset_right, .safe_area_max_inset_bottom, .safe_area_max_inset_left,
        .keyboard_inset_top,      .keyboard_inset_right,      .keyboard_inset_bottom,      .keyboard_inset_left,
        .keyboard_inset_width,    .keyboard_inset_height,
    }) |variable| {
        try testing.expectEqual(@as(?f64, 0), platform.cssEnvironmentVariable(browser, 1, variable, 0, 0));
        try testing.expectEqual(@as(?f64, 0), platform.cssEnvironmentVariable(browser, 2, variable, 0, 0));
    }
    try testing.expectEqual(@as(?f64, 1), platform.cssEnvironmentVariable(browser, 1, .preferred_text_scale, 0, 0));
    try testing.expectEqual(@as(u64, 0), platform.cssEnvironmentRevision(browser, 0));
}

test "environment values: titlebar and unsegmented viewport values are absent" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    inline for (.{ .titlebar_area_x, .titlebar_area_y, .titlebar_area_width, .titlebar_area_height }) |variable| {
        try testing.expectEqual(@as(?f64, null), platform.cssEnvironmentVariable(browser, 1, variable, 0, 0));
    }
    inline for (.{ .viewport_segment_width, .viewport_segment_height, .viewport_segment_top, .viewport_segment_right, .viewport_segment_bottom, .viewport_segment_left }) |variable| {
        for ([_][2]u32{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ std.math.maxInt(u32), std.math.maxInt(u32) } }) |indices| {
            try testing.expectEqual(@as(?f64, null), platform.cssEnvironmentVariable(browser, 1, variable, indices[0], indices[1]));
        }
    }
}

test "environment values: testing overrides isolate Browsers and advance their revision" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const other = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(other);

    try platform.adapter.setCssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0, 24.5);
    try testing.expectEqual(@as(?f64, 24.5), platform.cssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0));
    // Q3: platform recipes step 7 has no document -> TabId plumbing yet.
    // Every tab argument currently addresses the same Browser-owned values.
    try testing.expectEqual(@as(?f64, 24.5), platform.cssEnvironmentVariable(browser, 8, .safe_area_inset_top, 0, 0));
    try testing.expectEqual(@as(?f64, 0), platform.cssEnvironmentVariable(other, 7, .safe_area_inset_top, 0, 0));
    try testing.expectEqual(@as(u64, 1), platform.cssEnvironmentRevision(browser, 0));
    try testing.expectEqual(@as(u64, 0), platform.cssEnvironmentRevision(other, 0));

    try platform.adapter.setCssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0, 24.5);
    try testing.expectEqual(@as(u64, 1), platform.cssEnvironmentRevision(browser, 0));
    try platform.adapter.setCssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0, null);
    try testing.expectEqual(@as(?f64, null), platform.cssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0));
    try testing.expectEqual(@as(u64, 2), platform.cssEnvironmentRevision(browser, 0));
    try platform.adapter.setCssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0, 0);
    try testing.expectEqual(@as(?f64, 0), platform.cssEnvironmentVariable(browser, 7, .safe_area_inset_top, 0, 0));
    try testing.expectEqual(@as(u64, 3), platform.cssEnvironmentRevision(browser, 0));
}

test "environment values: all supplied values reach only their named variable" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    inline for (@typeInfo(platform.CssEnvironmentVariable).@"enum".field_values, 0..) |field_value, index| {
        const variable: platform.CssEnvironmentVariable = @fromBackingInt(@intCast(field_value));
        const value: f64 = @as(f64, @floatFromInt(index)) + 0.25;
        try platform.adapter.setCssEnvironmentVariable(browser, 4, variable, 0, 0, value);
    }
    inline for (@typeInfo(platform.CssEnvironmentVariable).@"enum".field_values, 0..) |field_value, index| {
        const variable: platform.CssEnvironmentVariable = @fromBackingInt(@intCast(field_value));
        const value: f64 = @as(f64, @floatFromInt(index)) + 0.25;
        try testing.expectEqual(@as(?f64, value), platform.cssEnvironmentVariable(browser, 4, variable, 0, 0));
    }
}

test "environment values: segment coordinates are ordered keys with no dense allocation" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    // Two unequal side-by-side segments, with a 20px hinge.
    const variables = [_]platform.CssEnvironmentVariable{ .viewport_segment_width, .viewport_segment_height, .viewport_segment_top, .viewport_segment_left, .viewport_segment_bottom, .viewport_segment_right };
    const left = [_]f64{ 300, 600, 0, 0, 600, 300 };
    const right = [_]f64{ 400, 600, 0, 320, 600, 720 };
    for (variables, left, right) |variable, a, b| {
        try platform.adapter.setCssEnvironmentVariable(browser, 1, variable, 0, 0, a);
        try platform.adapter.setCssEnvironmentVariable(browser, 1, variable, 1, 0, b);
        try testing.expectEqual(@as(?f64, a), platform.cssEnvironmentVariable(browser, 1, variable, 0, 0));
        try testing.expectEqual(@as(?f64, b), platform.cssEnvironmentVariable(browser, 1, variable, 1, 0));
        try testing.expectEqual(@as(?f64, null), platform.cssEnvironmentVariable(browser, 1, variable, 0, 1));
        try testing.expectEqual(@as(?f64, b), platform.cssEnvironmentVariable(browser, 2, variable, 1, 0));
    }
    try platform.adapter.setCssEnvironmentVariable(browser, 1, .viewport_segment_width, std.math.maxInt(u32), 0, 1);
    try testing.expectEqual(@as(?f64, 1), platform.cssEnvironmentVariable(browser, 1, .viewport_segment_width, std.math.maxInt(u32), 0));
    try testing.expectEqual(@as(?f64, null), platform.cssEnvironmentVariable(browser, 1, .viewport_segment_width, 0, std.math.maxInt(u32)));
}

test "environment values: allocation failures leave the old value and revision unchanged" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) !void {
    const browser = try platform.createBrowserPlatform(allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    platform.adapter.setCssEnvironmentVariable(browser, 1, .safe_area_inset_top, 0, 0, 8) catch |err| {
        try testing.expectEqual(@as(?f64, 0), platform.cssEnvironmentVariable(browser, 1, .safe_area_inset_top, 0, 0));
        try testing.expectEqual(@as(u64, 0), platform.cssEnvironmentRevision(browser, 0));
        return err;
    };
    try testing.expectEqual(@as(?f64, 8), platform.cssEnvironmentVariable(browser, 1, .safe_area_inset_top, 0, 0));
    try testing.expectEqual(@as(u64, 1), platform.cssEnvironmentRevision(browser, 0));
}
