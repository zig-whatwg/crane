//! While a page's navigation is in flight, its sessions hold the commands
//! the page answers, and send them on once it commits or ends (lane fw2;
//! src/devtools/held_commands.zig). Chrome's suspension of its DevTools
//! sessions (RenderFrameDevToolsAgentHost::DidStartNavigation /
//! DidFinishNavigation, DevToolsSession::FallThrough): a Runtime.evaluate
//! sent after Page.navigate's answer runs in the new document. Crane ran it
//! in the one being replaced, and a fetch it started there was cancelled by
//! the commit: tpg_scheme_network_events' refused fetch reported
//! net::ERR_ABORTED, 1 run in 5 alone on macOS.
//!
//! The navigations here wait at a loopback site that answers each request
//! for a `/gated` path only when the test lets it, so a navigation is in
//! flight for exactly as long as a test needs.

const std = @import("std");
const testing = std.testing;
const devtools = @import("devtools");
const cdp = @import("cdp_client.zig");
const replay = @import("cdpr_replay.zig");
const LoopbackListener = @import("loopback_listener").LoopbackListener;
const resetClose = @import("loopback_listener").resetClose;

const LeakChecked = replay.LeakChecked;

/// A loopback site whose `/gated...` answers wait, each until the test
/// releases it (`release`), in the order they came.
const GatedSite = struct {
    allocator: std.mem.Allocator,
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),
    /// `/gated...` requests that reached the site.
    arrived: std.atomic.Value(u32) = .init(0),
    /// How many of them may be answered.
    released: std.atomic.Value(u32) = .init(0),

    const page_html = "<!doctype html><title>page</title><p>page</p>";
    const gated_html = "<!doctype html><title>gated</title><p>gated</p>";
    const unload_html =
        \\<!doctype html><title>unload</title><script>
        \\addEventListener('beforeunload', function () {
        \\  debugger;
        \\  window.stepped = 1;
        \\  window.stepped = 2;
        \\});
        \\</script>
    ;

    fn start(allocator: std.mem.Allocator) !*GatedSite {
        const self = try allocator.create(GatedSite);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Let every waiting answer go, stop accepting, join, close, then wait
    /// out the answers being written.
    fn stop(self: *GatedSite) void {
        self.released.store(std.math.maxInt(u32), .release);
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
        self.allocator.destroy(self);
    }

    fn url(self: *const GatedSite, buffer: []u8, path: []const u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}{s}", .{ self.listener.port(), path });
    }

    /// Wait (10 s) until `count` gated requests have arrived: the
    /// navigations that made them are past their request's start.
    fn awaitArrived(self: *GatedSite, count: u32) !void {
        var waited: u32 = 0;
        while (self.arrived.load(.acquire) < count) : (waited += 1) {
            if (waited >= 10_000) return error.Timeout;
            std.Io.sleep(std.testing.io, .fromMilliseconds(1), .awake) catch {};
        }
    }

    /// Let the next waiting gated request be answered.
    fn release(self: *GatedSite) void {
        _ = self.released.fetchAdd(1, .acq_rel);
    }

    fn serve(self: *GatedSite) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answerAndClose, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answerAndClose(self: *GatedSite, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        const how = self.answer(stream) catch .close;
        switch (how) {
            .close => stream.close(std.testing.io),
            .reset => resetClose(stream),
        }
    }

    fn answer(self: *GatedSite, stream: std.Io.net.Stream) !enum { close, reset } {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        const line_end = std.mem.indexOf(u8, head, "\r\n") orelse return .close;
        var parts = std.mem.tokenizeScalar(u8, head[0..line_end], ' ');
        _ = parts.next() orelse return .close;
        const target = parts.next() orelse return .close;
        const path = if (std.mem.indexOfScalar(u8, target, '?')) |q| target[0..q] else target;
        if (std.mem.startsWith(u8, path, "/gated")) {
            const turn = self.arrived.fetchAdd(1, .acq_rel);
            while (self.released.load(.acquire) <= turn) {
                if (self.listener.isStopping()) return .close;
                std.Io.sleep(std.testing.io, .fromMilliseconds(1), .awake) catch {};
            }
            // A connection reset: the navigation fails (a network error).
            if (std.mem.eql(u8, path, "/gated-reset")) return .reset;
        }
        var output: [1024]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        const out = &writer.interface;
        if (std.mem.eql(u8, path, "/gated-204")) {
            try out.writeAll("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
        } else {
            const body = if (std.mem.eql(u8, path, "/gated.html")) gated_html else if (std.mem.eql(u8, path, "/unload.html")) unload_html else page_html;
            try out.print("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body });
        }
        try out.flush();
        return .close;
    }
};

/// A Browser with one tab, the remote end on it, a client, and the gated
/// site.
const Setup = struct {
    allocator: std.mem.Allocator,
    fx: *replay.Fixture,
    site: *GatedSite,

    fn start(allocator: std.mem.Allocator) !Setup {
        const fx = try replay.Fixture.start(allocator);
        errdefer fx.stop();
        const site = try GatedSite.start(allocator);
        return .{ .allocator = allocator, .fx = fx, .site = site };
    }

    fn stop(self: *Setup) void {
        self.fx.stop();
        self.site.stop();
    }

    fn rec(self: *Setup) *replay.Recorder {
        return &self.fx.rec;
    }

    /// A session on the tab (auto-attach, flat), OWNED, and its target id
    /// in `target_out`.
    fn attachPage(self: *Setup, target_out: *[64]u8) ![]u8 {
        const r = self.rec();
        _ = try r.result(try r.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", ""));
        const attached = try r.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.type", .equals = "page" }});
        const target = cdp.stringAt(r.at(attached), "params.targetInfo.targetId").?;
        @memcpy(target_out[0..target.len], target);
        target_out[target.len] = 0;
        return replay.dupeAt(self.allocator, r.at(attached), "params.sessionId");
    }

    /// Navigate `session` to `path` and wait for the answer.
    fn navigate(self: *Setup, session: []const u8, path: []const u8) !void {
        const id = try self.sendNavigate(session, path);
        _ = try self.rec().result(id);
    }

    /// Send Page.navigate to `path` on `session`; its id.
    fn sendNavigate(self: *Setup, session: []const u8, path: []const u8) !i64 {
        var url_buffer: [96]u8 = undefined;
        var params: [160]u8 = undefined;
        const url = try self.site.url(&url_buffer, path);
        return self.rec().send("Page.navigate", try std.fmt.bufPrint(&params, "{{\"url\":\"{s}\"}}", .{url}), session);
    }

    fn sendEvaluate(self: *Setup, session: []const u8, expression: []const u8) !i64 {
        var params: [256]u8 = undefined;
        return self.rec().send("Runtime.evaluate", try std.fmt.bufPrint(&params, "{{\"expression\":\"{s}\"}}", .{expression}), session);
    }

    /// The string value an evaluation answered.
    fn stringResult(self: *Setup, id: i64) ![]const u8 {
        const r = try self.rec().result(id);
        return cdp.stringAt(r, "result.value") orelse error.NoStringValue;
    }

    /// The navigations the Browser's devtools record has in flight, read on
    /// the Browser's thread.
    /// (A tree without the record - the red run before it - reads 0.)
    fn inFlight(self: *Setup) !usize {
        if (comptime @hasField(devtools.BrowserSide, "navigations")) {
            const side = self.fx.server.default_context.?.side;
            const Read = struct {
                side: *devtools.BrowserSide,
                count: usize = 0,
                fn run(ctx: ?*anyopaque, _: *@import("browser").Browser) void {
                    const read: *@This() = @ptrCast(@alignCast(ctx.?));
                    read.count = read.side.navigations.count();
                }
            };
            var read: Read = .{ .side = side };
            try self.fx.host.call(&read, Read.run);
            return read.count;
        } else return 0;
    }
};

test "a command sent after Page.navigate's answer runs in the new document: held until the commit, then in order; the browser's own commands answer at once" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");

    const navigation = try setup.sendNavigate(session, "/gated.html");
    try setup.site.awaitArrived(1);
    const href = try setup.sendEvaluate(session, "location.href");
    const title = try setup.sendEvaluate(session, "document.title");
    // Answered by the browser in Chrome: not held. Sent after the two
    // evaluations, so had they not been held their answers would be in
    // first.
    const history = try r.send("Page.getNavigationHistory", "{}", session);
    const history_at = try r.awaitResponse(history);
    try testing.expectEqual(@as(?usize, null), r.responseIndex(href));
    try testing.expectEqual(@as(?usize, null), r.responseIndex(title));

    setup.site.release();
    const navigation_at = try r.awaitResponse(navigation);
    const href_at = try r.awaitResponse(href);
    const title_at = try r.awaitResponse(title);
    try testing.expect(history_at < navigation_at);
    try testing.expect(navigation_at < href_at);
    try testing.expect(href_at < title_at);
    var url_buffer: [96]u8 = undefined;
    try testing.expectEqualStrings(try setup.site.url(&url_buffer, "/gated.html"), try setup.stringResult(href));
    try testing.expectEqualStrings("gated", try setup.stringResult(title));
    try testing.expectEqual(@as(usize, 0), try setup.inFlight());
}

test "held commands go when the navigation fails, ends without a document, or is replaced" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");
    var url_buffer: [96]u8 = undefined;
    const page_url = try gpa.allocator().dupe(u8, try setup.site.url(&url_buffer, "/page.html"));
    defer gpa.allocator().free(page_url);

    // A network error: Page.navigate answers with its errorText, then the
    // held command runs.
    {
        const navigation = try setup.sendNavigate(session, "/gated-reset");
        try setup.site.awaitArrived(1);
        const held = try setup.sendEvaluate(session, "1 + 1");
        _ = try r.awaitResponse(try r.send("Page.getNavigationHistory", "{}", session));
        try testing.expectEqual(@as(?usize, null), r.responseIndex(held));
        setup.site.release();
        const navigation_at = try r.awaitResponse(navigation);
        try testing.expect(cdp.stringAt(r.at(navigation_at), "result.errorText") != null);
        const held_at = try r.awaitResponse(held);
        try testing.expect(navigation_at < held_at);
        try testing.expectEqual(@as(i64, 2), cdp.at(try r.result(held), "result.value").?.integer);
    }
    try setup.navigate(session, "/page.html");
    // A 204: no document - the page stays, and the held command reads it.
    {
        const navigation = try setup.sendNavigate(session, "/gated-204");
        try setup.site.awaitArrived(2);
        const held = try setup.sendEvaluate(session, "location.href");
        _ = try r.awaitResponse(try r.send("Page.getNavigationHistory", "{}", session));
        try testing.expectEqual(@as(?usize, null), r.responseIndex(held));
        setup.site.release();
        const navigation_at = try r.awaitResponse(navigation);
        try testing.expectEqualStrings("net::ERR_ABORTED", cdp.stringAt(r.at(navigation_at), "result.errorText").?);
        try testing.expect(navigation_at < try r.awaitResponse(held));
        try testing.expectEqualStrings(page_url, try setup.stringResult(held));
    }
    // Replaced by another navigation (Page.navigate is the browser's: it
    // goes at once): the first ends, the hold lasts for the second, and the
    // held command runs in its document. (Page.stopLoading, Chrome's other
    // way to end one, Crane does not answer yet.)
    {
        _ = try setup.sendNavigate(session, "/gated.html");
        try setup.site.awaitArrived(3);
        const held = try setup.sendEvaluate(session, "document.title");
        const replacing = try setup.sendNavigate(session, "/page.html");
        const replacing_at = try r.awaitResponse(replacing);
        try testing.expect(replacing_at < try r.awaitResponse(held));
        try testing.expectEqualStrings("page", try setup.stringResult(held));
        setup.site.release();
    }
    try testing.expectEqual(@as(usize, 0), try setup.inFlight());
}

