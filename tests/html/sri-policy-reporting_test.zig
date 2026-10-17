//! Integrity violation reports snapshot stripped URLs in the existing queue.
const std = @import("std");
const Browser = @import("browser").Browser;
const dom = @import("dom");

fn exercise() !void {
    if (comptime @hasDecl(dom, "sri_reporting")) {
        const a = std.testing.allocator;
        const browser = try Browser.init(a, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        const url = "https://user:password@sri.test/page?query=yes#document-fragment";
        try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = url });
        const window = page.window_instance orelse return error.NoWindow;
        var client = try dom.global_settings.requestClient(window);
        defer client.deinit();
        const reporter = client.request.integrity_violation_reporter orelse return error.NoReporter;
        const state = dom.global_settings.reportingOf(window) orelse return error.NoReporting;
        const before = state.pending.items.len;
        for ([_]bool{ false, true }) |report_only| reporter.report(reporter.context, &.{
            .blocked_url = "https://other:secret@cross.test/path?q=yes#blocked-fragment",
            .destination = .script,
            .report_only = report_only,
            .endpoints = &.{ "one", "two" },
        });
        try std.testing.expectEqual(before + 4, state.pending.items.len);
        for (state.pending.items[before..], 0..) |record, index| {
            try std.testing.expectEqualStrings("integrity-violation", record.type);
            try std.testing.expectEqualStrings(if (index % 2 == 0) "one" else "two", record.destination);
            try std.testing.expectEqualStrings("https://sri.test/page?query=yes", record.url);
            const parsed = try std.json.parseFromSlice(std.json.Value, a, record.body_json, .{});
            defer parsed.deinit();
            const body = parsed.value.object;
            try std.testing.expectEqualStrings("https://sri.test/page?query=yes", body.get("documentURL").?.string);
            try std.testing.expectEqualStrings("https://cross.test/path?q=yes", body.get("blockedURL").?.string);
            try std.testing.expectEqualStrings("script", body.get("destination").?.string);
            try std.testing.expectEqual(index >= 2, body.get("reportOnly").?.bool);
        }
    } else return error.TestUnexpectedResult;
}

test "sri policy reports strip credentials and fragments and preserve report-only disposition" {
    const Trial = struct {
        fn run(result: *anyerror!void) void {
            result.* = exercise();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&result});
    thread.join();
    try result;
}
