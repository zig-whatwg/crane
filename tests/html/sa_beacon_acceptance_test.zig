//! Beacon's immediate acceptance follows browser policy checks before dispatch.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const fetch = @import("fetch");
const testing = std.testing;

const Reports = struct {
    count: usize = 0,
    url: [256]u8 = undefined,
    length: usize = 0,

    fn report(context: *anyopaque, violation: *const fetch.internal.CspViolation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        self.count += 1;
        const url = violation.resource.keyword();
        self.length = @min(url.len, self.url.len);
        @memcpy(self.url[0..self.length], url[0..self.length]);
    }
};

const Trial = struct {
    policy: []const u8,
    report_only: ?[]const u8 = null,
    reports: usize = 0,
    load: dom.keepalive_fetch.Load = .fetch,
    accepted: bool,
    dispatched: bool,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.NoPage;
        const html = try std.fmt.allocPrint(testing.allocator, "<!doctype html><meta http-equiv=Content-Security-Policy content=\"{s}\"><body>", .{self.policy});
        defer testing.allocator.free(html);
        try page.loadHTML(html, .{ .base_url = "https://secure.example.test/start" });
        const global = page.window_instance orelse return error.NoWindow;
        const allocator = global.ctx.allocator;
        const request = try fetch.internal.InternalRequest.init(allocator, "http://192.0.2.1:65533/beacon");
        var owned = true;
        defer if (owned) request.deinit();
        try request.setMethod("POST");
        request.keepalive = true;
        request.initiator_type = .beacon;
        const body = try fetch.internal.Body.fromBytes(allocator, "body");
        body.source = .{ .bytes = body.data.items };
        request.body = .{ .body = body };
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
        if (self.report_only) |policy| request.setPolicyContainer(try fetch.internal.PolicyContainer.fromResponseHeaders(allocator, .{
            .url = "https://secure.example.test/start",
            .csp = self.policy,
            .csp_report_only = policy,
        }));
        var reports: Reports = .{};
        request.csp_violation_reporter = .{ .context = &reports, .report = Reports.report };
        try testing.expect(request.prohibits_mixed_security_contexts);
        const group = dom.global_settings.fetchGroupOf(global) orelse return error.NoFetchGroup;
        const before = fetch.algorithms.async_fetch.inFlight();
        owned = false; // send takes the request even when it rejects.
        try testing.expectEqual(self.accepted, try dom.keepalive_fetch.send(global, request, .{ .load = self.load }));
        try testing.expectEqual(before + @as(usize, @intFromBool(self.dispatched)), fetch.algorithms.async_fetch.inFlight());
        try testing.expectEqual(@as(u64, if (self.dispatched and self.load == .fetch) 4 else 0), group.inflight_keepalive_bytes);
        try testing.expectEqual(self.reports, reports.count);
        if (self.reports != 0) try testing.expectEqualStrings("http://192.0.2.1:65533/beacon", reports.url[0..reports.length]);
        // Browser teardown terminates accepted requests. This test observes
        // synchronous acceptance and does not wait for a network response.
    }
};

fn check(trial: Trial) !void {
    var state = trial;
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&state});
    thread.join();
    try state.result;
}

test "Beacon mixed-content rejection returns false without dispatch or quota" {
    try check(.{ .policy = "", .accepted = false, .dispatched = false });
}

test "Beacon UIR upgrade precedes mixed-content rejection" {
    try check(.{ .policy = "upgrade-insecure-requests", .accepted = true, .dispatched = true });
}

test "Beacon CSP rejection returns true without dispatch or quota" {
    try check(.{ .policy = "connect-src 'none'", .reports = 1, .accepted = true, .dispatched = false });
}

test "Beacon mixed-content rejection delivers report-only CSP once" {
    try check(.{ .policy = "", .report_only = "connect-src https:", .reports = 1, .accepted = false, .dispatched = false });
}

test "Ping loads retain their asynchronous mixed-content behavior" {
    try check(.{ .policy = "", .load = .ping, .accepted = true, .dispatched = true });
}
