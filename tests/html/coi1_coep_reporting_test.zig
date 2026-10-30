//! Lane coi1: Fetch 3.7's CORP violation reports reach the request client's
//! Reporting queue as "coep" reports (dom.coep_reporting), with stripped URLs
//! and both dispositions; a reporter whose client's realm has ended reports
//! nothing and touches nothing.

const std = @import("std");
const Browser = @import("browser").Browser;
const dom = @import("dom");

fn reportsReachTheQueue() !void {
    const a = std.testing.allocator;
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    const url = "https://user:password@coep.test/page?query=yes#document-fragment";
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = url });
    const window = page.window_instance orelse return error.NoWindow;
    var client = try dom.global_settings.requestClient(window);
    defer client.deinit();
    const reporter = client.request.coep_violation_reporter orelse return error.NoReporter;
    const state = dom.global_settings.reportingOf(window) orelse return error.NoReporting;
    const before = state.pending.items.len;
    for ([_]bool{ false, true }) |report_only| reporter.report(reporter.context, &.{
        .blocked_url = "https://other:secret@cross.test/path?q=yes#blocked-fragment",
        .destination = .image,
        .report_only = report_only,
        .endpoint = if (report_only) "ro" else "main",
    });
    try std.testing.expectEqual(before + 2, state.pending.items.len);
    for (state.pending.items[before..], 0..) |record, index| {
        try std.testing.expectEqualStrings("coep", record.type);
        try std.testing.expectEqualStrings(if (index == 0) "main" else "ro", record.destination);
        try std.testing.expectEqualStrings("https://coep.test/page?query=yes", record.url);
        const parsed = try std.json.parseFromSlice(std.json.Value, a, record.body_json, .{});
        defer parsed.deinit();
        const body = parsed.value.object;
        try std.testing.expectEqualStrings("corp", body.get("type").?.string);
        try std.testing.expectEqualStrings("https://cross.test/path?q=yes", body.get("blockedURL").?.string);
        try std.testing.expectEqualStrings("image", body.get("destination").?.string);
        try std.testing.expectEqualStrings(if (index == 0) "enforce" else "reporting", body.get("disposition").?.string);
    }
}

test "coep CORP reports strip URLs and carry both dispositions" {
    try onThread(reportsReachTheQueue);
}

fn endedRealmReportsNothing() !void {
    const a = std.testing.allocator;
    const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("https://first.test/", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>first</title>", .{ .base_url = "https://first.test/one" });
    try page.loadHTML("<!doctype html><title>second</title>", .{ .base_url = "https://first.test/two" });
    const first_window = page.window_instance orelse return error.NoWindow;
    var client = try dom.global_settings.requestClient(first_window);
    defer client.deinit();
    const reporter = client.request.coep_violation_reporter orelse return error.NoReporter;
    // Another origin: the page's next document gets a new realm, and the
    // first one's ends.
    try page.loadHTML("<!doctype html><title>third</title>", .{ .base_url = "https://second.test/" });
    for (0..3) |_| {
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
    const window = page.window_instance orelse return error.NoWindow;
    const state = dom.global_settings.reportingOf(window) orelse return error.NoReporting;
    const before = state.pending.items.len;
    reporter.report(reporter.context, &.{
        .blocked_url = "https://cross.test/x",
        .destination = .script,
        .report_only = false,
        .endpoint = "",
    });
    try std.testing.expectEqual(before, state.pending.items.len);
}

test "a CORP reporter whose client's realm has ended reports nothing" {
    try onThread(endedRealmReportsNothing);
}

fn onThread(comptime body: fn () anyerror!void) !void {
    const Trial = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&result});
    thread.join();
    try result;
}
