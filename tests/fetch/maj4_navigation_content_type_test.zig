//! A frame's navigation reports its resource timing to its container's
//! global without response details when it went to another origin or came
//! back through one: no status and no content encoding (lp1's test) - and no
//! content type either (resource-timing/content-type.html "content-type
//! should be empty for iframes having cross origin redirects", "... not be
//! exposed for iframes with any non-same-origin redirect" and the
//! cross-origin iframe case: Chrome 157 and Firefox 160 pass at wpt.fyi
//! 2358bd4835, Safari 27.2 does not - golden rule 2, the majority; Chromium
//! CreateResourceTimingInfo sets content_type only with
//! allow_response_details). A same-origin one keeps its content type.
const std = @import("std");
const fetch = @import("fetch");

const Report = struct {
    count: usize = 0,
    content_type: [32]u8 = undefined,
    content_type_len: usize = 0,

    fn receive(context: *anyopaque, timing: *const fetch.internal.TimingReport) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.count += 1;
        const value = timing.body_info.content_type;
        self.content_type_len = @min(value.len, self.content_type.len);
        @memcpy(self.content_type[0..self.content_type_len], value[0..self.content_type_len]);
    }

    fn reported(self: *const @This()) []const u8 {
        return self.content_type[0..self.content_type_len];
    }
};

fn answer(status: u16, location: ?[]const u8, content_type: ?[]const u8) !fetch.network.NetworkResponse {
    const allocator = std.testing.allocator;
    var headers: std.ArrayList(fetch.network.NetworkResponse.Header) = .empty;
    errdefer {
        for (headers.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        headers.deinit(allocator);
    }
    if (location) |url| try addHeader(&headers, "Location", url);
    if (content_type) |value| try addHeader(&headers, "Content-Type", value);
    return .{
        .allocator = allocator,
        .status = status,
        .http_version = .http_1_1,
        .headers = try headers.toOwnedSlice(allocator),
        .body = null,
        .final_url = null,
        .total_time_ms = 0,
        .time_to_first_byte_ms = 0,
        .redirect_count = 0,
        .remote_ip = null,
        .remote_port = null,
    };
}

fn addHeader(headers: *std.ArrayList(fetch.network.NetworkResponse.Header), name: []const u8, value: []const u8) !void {
    const allocator = std.testing.allocator;
    const name_copy = try allocator.dupe(u8, name);
    errdefer allocator.free(name_copy);
    const value_copy = try allocator.dupe(u8, value);
    errdefer allocator.free(value_copy);
    try headers.append(allocator, .{ .name = name_copy, .value = value_copy });
}

/// The content type a frame navigation through `urls` (the first is the
/// request's, each later one a 302 hop) reports to its container, its final
/// response `text/html; charset=utf-8`.
fn reportedContentType(urls: []const []const u8, report: *Report) !void {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, urls[0]);
    defer request.deinit();
    try request.setOrigin("http://a.test");
    request.mode = .navigate;
    request.destination = .iframe;
    request.redirect_mode = .follow;
    request.initiator_type = .iframe;
    request.timing_reporter = .{ .context = report, .report = &Report.receive };
    const job = try fetch.algorithms.FetchJob.create(allocator, request, false, .{});
    defer job.destroy();
    try std.testing.expect(try job.start() == .network);
    for (urls[1..]) |url| {
        try std.testing.expect(try job.resumeNetwork(try answer(302, url, null)) == .network);
    }
    try std.testing.expect(try job.resumeNetwork(try answer(200, null, "text/html; charset=utf-8")) == .done);
    var result = job.takeResult();
    result.deinit();
    try std.testing.expectEqual(@as(usize, 1), report.count);
}

test "a frame navigation that came back through a cross-origin redirect reports no content type to its container" {
    var report: Report = .{};
    try reportedContentType(&.{ "http://a.test/first", "http://b.test/second", "http://a.test/final" }, &report);
    try std.testing.expectEqualStrings("", report.reported());
}

test "a frame navigation to another origin reports no content type to its container" {
    var report: Report = .{};
    try reportedContentType(&.{"http://b.test/final"}, &report);
    try std.testing.expectEqualStrings("", report.reported());
}

test "a frame navigation through same-origin redirects reports its content type to its container" {
    var report: Report = .{};
    try reportedContentType(&.{ "http://a.test/first", "http://a.test/final" }, &report);
    try std.testing.expectEqualStrings("text/html", report.reported());
}
