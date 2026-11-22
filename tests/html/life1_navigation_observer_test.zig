//! A Browser's navigation observer (src/html/navigation/observer.zig, lane
//! life1; the CDP design's N2-N5): its one slot on the Browser's navigables
//! is told each milestone at its spec step, on the window thread - the order
//! CDP's Page events need (tmp/plans/cdp1-evidence/seq-vue-e2e-one.txt:
//! frameStartedLoading, the Page.navigate reply at ready-to-commit, then
//! frameNavigated, DOMContentLoaded, load, frameStoppedLoading). The hold
//! point keeps a paused navigable's navigation before its fetch until it is
//! released (CDP waitForDebuggerOnStart / Runtime.runIfWaitingForDebugger),
//! and a host navigation names its referrer and learns its navigation id.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const html = @import("html");
const LoopbackListener = @import("loopback_listener").LoopbackListener;

const observer = html.navigation.observer;
const Tag = std.meta.Tag(observer.Event);

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Run the page's tasks until `condition` (a script) is true, bounded at 5 s.
fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

/// What the observer heard: each milestone's kind, navigable, navigation
/// and (for those that carry one) URL and outcome.
const Recorder = struct {
    const Seen = struct {
        tag: Tag,
        navigable_id: u64,
        navigation_id: u64,
        url: []u8 = &.{},
        outcome: ?observer.ReadyOutcome = null,
        same_document: ?observer.SameDocumentKind = null,
        parent_id: ?u64 = null,
    };
    seen: std.ArrayListUnmanaged(Seen) = .empty,
    held: ?u64 = null,

    fn deinit(self: *Recorder) void {
        for (self.seen.items) |s| testing.allocator.free(s.url);
        self.seen.deinit(testing.allocator);
    }

    fn reset(self: *Recorder) void {
        for (self.seen.items) |s| testing.allocator.free(s.url);
        self.seen.clearRetainingCapacity();
    }

    fn notify(context: *anyopaque, milestone: *const observer.Milestone) void {
        const self: *Recorder = @ptrCast(@alignCast(context));
        var seen: Seen = .{ .tag = std.meta.activeTag(milestone.event), .navigable_id = milestone.navigable_id, .navigation_id = milestone.navigation_id };
        const url: []const u8 = switch (milestone.event) {
            .started => |s| s.url,
            .ready_to_commit => |r| blk: {
                seen.outcome = r.outcome;
                break :blk r.url;
            },
            .committed => |c| c.url,
            .same_document => |d| blk: {
                seen.same_document = d.kind;
                break :blk d.url;
            },
            .navigable_created => |c| blk: {
                seen.parent_id = c.parent_id;
                break :blk "";
            },
            else => "",
        };
        seen.url = testing.allocator.dupe(u8, url) catch &.{};
        self.seen.append(testing.allocator, seen) catch {};
    }

    fn hold(context: *anyopaque, navigable_id: u64) bool {
        const self: *Recorder = @ptrCast(@alignCast(context));
        return self.held == navigable_id;
    }

    fn observe(self: *Recorder, browser: *browser_mod.Browser) !void {
        const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
        navigables.observer = .{ .context = self, .notify = notify, .hold_first_navigation = hold };
    }

    /// The tags heard for navigable `id`, in order.
    fn tagsOf(self: *const Recorder, id: u64, out: []Tag) []Tag {
        var n: usize = 0;
        for (self.seen.items) |s| {
            if (s.navigable_id != id or n == out.len) continue;
            out[n] = s.tag;
            n += 1;
        }
        return out[0..n];
    }

    fn first(self: *const Recorder, id: u64, tag: Tag) ?Seen {
        for (self.seen.items) |s| if (s.navigable_id == id and s.tag == tag) return s;
        return null;
    }
};

fn loadedPage(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title><body>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    return page;
}

fn hostNavigationMilestones() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try page.loadHTML("<!doctype html><title>two</title><script>document.addEventListener('DOMContentLoaded', () => {});</script>", .{ .base_url = "http://example.test/two" });
    try until(browser, "document.title === 'two' && document.readyState === 'complete'");
    var buffer: [16]Tag = undefined;
    const tags = recorder.tagsOf(tab, &buffer);
    try testing.expectEqualSlices(Tag, &.{ .started, .ready_to_commit, .committed, .dom_content_loaded, .load, .stopped_loading }, tags);
    // One navigation id from start to commit (CDP's loaderId), and the URL.
    const started = recorder.first(tab, .started).?;
    try testing.expect(started.navigation_id != 0);
    try testing.expectEqual(started.navigation_id, recorder.first(tab, .ready_to_commit).?.navigation_id);
    try testing.expectEqual(started.navigation_id, recorder.first(tab, .committed).?.navigation_id);
    try testing.expectEqual(observer.ReadyOutcome.document, recorder.first(tab, .ready_to_commit).?.outcome.?);
    try testing.expectEqualStrings("http://example.test/two", recorder.first(tab, .committed).?.url);
}

