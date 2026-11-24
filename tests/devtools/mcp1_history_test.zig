//! Lane mcp1, batch 4: a page's navigation history over CDP as Chrome 157
//! answers it (content/browser/devtools/protocol/page_handler.cc
//! PageHandler::GetNavigationHistory, NavigateToHistoryEntry and
//! ResetNavigationHistory over NavigationController): which entries a tab
//! has after each kind of navigation - two navigations, an iframe's, a
//! pushState, a fragment, a link, a form, a reload, a traversal - with each
//! entry's id, URL, user-typed URL, title and transition type, the current
//! index, and the errors.
//!
//! COMPARING with Chrome: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port>: it drives that
//! Chrome's browser target instead. CRANE_CDP_TRACE_VERBOSE prints each
//! step's history, its ids numbered by first appearance and the site's
//! origin as {site}.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const browser_mod = @import("browser");
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");

const LeakChecked = @import("root").poisoning.DebugAllocator(.{ .thread_safe = true });

fn verbose() bool {
    return std.c.getenv("CRANE_CDP_TRACE_VERBOSE") != null;
}

fn progress(comptime format: []const u8, args: anytype) void {
    if (!verbose()) return;
    std.debug.print("mcp1_history: " ++ format ++ "\n", args);
}

/// The browser target's WebSocket path on `port` (/json/version).
fn browserPath(allocator: Allocator, port: u16) ![]u8 {
    var version = try cdp.httpGet(allocator, port, "/json/version", &.{"Host: 127.0.0.1"});
    defer version.deinit();
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, version.body, .{});
    defer parsed.deinit();
    const ws = parsed.value.object.get("webSocketDebuggerUrl").?.string;
    return allocator.dupe(u8, ws[std.mem.indexOf(u8, ws, "/devtools/").?..]);
}