test "a session's held commands are dropped, unanswered, when it detaches" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");

    _ = try setup.stringResult(try setup.sendEvaluate(session, "localStorage.clear() || 'cleared'"));
    _ = try setup.sendNavigate(session, "/gated.html");
    try setup.site.awaitArrived(1);
    // Its effect would outlive the navigation (the origin's storage): a
    // dropped command never makes it.
    const held = try setup.sendEvaluate(session, "localStorage.setItem('ran', 'yes') || location.href");
    var params: [128]u8 = undefined;
    _ = try r.result(try r.send("Target.detachFromTarget", try std.fmt.bufPrint(&params, "{{\"sessionId\":\"{s}\"}}", .{session}), ""));
    _ = try r.awaitEvent("Target.detachedFromTarget", "", 0, &.{});
    setup.site.release();
    // The tab commits with no session on it; a second session finds the new
    // document, and the first one's command never answered.
    const second = try replay.dupeAt(gpa.allocator(), r.at(try r.awaitResponse(try r.send("Target.attachToTarget", try std.fmt.bufPrint(&params, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{std.mem.sliceTo(&target, 0)}), ""))), "result.sessionId");
    defer gpa.allocator().free(second);
    var url_buffer: [96]u8 = undefined;
    const gated = try setup.site.url(&url_buffer, "/gated.html");
    var tries: u32 = 0;
    while (true) : (tries += 1) {
        if (std.mem.eql(u8, try setup.stringResult(try setup.sendEvaluate(second, "location.href")), gated)) break;
        if (tries > 2000) return error.NeverCommitted;
        std.Io.sleep(std.testing.io, .fromMilliseconds(5), .awake) catch {};
    }
    try testing.expectEqualStrings("none", try setup.stringResult(try setup.sendEvaluate(second, "localStorage.getItem('ran') || 'none'")));
    try testing.expectEqual(@as(?usize, null), r.responseIndex(held));
    try testing.expectEqual(@as(usize, 0), try setup.inFlight());
}

