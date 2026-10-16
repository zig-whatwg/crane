const std = @import("std");
const fetch = @import("fetch");
const ResourceTiming = @import("dom").performance_timeline.ResourceTiming;

const UnchangedClock = struct {
    pub fn call(_: @This(), value: f64) f64 {
        return value;
    }
};

test "resource timing metrics outlive both their fetch and original entry data" {
    try copyMetrics(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, copyMetrics, .{});
}

fn copyMetrics(allocator: std.mem.Allocator) !void {
    var copy: ResourceTiming = undefined;
    {
        var info = fetch.internal.FetchTimingInfo.init(allocator);
        defer info.deinit();
        try info.addServerTimingHeader("db;dur=7;desc=\"cached\"");
        var original = try ResourceTiming.fromReport(allocator, &.{
            .timing_info = &info,
            .url = "https://a.test/resource",
            .initiator_type = .fetch,
            .cache_state = "",
            .body_info = .{},
            .response_status = 200,
        }, UnchangedClock{});
        defer original.deinit();
        copy = try original.clone(allocator);
    }
    defer copy.deinit();
    try std.testing.expectEqual(@as(usize, 1), copy.server_timing.len);
    try std.testing.expectEqualStrings("db", copy.server_timing[0].name);
    try std.testing.expectEqualStrings("cached", copy.server_timing[0].description);
    try std.testing.expectEqual(@as(f64, 7), copy.server_timing[0].duration);
}

test "full navigation timing without timing allow exposes no server metrics" {
    const allocator = std.testing.allocator;
    var info = fetch.internal.FetchTimingInfo.init(allocator);
    defer info.deinit();
    try info.addServerTimingHeader("secret;desc=private");
    var timing = try ResourceTiming.fromReport(allocator, &.{
        .timing_info = &info,
        .url = "https://b.test/navigation",
        .initiator_type = .iframe,
        .cache_state = "",
        .body_info = .{},
        .response_status = 200,
        .timing_allow_passed = false,
    }, UnchangedClock{});
    defer timing.deinit();
    try std.testing.expectEqual(@as(usize, 0), timing.server_timing.len);
}
