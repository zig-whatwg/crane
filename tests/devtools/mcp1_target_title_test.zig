//! Lane mcp1, batch 2: what a page target's info says about its title, and
//! when Target.targetInfoChanged tells it, as Chrome 157 does - for a
//! parsed title, a title script sets after the load (document.title, the
//! title's text node, the element removed), and pages with no title, whose
//! target shows a placeholder made from the URL.
//!
//! COMPARING with Chrome: run Chrome for Testing 157 with
//! `--headless=new --remote-debugging-port=<port> --user-data-dir=<empty dir> about:blank`
//! and this test with CRANE_CDP_TRACE_CHROME_PORT=<port>: it drives that
//! Chrome's browser target instead. CRANE_CDP_TRACE_VERBOSE prints each
//! step's messages (targetInfoChanged with its title) and what getTargets
//! said.

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
    std.debug.print("mcp1_target_title: " ++ format ++ "\n", args);
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

/// What one step showed: the page target's targetInfoChanged titles, in
/// order, whether the first came after the step's Page.frameNavigated, and
/// the title Target.getTargets gave at the end.
const Step = struct {
    events: std.ArrayList([]const u8) = .empty,
    first_event_after_commit: ?bool = null,
    listed: []const u8 = "",
};

const Probe = struct {
    arena: Allocator,
    rec: replay.Recorder,
    target_id: []const u8 = "",
    session: []const u8 = "",
    /// How long a step waits for late events: a second for Chrome, whose
    /// events come from other processes; less for Crane's.
    settle_ms: u32,

    fn attach(self: *Probe) !void {
        _ = try self.rec.awaitResponse(try self.rec.send("Target.setDiscoverTargets", "{\"discover\":true}", ""));
        const targets = try self.rec.result(try self.rec.send("Target.getTargets", "{}", ""));
        for (targets.object.get("targetInfos").?.array.items) |info| {
            if (std.mem.eql(u8, info.object.get("type").?.string, "page")) self.target_id = try self.arena.dupe(u8, info.object.get("targetId").?.string);
        }
        if (self.target_id.len == 0) return error.NoPage;
        const params = try std.fmt.allocPrint(self.arena, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{self.target_id});
        const attached = try self.rec.result(try self.rec.send("Target.attachToTarget", params, ""));
        self.session = try self.arena.dupe(u8, attached.object.get("sessionId").?.string);
        _ = try self.rec.awaitResponse(try self.rec.send("Page.enable", "{}", self.session));
    }

    /// The page's title in Target.getTargets now.
    fn listed(self: *Probe) ![]const u8 {
        const id = try self.rec.send("Target.getTargets", "{}", "");
        const infos = cdp.at(self.rec.at(try self.rec.awaitResponse(id)), "result.targetInfos") orelse return error.NoResult;
        for (infos.array.items) |info| {
            if (std.mem.eql(u8, cdp.stringAt(info, "targetId") orelse "", self.target_id)) return self.arena.dupe(u8, cdp.stringAt(info, "title") orelse "");
        }
        return error.NoPage;
    }

    /// `settle_ms` of events (what a browser might send late).
    fn settle(self: *Probe) !void {
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":\"new Promise(r => setTimeout(r, {d}))\",\"awaitPromise\":true}}", .{self.settle_ms});
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", params, self.session));
    }

    /// The step's record from message `start` on.
    fn collect(self: *Probe, name: []const u8, start: usize) !Step {
        var step: Step = .{};
        var committed = false;
        for (self.rec.log.items[start..], start..) |m, i| {
            const method = cdp.stringAt(m.value, "method") orelse continue;
            if (std.mem.eql(u8, method, "Page.frameNavigated") and cdp.at(m.value, "params.frame.parentId") == null) committed = true;
            if (std.mem.eql(u8, method, "Target.targetInfoChanged") and std.mem.eql(u8, cdp.stringAt(m.value, "params.targetInfo.targetId") orelse "", self.target_id)) {
                const title = cdp.stringAt(m.value, "params.targetInfo.title") orelse "";
                if (step.first_event_after_commit == null) step.first_event_after_commit = committed;
                try step.events.append(self.arena, try self.arena.dupe(u8, title));
            }
            if (verbose()) progress("  {s} {d}: {s} {s}", .{ name, i, method, cdp.stringAt(m.value, "params.targetInfo.title") orelse "" });
        }
        step.listed = try self.listed();
        progress("{s}: {d} targetInfoChanged, the first after the commit: {?}; getTargets: \"{s}\"", .{ name, step.events.items.len, step.first_event_after_commit, step.listed });
        return step;
    }

    /// Navigate and wait for the load, then a second more.
    fn navigate(self: *Probe, name: []const u8, url: []const u8) !Step {
        const start = self.rec.log.items.len;
        const params = try std.fmt.allocPrint(self.arena, "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
        _ = try self.rec.send("Page.navigate", params, self.session);
        _ = try self.rec.awaitEvent("Page.loadEventFired", self.session, start, &.{});
        try self.settle();
        return self.collect(name, start);
    }

    /// Run `expression` in the page, then a second more.
    fn run(self: *Probe, name: []const u8, expression: []const u8) !Step {
        const start = self.rec.log.items.len;
        const params = try std.fmt.allocPrint(self.arena, "{{\"expression\":{f}}}", .{std.json.fmt(expression, .{})});
        _ = try self.rec.awaitResponse(try self.rec.send("Runtime.evaluate", params, self.session));
        try self.settle();
        return self.collect(name, start);
    }
};

