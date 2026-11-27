//! Lane net-nav1 (Items 2 & 4):
//! - Item 2: navigationRequest and workerScriptRequest set
//!   `traversable_for_user_prompts` cleanly (HTML "create navigation params
//!   by fetching" step 3; Fetch "request's traversable for user prompts").
//! - Item 4: Removed iframe's history steps (Golden Rule 2: HTML #6315 +
//!   Firefox 158+ drop the removed iframe's entries, shrinking history.length
//!   and skipping its step on history.back(); JointHistory.navigationEntries
//!   keeps its current index on the preceding used step right after
//!   removeNavigable).

const std = @import("std");
const testing = std.testing;
const html = @import("html");
const html_core = @import("html_core");
const fetch = @import("fetch");
const browser_mod = @import("browser");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const JointHistory = html_core.navigation.joint_history.JointHistory;
const NavigationEntry = html_core.navigation.joint_history.NavigationEntry;
const nav_fetch = html_core.navigation.fetch_integration;
const script_fetch = html_core.workers.script_fetch;

test "Item 2: navigationRequest sets traversable_for_user_prompts and use_url_credentials" {
    const allocator = testing.allocator;
    const req = try nav_fetch.navigationRequest(allocator, "http://example.test/page", .{});
    defer req.deinit();
    try testing.expect(req.traversable_for_user_prompts == .traversable);
    try testing.expect(req.use_url_credentials);
}

test "Item 2: workerScriptRequest resolves traversable_for_user_prompts from creator kind" {
    const allocator = testing.allocator;

    // Window creator: user_agent_override.has_traversable = true -> .traversable
    const win_req = try script_fetch.workerScriptRequest(allocator, "http://example.test/w.js", .{
        .user_agent_override = .{ .has_traversable = true },
    });
    defer win_req.deinit();
    try testing.expect(win_req.traversable_for_user_prompts == .traversable);
    try testing.expect(win_req.use_url_credentials);

    // Worker creator (nested worker) or clientless: .no_traversable (never left .client)
    const nested_req = try script_fetch.workerScriptRequest(allocator, "http://example.test/nested.js", .{
        .user_agent_override = .{ .has_traversable = false },
    });
    defer nested_req.deinit();
    try testing.expect(nested_req.traversable_for_user_prompts == .no_traversable);
}

test "Item 4: JointHistory.navigationEntries keeps current index on preceding step right after removeNavigable" {
    const allocator = testing.allocator;
    var h = JointHistory.init(allocator);
    defer h.deinit();

    const top: u64 = 1;
    const frame: u64 = 2;

    // Step 0: top at /a
    try h.addInitialEntry(top, "http://a.test/a", null, "http://a.test");

    // Step 1: top pushes /b
    try h.commitDocument(top, "http://a.test/b", null, "http://a.test", .push);

    // Frame attaches at step 1, then pushes /c at step 2
    try h.addChildInitialEntry(frame, top, "http://a.test/frame-init", null, "http://a.test");
    try h.commitDocument(frame, "http://a.test/c", null, "http://a.test", .push);

    try testing.expectEqual(@as(usize, 3), h.lengthAndIndex().length);
    try testing.expectEqual(@as(usize, 2), h.lengthAndIndex().index);

    // Remove iframe while current_step is still 2 (before queued update runs).
    h.removeNavigable(frame);

    try testing.expectEqual(@as(usize, 2), h.lengthAndIndex().length);
    try testing.expectEqual(@as(usize, 1), h.lengthAndIndex().index);
    try testing.expectEqual(@as(?u32, 0), h.stepByDelta(-1));

    // navigationEntries must report current index 1 (/b), NOT 0 (/a).
    var entries: std.ArrayList(NavigationEntry) = .empty;
    defer entries.deinit(allocator);
    const current = try h.navigationEntries(allocator, &entries);
    try testing.expectEqual(@as(usize, 2), entries.items.len);
    try testing.expectEqual(@as(usize, 1), current);
    try testing.expectEqualStrings("http://a.test/b", entries.items[current].url);
}

const HistorySite = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    fn start(allocator: std.mem.Allocator) !*HistorySite {
        const self = try allocator.create(HistorySite);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, acceptLoop, .{self});
        return self;
    }

    fn stop(self: *HistorySite) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn url(self: *const HistorySite, buf: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    fn acceptLoop(self: *HistorySite) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const t = std.Thread.spawn(.{}, serve, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            t.detach();
        }
    }

    fn serve(self: *HistorySite, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        var in_buf: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &in_buf);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) {
            reader.interface.fillMore() catch return;
        }
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return;
        const path = parts.next() orelse return;

        const body: []const u8 = if (std.mem.eql(u8, path, "/a"))
            "<!doctype html><title>A</title>"
        else if (std.mem.eql(u8, path, "/b"))
            "<!doctype html><title>B</title><iframe id=f src='/f1'></iframe>"
        else if (std.mem.eql(u8, path, "/f1"))
            "<!doctype html><title>F1</title>"
        else
            "<!doctype html><title>F2</title>";

        var out_buf: [1024]u8 = undefined;
        var writer = stream.writer(std.testing.io, &out_buf);
        writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body }) catch return;
        writer.interface.flush() catch return;
    }
};

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, expr: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const value = try page.evaluateScriptToString(expr, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

test "Item 4: Browser history.length shrinks and history.back() skips removed navigated iframe" {
    const site = try HistorySite.start(testing.allocator);
    defer site.stop();

    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();

    var url_a: [96]u8 = undefined;
    const a = try site.url(&url_a, "/a");

    try browser.navigate(a, .window);
    var page = browser.current_context orelse return error.NoContext;
    try runUntil(browser, page, "document.title === 'A'");

    // Navigate top-level to /b via location.href so it pushes step 1 on top of /a.
    const go_b = try page.evaluateScriptToString("location.href = '/b'; 'ok'", testing.allocator);
    testing.allocator.free(go_b);
    var waited_b: usize = 0;
    while (waited_b < 5_000) : (waited_b += 10) {
        page = browser.current_context orelse return error.NoContext;
        const ok_b = try page.evaluateScriptToString("String(document.title === 'B' && frames[0] && frames[0].document.title === 'F1')", testing.allocator);
        defer testing.allocator.free(ok_b);
        if (std.mem.eql(u8, ok_b, "true")) break;
        _ = try browser.runEventLoopBlocking(10);
    }
    try runUntil(browser, page, "document.title === 'B' && frames[0] && frames[0].document.title === 'F1' && history.length === 2");

    // Navigate the iframe to /f2 (pushes joint history step 2).
    const nav_f2 = try page.evaluateScriptToString("frames[0].location.href = '/f2'; 'ok'", testing.allocator);
    testing.allocator.free(nav_f2);
    try runUntil(browser, page, "frames[0].document.title === 'F2' && history.length === 3");

    // Remove the iframe: history.length shrinks to 2 immediately, and history.back() goes straight to /a.
    const removed = try page.evaluateScriptToString("document.getElementById('f').remove(); String(history.length)", testing.allocator);
    defer testing.allocator.free(removed);
    try testing.expectEqualStrings("2", removed);

    const back = try page.evaluateScriptToString("history.back(); 'ok'", testing.allocator);
    testing.allocator.free(back);
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        page = browser.current_context orelse return error.NoContext;
        const title = try page.evaluateScriptToString("document.title", testing.allocator);
        defer testing.allocator.free(title);
        if (std.mem.eql(u8, title, "A")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.DidNotReturnToA;
}
