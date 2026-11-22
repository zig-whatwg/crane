//! The HTTP cache persists in a Browser's profile directory (the user's
//! ruling D6, 2026-11-21; lane prof1, D6 step 5), as Chrome's disk cache
//! keeps a profile's: a fresh response one Browser on the directory stored
//! answers the next Browser's fetch with no request to the server; a stale
//! one it stored is revalidated (a 304) rather than fetched whole; and a
//! Browser with no profile directory starts with an empty cache, as before.
//! Writes still queued when the first Browser ends are flushed then.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("hc1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/fresh.txt", .body = "fresh" },
    .{ .path = "/stale.txt", .body = "stale", .cache_control = "max-age=0", .etag = "\"s1\"" },
};

const page_url = "http://prof1.test/page.html";

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

fn runInPage(browser: *Browser, comptime body: []const u8) ![]u8 {
    const launch = "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + e; }); 'ok'";
    browser.allocator.free(try evaluate(browser, launch));
    for (0..1000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn startBrowser(allocator: std.mem.Allocator, server: *http.Server, profile: ?[]const u8) !*Browser {
    var proxy_buf: [64]u8 = undefined;
    const proxy = try server.proxyUrl(&proxy_buf);
    const browser = try Browser.init(allocator, .{
        .snapshot_path = "",
        .profile_dir = profile,
        .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
    });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    return browser;
}

const fetch_both =
    \\const a = await (await fetch('/fresh.txt')).text();
    \\const b = await (await fetch('/stale.txt')).text();
    \\return a + ',' + b;
;

const Run = struct {
    server: *http.Server,
    profile: ?[]const u8,
    failure: ?anyerror = null,
    answer: [32]u8 = undefined,
    answer_len: usize = 0,

    fn main(self: *Run) void {
        self.run() catch |err| {
            self.failure = err;
        };
    }

    fn run(self: *Run) !void {
        var debug: @import("root").poisoning.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug.deinit() != .ok) {
            self.failure = error.Leaked;
        };
        const browser = try startBrowser(debug.allocator(), self.server, self.profile);
        defer browser.deinit();
        const got = try runInPage(browser, fetch_both);
        defer browser.allocator.free(got);
        @memcpy(self.answer[0..got.len], got);
        self.answer_len = got.len;
    }

    /// One Browser, start to end, on a thread of its own.
    fn once(server: *http.Server, profile: ?[]const u8) ![]const u8 {
        var run: Run = .{ .server = server, .profile = profile };
        const thread = try std.Thread.spawn(.{}, main, .{&run});
        thread.join();
        if (run.failure) |err| return err;
        try std.testing.expectEqualStrings("fresh,stale", run.answer[0..run.answer_len]);
        return "fresh,stale";
    }
};

test "a response the HTTP cache stored in one Browser on a profile directory answers the next Browser on it" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(base);
    const profile = try std.fs.path.join(std.testing.allocator, &.{ base, "profile" });
    defer std.testing.allocator.free(profile);

    _ = try Run.once(server, profile);
    try std.testing.expectEqual(@as(u32, 1), server.count("/fresh.txt"));
    try std.testing.expectEqual(@as(u32, 1), server.count("/stale.txt"));
    _ = try Run.once(server, profile);
    // The fresh one: from the profile's cache, no request.
    try std.testing.expectEqual(@as(u32, 1), server.count("/fresh.txt"));
    // The stale one: revalidated against what was stored - a 304.
    try std.testing.expectEqual(@as(u32, 2), server.count("/stale.txt"));
    try std.testing.expectEqual(@as(u32, 1), server.notModified("/stale.txt"));
}

test "a Browser with no profile directory starts with an empty HTTP cache, as before" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    _ = try Run.once(server, null);
    _ = try Run.once(server, null);
    try std.testing.expectEqual(@as(u32, 2), server.count("/fresh.txt"));
    try std.testing.expectEqual(@as(u32, 0), server.notModified("/stale.txt"));
}