test "Debugger.pause sent while commands are held is not held (Chrome sends it on the IO thread)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");
    _ = try r.result(try r.send("Debugger.enable", "{}", session));

    const navigation = try setup.sendNavigate(session, "/gated.html");
    try setup.site.awaitArrived(1);
    const document = try r.send("DOM.getDocument", "{}", session);
    const pause = try r.send("Debugger.pause", "{}", session);
    const pause_at = try r.awaitResponse(pause);
    try testing.expectEqual(@as(?usize, null), r.responseIndex(document));
    setup.site.release();
    const navigation_at = try r.awaitResponse(navigation);
    const document_at = try r.awaitResponse(document);
    try testing.expect(pause_at < navigation_at);
    try testing.expect(navigation_at < document_at);
}

test "params Chrome decodes in the browser and that do not decode are answered at once; the page's own params wait with their command" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");

    _ = try setup.sendNavigate(session, "/gated.html");
    try setup.site.awaitArrived(1);
    // Runtime.evaluate's params are the page's to decode: it waits.
    const page_decoded = try r.send("Runtime.evaluate", "{\"expression\":5}", session);
    // Emulation.setUserAgentOverride's are the browser's (EmulationHandler,
    // which then lets it through): -32602 now.
    const browser_decoded = try r.send("Emulation.setUserAgentOverride", "{\"userAgent\":5}", session);
    try testing.expectEqual(@as(?i64, -32602), try r.errorCode(browser_decoded));
    try testing.expectEqual(@as(?usize, null), r.responseIndex(page_decoded));
    // Well-formed, it waits as any of the page's commands.
    const well_formed = try r.send("Emulation.setUserAgentOverride", "{\"userAgent\":\"fw2\"}", session);
    _ = try r.awaitResponse(try r.send("Page.getNavigationHistory", "{}", session));
    try testing.expectEqual(@as(?usize, null), r.responseIndex(well_formed));
    setup.site.release();
    try testing.expectEqual(@as(?i64, -32602), try r.errorCode(page_decoded));
    try testing.expectEqual(@as(?i64, null), try r.errorCode(well_formed));
    try testing.expect(r.responseIndex(page_decoded).? < r.responseIndex(well_formed).?);
}

