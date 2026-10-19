//! Static module requests preserve their creator's referrer-policy default
//! without sharing a settings object between Browser or worker threads.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("module1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/worker.js", .body = "import referrer from './referrer.js'; postMessage(referrer);" },
    .{ .path = "/referrer.js", .echo_referrer = true, .delay_ms = 50 },
};

fn runBrowser(allocator: std.mem.Allocator, server: *http.Server, policy: []const u8, expected: []const u8) !void {
    var proxy_buffer: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buffer);
    const browser = try Browser.init(allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    defer browser.deinit();
    try browser.navigateWithOptions("http://wf1.test/page.html", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    const markup = try std.fmt.allocPrint(allocator, "<!doctype html><meta name=referrer content='{s}'><body>", .{policy});
    defer allocator.free(markup);
    try page.loadHTML(markup, .{ .base_url = "http://wf1.test/page.html" });
    const start = try page.evaluateScriptToString(
        \\globalThis.answer = 'pending';
        \\globalThis.worker = new Worker('/worker.js', {type: 'module'});
        \\worker.onmessage = e => { answer = e.data; worker.terminate(); };
        \\worker.onerror = () => { answer = 'worker-error'; };
        \\'started'
    , allocator);
    allocator.free(start);
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const answer = try page.evaluateScriptToString("answer", allocator);
        defer allocator.free(answer);
        if (std.mem.eql(u8, answer, "pending")) continue;
        try std.testing.expectEqualStrings(expected, answer);
        return;
    }
    return error.TimedOut;
}

const Run = struct {
    server: *http.Server,
    failure: ?anyerror = null,
    policy: []const u8,
    expected: []const u8,

    fn onThread(self: *Run) void {
        // Per-Browser allocators let both Browser threads run concurrently.
        // Each is leak-checking; sharing std.testing.allocator serializes
        // allocations enough to conceal cross-Browser routing bugs.
        var gpa: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (gpa.deinit() == .leak) {
            self.failure = error.BrowserLeaked;
        };
        runBrowser(gpa.allocator(), self.server, self.policy, self.expected) catch |err| {
            self.failure = err;
        };
    }
};

test "two Browsers start module workers using each outside referrer policy" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var first: Run = .{ .server = server, .policy = "no-referrer", .expected = "" };
    var second: Run = .{ .server = server, .policy = "origin", .expected = "http://wf1.test/" };
    const a = try std.Thread.spawn(.{}, Run.onThread, .{&first});
    const b = std.Thread.spawn(.{}, Run.onThread, .{&second}) catch |err| {
        a.join();
        return err;
    };
    a.join();
    b.join();
    if (first.failure) |err| return err;
    if (second.failure) |err| return err;
    try std.testing.expectEqual(@as(u32, 2), server.count("/referrer.js"));
}