fn expectEvents(step: Step, want: []const []const u8) !void {
    try testing.expectEqual(want.len, step.events.items.len);
    for (want, step.events.items) |w, got| try testing.expectEqualStrings(w, got);
}

/// The steps, then what Chrome showed.
fn check(allocator: Allocator, arena: Allocator, client: *cdp.Client, site: *replay.Site, settle_ms: u32) !void {
    var probe: Probe = .{ .arena = arena, .rec = replay.Recorder.init(allocator, client), .settle_ms = settle_ms };
    defer probe.rec.deinit();
    try probe.attach();
    var buffer: [96]u8 = undefined;
    const streamed = try arena.dupe(u8, try site.url(&buffer, "/streamed.html"));
    const titleless = try arena.dupe(u8, try site.url(&buffer, "/frame.html"));
    // The placeholder: the URL without "http://" (url_formatter's
    // kFormatUrlOmitHTTP, NavigationEntryImpl::GetTitleForDisplay).
    const streamed_shown = streamed["http://".len..];
    const titleless_shown = titleless["http://".len..];

    const parsed = try probe.navigate("parsed", streamed);
    const set = try probe.run("document.title", "document.title = 'Second'");
    const text = try probe.run("text node", "document.querySelector('title').firstChild.data = 'Third'");
    const removed = try probe.run("removed", "document.querySelector('title').remove()");
    const none = try probe.navigate("no title", titleless);
    const data = try probe.navigate("data URL", "data:text/html,<p>x</p>");
    const blank = try probe.navigate("about:blank", "about:blank");

    // A commit: one targetInfoChanged, after Page.frameNavigated, its title
    // the placeholder; a title the page has or sets: none.
    try expectEvents(parsed, &.{streamed_shown});
    try testing.expectEqual(@as(?bool, true), parsed.first_event_after_commit);
    try testing.expectEqualStrings("streamed", parsed.listed);
    try expectEvents(set, &.{});
    try testing.expectEqualStrings("Second", set.listed);
    try expectEvents(text, &.{});
    try testing.expectEqualStrings("Third", text.listed);
    try expectEvents(removed, &.{});
    try testing.expectEqualStrings(streamed_shown, removed.listed);
    try expectEvents(none, &.{titleless_shown});
    try testing.expectEqualStrings(titleless_shown, none.listed);
    try expectEvents(data, &.{"data:text/html,<p>x</p>"});
    try testing.expectEqualStrings("data:text/html,<p>x</p>", data.listed);
    try expectEvents(blank, &.{"about:blank"});
    try testing.expectEqualStrings("about:blank", blank.listed);
    progress("every expectation held", .{});
}

test "a page target's title: the placeholder after a commit, a parsed or script-set title in getTargets only, as Chrome's" {
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