test "a session that attaches while its tab navigates holds too (kAll)" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/page.html");

    _ = try setup.sendNavigate(session, "/gated.html");
    try setup.site.awaitArrived(1);
    var params: [128]u8 = undefined;
    const second = try replay.dupeAt(gpa.allocator(), r.at(try r.awaitResponse(try r.send("Target.attachToTarget", try std.fmt.bufPrint(&params, "{{\"targetId\":\"{s}\",\"flatten\":true}}", .{std.mem.sliceTo(&target, 0)}), ""))), "result.sessionId");
    defer gpa.allocator().free(second);
    const href = try setup.sendEvaluate(second, "location.href");
    _ = try r.awaitResponse(try r.send("Page.getNavigationHistory", "{}", second));
    try testing.expectEqual(@as(?usize, null), r.responseIndex(href));
    setup.site.release();
    var url_buffer: [96]u8 = undefined;
    try testing.expectEqualStrings(try setup.site.url(&url_buffer, "/gated.html"), try setup.stringResult(href));
}

test "a tab closed while it navigates takes its navigation out of the record, and its held commands with its session" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();

    // A second tab, auto-attached, navigating and held.
    const created_id = try r.send("Target.createTarget", "{\"url\":\"about:blank\"}", "");
    const created = try replay.dupeAt(gpa.allocator(), try r.result(created_id), "targetId");
    defer gpa.allocator().free(created);
    const attached = try r.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.targetId", .equals = created }});
    const other = try replay.dupeAt(gpa.allocator(), r.at(attached), "params.sessionId");
    defer gpa.allocator().free(other);
    _ = try setup.sendNavigate(other, "/gated.html");
    try setup.site.awaitArrived(1);
    try testing.expectEqual(@as(usize, 1), try setup.inFlight());
    const held = try setup.sendEvaluate(other, "1");

    var params: [128]u8 = undefined;
    _ = try r.result(try r.send("Target.closeTarget", try std.fmt.bufPrint(&params, "{{\"targetId\":\"{s}\"}}", .{created}), ""));
    // (Target.targetDestroyed is discovery's, not asked for here.)
    _ = try r.awaitEvent("Target.detachedFromTarget", "", 0, &.{.{ .path = "params.sessionId", .equals = other }});
    var tries: u32 = 0;
    while (try setup.inFlight() != 0) : (tries += 1) {
        if (tries > 2000) return error.RecordKept;
        std.Io.sleep(std.testing.io, .fromMilliseconds(5), .awake) catch {};
    }
    try testing.expectEqual(@as(?usize, null), r.responseIndex(held));
    // The first tab's session holds nothing.
    try testing.expectEqualStrings("about:blank", try setup.stringResult(try setup.sendEvaluate(session, "location.href")));
}