const Probe = struct {
    arena: Allocator,
    rec: replay.Recorder,
    origin: []const u8,
    session: []const u8 = "",
    /// Entry ids in the order first seen: an id prints as "e<index>".
    seen: std.ArrayList(i64) = .empty,
    /// How long a step waits for late work: a second for Chrome, less for
    /// Crane.
    settle_ms: u32,

    fn attach(self: *Probe) !void {
        const targets = try self.rec.result(try self.rec.send("Target.getTargets", "{}", ""));
        var target_id: []const u8 = "";
        for (targets.object.get("targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, info.object.get("type").?.string, "page")) target_id = try self.arena.dupe(u8, info.object.get("targetId").?.string);
        }
        if (target_id.len == 0) return error.NoPage;
        const params = try std.fmt.allocPrint(self.arena, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{target_id});
        const attached = try self.rec.result(try self.rec.send("Target.attachToTarget", params, ""));
        self.session = try self.arena.dupe(u8, attached.object.get("sessionId").?.string);
        _ = try self.rec.awaitResponse(try self.rec.send("Page.enable", "{}", self.session));
    }

    fn settle(self: *Probe) !void {
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":\"new Promise(r => setTimeout(r, {d}))\",\"awaitPromise\":true}}", .{self.settle_ms});
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", params, self.session));
    }

    fn label(self: *Probe, id: i64) ![]const u8 {
        for (self.seen.items, 0..) |s, i| if (s == id) return std.fmt.allocPrint(self.arena, "e{d}", .{i});
        try self.seen.append(self.arena, id);
        return std.fmt.allocPrint(self.arena, "e{d}", .{self.seen.items.len - 1});
    }

    fn site(self: *Probe, text: []const u8) ![]const u8 {
        return std.mem.replaceOwned(u8, self.arena, text, self.origin, "{site}");
    }

    /// Page.getNavigationHistory, as one line per entry after a header:
    /// "current <i>", then "<label> <transition> <url> typed=<userTypedURL>
    /// title=<title>"; or the command's error.
    fn history(self: *Probe, name: []const u8) ![]const u8 {
        const id = try self.rec.send("Page.getNavigationHistory", "{}", self.session);
        const answer = self.rec.at(try self.rec.awaitResponse(id));
        var out: std.Io.Writer.Allocating = .init(self.arena);
        if (cdp.at(answer, "error")) |e| {
            try out.writer.print("error {s}", .{cdp.stringAt(e, "message") orelse "?"});
        } else {
            const result = cdp.at(answer, "result").?;
            try out.writer.print("current {d}", .{result.object.get("currentIndex").?.integer});
            for (result.object.get("entries").?.array.items) |entry| {
                try out.writer.print("\n{s} {s} {s} typed={s} title={s}", .{
                    try self.label(entry.object.get("id").?.integer),
                    cdp.stringAt(entry, "transitionType") orelse "?",
                    try self.site(cdp.stringAt(entry, "url") orelse "?"),
                    try self.site(cdp.stringAt(entry, "userTypedURL") orelse "?"),
                    cdp.stringAt(entry, "title") orelse "?",
                });
            }
        }
        progress("== {s}\n{s}", .{ name, out.written() });
        return out.written();
    }

    /// The id of entry `index` now.
    fn entryId(self: *Probe, index: usize) !i64 {
        const result = try self.rec.result(try self.rec.send("Page.getNavigationHistory", "{}", self.session));
        return result.object.get("entries").?.array.items[index].object.get("id").?.integer;
    }

    fn navigate(self: *Probe, url: []const u8) !void {
        const start = self.rec.log.items.len;
        const params = try std.fmt.allocPrint(self.arena, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
        _ = try self.rec.send("Page.navigate", params, self.session);
        _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, start, &.{});
        try self.settle();
    }

    /// Run `expression` in the page; `load`: wait for the main frame's load
    /// it causes.
    fn run(self: *Probe, expression: []const u8, load: bool) !void {
        const start = self.rec.log.items.len;
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":{f}}}", .{std.json.fmt(expression, .{})});
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", params, self.session));
        if (load) _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, start, &.{});
        try self.settle();
    }

    fn reload(self: *Probe) !void {
        const start = self.rec.log.items.len;
        _ = try self.rec.send("Page.reload", "{}", self.session);
        _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, start, &.{});
        try self.settle();
    }

    /// Page.navigateToHistoryEntry to entry `index`; `load`: a
    /// cross-document traversal, waited for.
    fn go(self: *Probe, index: usize, load: bool) !void {
        const start = self.rec.log.items.len;
        const params = try std.fmt.allocPrint(self.arena, "{{\"entryId\":{d}}}", .{try self.entryId(index)});
        _ = try self.rec.result(try self.rec.send("Page.navigateToHistoryEntry", params, self.session));
        if (load) _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, start, &.{});
        try self.settle();
    }

    /// A command's error message, or "" when it succeeded.
    fn errorOf(self: *Probe, method: []const u8, params: []const u8) ![]const u8 {
        const answer = self.rec.at(try self.rec.awaitResponse(try self.rec.send(method, params, self.session)));
        const e = cdp.at(answer, "error") orelse return "";
        const text = try std.fmt.allocPrint(self.arena, "{d} {s}", .{ (cdp.at(e, "code") orelse std.json.Value{ .integer = 0 }).integer, cdp.stringAt(e, "message") orelse "" });
        progress("== {s} {s}: {s}", .{ method, params, text });
        return text;
    }
};

