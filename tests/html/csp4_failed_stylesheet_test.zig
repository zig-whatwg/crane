//! A stylesheet that receives an HTTP error still has an empty CSSOM sheet
//! in browsers. A fetch blocked by CSP has no sheet. Keep those cases
//! separate from a successful response, whose CSS rules must be parsed.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/allowed.css", .content_type = "text/css", .body = "body { color: blue }" },
    .{ .path = "/failed.css", .fail_first = std.math.maxInt(u32) },
    .{ .path = "/blocked.css", .content_type = "text/css", .body = "body { color: red }" },
    .{ .path = "/integrity.css", .content_type = "text/css", .body = "body { color: green }" },
    .{ .path = "/network.css", .content_type = "text/css", .body = "body { color: purple }" },
};

const Case = enum { allowed, http_error, csp_blocked, integrity_failure, network_error };

fn run(case: Case) !void {
    const allocator = std.testing.allocator;
    const server = try http.Server.start(allocator, &routes);
    defer server.stop();
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    const page_url = "http://cs4.test/page.html";
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    const policy = switch (case) {
        .csp_blocked => "'none'",
        .network_error => "http://cs4.test:*",
        else => "'self'",
    };
    var html_buf: [256]u8 = undefined;
    const html = try std.fmt.bufPrint(
        &html_buf,
        "<!doctype html><meta http-equiv=Content-Security-Policy content=\"style-src {s}\"><body>",
        .{policy},
    );
    try page.loadHTML(html, .{ .base_url = page_url });
    const path = switch (case) {
        .allowed => "/allowed.css",
        .http_error => "/failed.css",
        .csp_blocked => "/blocked.css",
        .integrity_failure => "/integrity.css",
        .network_error => "/network.css",
    };
    // Fetch's bad-port check produces a network error before contacting the
    // server. CSP allows this URL, so the two rejection paths stay distinct.
    const href = if (case == .network_error) "http://cs4.test:9/network.css" else path;
    const integrity = if (case == .integrity_failure)
        "link.integrity = 'sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';"
    else
        "";
    var script_buf: [1024]u8 = undefined;
    const script = try std.fmt.bufPrint(&script_buf,
        \\globalThis.answer = 'pending';
        \\const link = document.createElement('link');
        \\link.rel = 'stylesheet';
        \\link.href = '{s}';
        \\{s}
        \\const finish = event => {{
        \\  const sheet = link.sheet;
        \\  answer = [event.type, sheet !== null,
        \\    sheet ? sheet.cssRules.length : 'none',
        \\    Array.from(document.styleSheets).includes(sheet)].join('|');
        \\}};
        \\link.onload = finish;
        \\link.onerror = finish;
        \\document.head.appendChild(link);
        \\'ok'
    , .{ href, integrity });
    const started = try page.evaluateScriptToString(script, allocator);
    defer allocator.free(started);
    try std.testing.expectEqualStrings("ok", started);
    const expected = switch (case) {
        .allowed => "load|true|1|true",
        .http_error => "error|true|0|true",
        .csp_blocked, .integrity_failure, .network_error => "error|false|none|false",
    };
    for (0..500) |_| {
        const answer = try page.evaluateScriptToString("answer", allocator);
        defer allocator.free(answer);
        if (!std.mem.eql(u8, answer, "pending")) {
            try std.testing.expectEqualStrings(expected, answer);
            const expected_requests: u32 = switch (case) {
                .csp_blocked, .network_error => 0,
                else => 1,
            };
            try std.testing.expectEqual(expected_requests, server.count(path));
            return;
        }
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn onFreshThread(case: Case) !void {
    const Run = struct {
        case: Case,
        failure: ?anyerror = null,

        fn go(self: *@This()) void {
            run(self.case) catch |err| {
                self.failure = err;
            };
        }
    };
    var state: Run = .{ .case = case };
    const thread = try std.Thread.spawn(.{}, Run.go, .{&state});
    thread.join();
    if (state.failure) |err| return err;
}

test "CSP allows a successful stylesheet and its parsed CSSOM rules" {
    try onFreshThread(.allowed);
}

test "CSP allows an HTTP error response to retain an empty CSSOM sheet" {
    try onFreshThread(.http_error);
}

test "a CSP-blocked stylesheet creates no sheet and sends no request" {
    try onFreshThread(.csp_blocked);
}

test "an integrity-failed stylesheet creates no sheet" {
    try onFreshThread(.integrity_failure);
}

test "a stylesheet network error creates no sheet and sends no request" {
    try onFreshThread(.network_error);
}