test "a tab waiting for the debugger, its first navigation held, resumes on Runtime.runIfWaitingForDebugger, whose answer waits for the commit" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    const r = setup.rec();
    _ = try r.result(try r.send("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":true,\"flatten\":true}", ""));
    var url_buffer: [96]u8 = undefined;
    const url = try setup.site.url(&url_buffer, "/page.html");
    var params: [160]u8 = undefined;
    const created = try replay.dupeAt(gpa.allocator(), try r.result(try r.send("Target.createTarget", try std.fmt.bufPrint(&params, "{{\"url\":\"{s}\"}}", .{url}), "")), "targetId");
    defer gpa.allocator().free(created);
    const attached = try r.awaitEvent("Target.attachedToTarget", "", 0, &.{.{ .path = "params.targetInfo.targetId", .equals = created }});
    try testing.expect(cdp.at(r.at(attached), "params.waitingForDebugger").?.bool);
    const session = try replay.dupeAt(gpa.allocator(), r.at(attached), "params.sessionId");
    defer gpa.allocator().free(session);

    const run = try r.send("Runtime.runIfWaitingForDebugger", "{}", session);
    _ = try r.awaitResponse(run);
    try testing.expectEqualStrings(url, try setup.stringResult(try setup.sendEvaluate(session, "location.href")));
}

test "paused in a beforeunload handler, Debugger.stepOver is not held, and the navigation goes on" {
    var gpa: LeakChecked = .init;
    defer testing.expect(gpa.deinit() == .ok) catch @panic("leak");
    var setup = try Setup.start(gpa.allocator());
    defer setup.stop();
    var target: [64]u8 = undefined;
    const session = try setup.attachPage(&target);
    defer gpa.allocator().free(session);
    const r = setup.rec();
    try setup.navigate(session, "/unload.html");
    _ = try r.result(try r.send("Debugger.enable", "{}", session));

    const navigation = try setup.sendNavigate(session, "/page.html");
    const first = try r.awaitEvent("Debugger.paused", session, 0, &.{});
    // beforeunload runs before the request starts (Chrome's
    // DidStartNavigation comes after it): stepping is not held.
    const step = try r.send("Debugger.stepOver", "{}", session);
    _ = try r.awaitResponse(step);
    const second = try r.awaitEvent("Debugger.paused", session, first + 1, &.{});
    try testing.expect(second > first);
    _ = try r.awaitResponse(try r.send("Debugger.resume", "{}", session));
    _ = try r.result(navigation);
    var url_buffer: [96]u8 = undefined;
    try testing.expectEqualStrings(try setup.site.url(&url_buffer, "/page.html"), try setup.stringResult(try setup.sendEvaluate(session, "location.href")));
}