test "a host navigation's milestones come in CDP's order with one navigation id" {
    try onFreshThread(hostNavigationMilestones);
}

fn sameDocumentMilestones() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try page.runScript("location.hash = 'x'; history.pushState(null, '', '/pushed'); history.replaceState(null, '', '/replaced');");
    var buffer: [16]Tag = undefined;
    try testing.expectEqualSlices(Tag, &.{ .same_document, .same_document, .same_document }, recorder.tagsOf(tab, &buffer));
    try testing.expectEqual(observer.SameDocumentKind.fragment, recorder.seen.items[0].same_document.?);
    try testing.expectEqualStrings("http://example.test/one#x", recorder.seen.items[0].url);
    try testing.expectEqual(observer.SameDocumentKind.push, recorder.seen.items[1].same_document.?);
    try testing.expectEqual(observer.SameDocumentKind.replace, recorder.seen.items[2].same_document.?);
    try testing.expectEqualStrings("http://example.test/replaced", recorder.seen.items[2].url);
}

test "same-document navigations are same_document milestones, with no navigation started" {
    try onFreshThread(sameDocumentMilestones);
}

fn frameCreatedAndDestroyed() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try page.runScript("globalThis.f = document.createElement('iframe'); document.body.append(f);");
    const created = for (recorder.seen.items) |s| {
        if (s.tag == .navigable_created) break s;
    } else return error.NoFrameCreated;
    try testing.expectEqual(tab, created.parent_id.?);
    // Its initial about:blank commits after it was created, with no
    // navigation (navigation id 0).
    const committed = recorder.first(created.navigable_id, .committed) orelse return error.NoInitialCommit;
    try testing.expectEqual(@as(u64, 0), committed.navigation_id);
    try testing.expectEqualStrings("about:blank", committed.url);

    recorder.reset();
    try page.runScript("f.remove();");
    var buffer: [4]Tag = undefined;
    try testing.expectEqualSlices(Tag, &.{.navigable_destroyed}, recorder.tagsOf(created.navigable_id, &buffer));
}

test "a frame's navigable is created before its initial document commits, and destroyed after its removal" {
    try onFreshThread(frameCreatedAndDestroyed);
}

fn nestedFramesDestroyedOnce() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);

    // A frame with a frame inside it (srcdoc, so the inner one is made as
    // the outer's document parses).
    try page.runScript("globalThis.f = document.createElement('iframe'); f.srcdoc = '<iframe></iframe>'; document.body.append(f);");
    try until(browser, "f.contentDocument && f.contentDocument.querySelector('iframe') !== null && f.contentWindow.length === 1");
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    var outer: ?u64 = null;
    var inner: ?u64 = null;
    for (recorder.seen.items) |s| {
        if (s.tag != .navigable_created) continue;
        if (s.parent_id == tab) outer = s.navigable_id else inner = s.navigable_id;
    }
    recorder.reset();
    try page.runScript("f.remove();");
    // "Destroy a child navigable" tells each navigable's end once, the inner
    // first - and closing the removed context tells nothing more (it is no
    // top-level traversable).
    var destroyed: [8]u64 = undefined;
    var n: usize = 0;
    for (recorder.seen.items) |s| {
        if (s.tag != .navigable_destroyed) continue;
        if (n < destroyed.len) destroyed[n] = s.navigable_id;
        n += 1;
    }
    try testing.expectEqualSlices(u64, &.{ inner orelse return error.NoInnerFrame, outer orelse return error.NoOuterFrame }, destroyed[0..n]);
}

test "removing a frame with a frame inside tells each navigable's end once, children first" {
    try onFreshThread(nestedFramesDestroyedOnce);
}

fn heldUntilReleased() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    // The tab is paused (CDP waitForDebuggerOnStart): its navigation starts,
    // and waits before its fetch.
    recorder.held = tab;
    try browser.navigateInPlace("data:text/html,<title>released</title>");
    _ = try browser.runEventLoopBlocking(100);
    var buffer: [16]Tag = undefined;
    try testing.expectEqualSlices(Tag, &.{.started}, recorder.tagsOf(tab, &buffer));
    try expectEval(page, "document.title", "one");
    // Released (Runtime.runIfWaitingForDebugger): it goes on.
    recorder.held = null;
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
    observer.release(navigables, tab);
    try until(browser, "document.title === 'released'");
    try testing.expectEqualSlices(Tag, &.{ .started, .ready_to_commit, .committed, .dom_content_loaded, .load, .stopped_loading }, recorder.tagsOf(tab, &buffer));
}