/// The steps; each history recorded.
fn check(allocator: Allocator, arena: Allocator, client: *cdp.Client, s: *replay.Site, settle_ms: u32) !void {
    var buffer: [96]u8 = undefined;
    const origin = try arena.dupe(u8, try s.url(&buffer, ""));
    var probe: Probe = .{ .arena = arena, .rec = replay.Recorder.init(allocator, client), .origin = origin, .settle_ms = settle_ms };
    defer probe.rec.deinit();
    try probe.attach();
    const root = try std.fmt.allocPrint(arena, "{s}/", .{origin});
    const streamed = try std.fmt.allocPrint(arena, "{s}/streamed.html", .{origin});

    const start = try probe.history("start");
    try probe.navigate(root);
    const first = try probe.history("navigate /");
    try probe.run("frames[0].location.href = '/data.json'", false);
    const subframe = try probe.history("iframe navigated");
    try probe.run("history.pushState(null, '', '/pushed')", false);
    const pushed = try probe.history("pushState");
    try probe.run("location.hash = 'x'", false);
    const fragment = try probe.history("fragment");
    try probe.run("document.title = 'Changed'", false);
    const titled = try probe.history("title set");
    try probe.navigate(streamed);
    const second = try probe.history("navigate /streamed.html");
    try probe.run("const a = document.createElement('a'); a.href = '/reject.html'; document.body.append(a); a.click()", true);
    const linked = try probe.history("link clicked");
    try probe.run("const f = document.createElement('form'); f.action = '/frame.html'; f.innerHTML = '<input name=q value=1>'; document.body.append(f); f.submit()", true);
    const submitted = try probe.history("form submitted");
    try probe.reload();
    const reloaded = try probe.history("reloaded");
    try probe.go(1, true);
    const back_far = try probe.history("navigateToHistoryEntry 1");
    try probe.go(4, false);
    const forward_same = try probe.history("navigateToHistoryEntry 4");
    const unknown = try probe.errorOf("Page.navigateToHistoryEntry", "{\"entryId\":987654321}");
    try probe.run("history.back()", false);
    const page_back = try probe.history("history.back()");
    const reset = try probe.errorOf("Page.resetNavigationHistory", "{}");
    const after_reset = try probe.history("resetNavigationHistory");

    // The record, compared as one text.
    const all = try std.mem.join(arena, "\n-- ", &.{ start, first, subframe, pushed, fragment, titled, second, linked, submitted, reloaded, back_far, forward_same, unknown, page_back, reset, after_reset });
    progress("ALL\n{s}", .{all});
    try testing.expectEqualStrings(try std.mem.join(arena, "\n", &chrome_157), all);
}

/// What Chrome for Testing 157.0.8103.78 answered (recorded on chat2 with
/// CRANE_CDP_TRACE_CHROME_PORT, 2026-11-24), one line each.
const chrome_157 = [_][]const u8{
    "current 0",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "-- current 1",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "-- current 2",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "-- current 3",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "-- current 4",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=replay",
    "-- current 4",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "-- current 5",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "-- current 6",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "-- current 7",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "e7 form_submit {site}/frame.html?q=1 typed={site}/frame.html?q=1 title=",
    "-- current 7",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "e7 reload {site}/frame.html?q=1 typed={site}/frame.html?q=1 title=",
    "-- current 1",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "e7 reload {site}/frame.html?q=1 typed={site}/frame.html?q=1 title=",
    "-- current 4",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "e7 reload {site}/frame.html?q=1 typed={site}/frame.html?q=1 title=",
    "-- -32602 No entry with passed id",
    "-- current 3",
    "e0 auto_toplevel about:blank typed=about:blank title=",
    "e1 typed {site}/ typed={site}/ title=replay",
    "e2 typed {site}/ typed={site}/ title=replay",
    "e3 link {site}/pushed typed={site}/ title=replay",
    "e4 link {site}/pushed#x typed={site}/ title=Changed",
    "e5 typed {site}/streamed.html typed={site}/streamed.html title=streamed",
    "e6 link {site}/reject.html typed={site}/reject.html title=reject",
    "e7 reload {site}/frame.html?q=1 typed={site}/frame.html?q=1 title=",
    "-- ",
    "-- current 0",
    "e3 link {site}/pushed typed={site}/ title=replay",
};

test "Page.getNavigationHistory, navigateToHistoryEntry and resetNavigationHistory: the entries and answers Chrome gives after each kind of navigation" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    const allocator = gpa.allocator();
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const site = try replay.Site.start(allocator);
    defer site.stop();

    if (std.c.getenv("CRANE_CDP_TRACE_CHROME_PORT")) |port_text| {
        const port = try std.fmt.parseInt(u16, std.mem.span(port_text), 10);
        const path = try browserPath(allocator, port);
        defer allocator.free(path);
        const client = try cdp.Client.openWebSocket(allocator, port, path, null);
        defer client.close();
        if (client.upgrade_status != 101) return error.UpgradeRefused;
        return check(allocator, arena_state.allocator(), client, site, 1000);
    }

    const host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const server = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer server.stop();
    const path = try browserPath(allocator, server.port);
    defer allocator.free(path);
    const client = try cdp.Client.openWebSocket(allocator, server.port, path, null);
    defer client.close();
    try check(allocator, arena_state.allocator(), client, site, 300);
}