test "a held navigation waits before its fetch until the observer releases it" {
    try onFreshThread(heldUntilReleased);
}

/// Answers one request with a small HTML page, keeping the request's
/// Referer header.
const RefererServer = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    referer: [256]u8 = undefined,
    referer_len: usize = 0,

    fn start() !*RefererServer {
        const self = try testing.allocator.create(RefererServer);
        errdefer testing.allocator.destroy(self);
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    fn stop(self: *RefererServer) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        testing.allocator.destroy(self);
    }

    fn serve(self: *RefererServer) void {
        while (self.listener.accept()) |stream| {
            defer stream.close(testing.io);
            self.reply(stream) catch {};
        }
    }

    fn reply(self: *RefererServer, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        const head = reader.interface.buffered();
        if (indexOfIgnoreCase(head, "\r\nreferer: ")) |at| {
            const start_at = at + "\r\nreferer: ".len;
            const end_at = std.mem.indexOfPos(u8, head, start_at, "\r\n") orelse head.len;
            const value = head[start_at..end_at];
            const n = @min(value.len, self.referer.len);
            @memcpy(self.referer[0..n], value[0..n]);
            self.referer_len = n;
        }
        var output: [0]u8 = .{};
        var writer = stream.writer(testing.io, &output);
        const body = "<!doctype html><title>served</title>";
        var head_buf: [256]u8 = undefined;
        const response_head = try std.fmt.bufPrint(&head_buf, "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body.len});
        try writer.interface.writeAll(response_head);
        try writer.interface.writeAll(body);
        try writer.interface.flush();
    }
};

fn hostNavigationReferrer() !void {
    const server = try RefererServer.start();
    defer server.stop();
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    var url_buf: [128]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buf, "http://127.0.0.1:{d}/page", .{server.listener.port()});
    var started: u64 = 0;
    // N5: a host navigation names its referrer and policy (CDP
    // Page.navigate), and learns the id of the navigation it started.
    dom.top_level_traversables.navigate(page.traversable orelse return error.NoTraversable, url, .{
        .referrer = "http://127.0.0.1/referring/page?q",
        .referrer_policy = .unsafe_url,
        .started_navigation_id = &started,
    });
    try testing.expect(started != 0);
    try until(browser, "document.title === 'served'");
    try testing.expectEqual(started, recorder.first(tab, .committed).?.navigation_id);
    try testing.expectEqualStrings("http://127.0.0.1/referring/page?q", server.referer[0..server.referer_len]);
    try expectEval(page, "document.referrer", "http://127.0.0.1/referring/page?q");
}

test "a host navigation names its referrer and learns its navigation id" {
    try onFreshThread(hostNavigationReferrer);
}

fn contextNavigateReturnsItsId() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    // The host's navigation of its page: the id it started is the one its
    // milestones carry (CDP Page.navigate's loaderId).
    const started = try page.navigateWithOptions("data:text/html,<title>by id</title>", .{});
    try testing.expect(started != 0);
    try until(browser, "document.title === 'by id'");
    try testing.expectEqual(started, recorder.first(tab, .started).?.navigation_id);
    try testing.expectEqual(started, recorder.first(tab, .committed).?.navigation_id);
    // A same-document navigation starts none.
    try testing.expectEqual(@as(u64, 0), try page.navigateWithOptions("data:text/html,<title>by id</title>#frag", .{}));
}

test "Context.navigateWithOptions returns the id of the navigation it started" {
    try onFreshThread(contextNavigateReturnsItsId);
}

fn bfcacheRestoreIsCommitted() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser);
    // Two documents of the host page's history, the first kept by the
    // back/forward cache when the second commits.
    try page.loadHTML("<!doctype html><title>two</title>", .{ .base_url = "http://example.test/two" });
    try until(browser, "document.title === 'two' && document.readyState === 'complete'");
    var recorder: Recorder = .{};
    defer recorder.deinit();
    try recorder.observe(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    try page.runScript("history.back();");
    try until(browser, "document.title === 'one'");
    // Restored or reloaded, the document the tab shows again is committed
    // (CDP frameNavigated; a restore's has type BackForwardCacheRestore).
    const committed = recorder.first(tab, .committed) orelse return error.NoCommit;
    try testing.expectEqualStrings("http://example.test/one", committed.url);
}

test "a traversal back commits the document it shows again, restored from the back/forward cache or loaded" {
    try onFreshThread(bfcacheRestoreIsCommitted);
}

/// The first position of `needle` in `haystack`, ASCII case ignored (an HTTP
/// header name is case-insensitive). Zig 0.17's std.ascii has no
/// indexOfIgnoreCase.
fn indexOfIgnoreCase(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len > haystack.len) return null;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return i;
    }
    return null;
}
