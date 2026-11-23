//! A navigation that starts while an earlier one's commit waits on the traversal queue - the earlier one mature,
//! its response in and its "finalize a cross-document navigation" queued - goes on, and commits after it (lane
//! fw2). Chrome's behaviour, by golden rule 2 (HTMLIFrameElement.zig commitAfterFinalize says why): the spec's
//! "deactivate a document for a cross-document navigation" step 5.2, and its push/replace "traversal" write
//! (apply the history step 8.4), would end the later navigation; whatwg/html#12942 removes both.
//!
//! The later navigation is started from a task queued on the traversal queue's own task source at the earlier
//! one's ready-to-commit milestone: it runs before the earlier one's apply job, which is queued right after.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
const html = @import("html");

const LoopbackListener = @import("loopback_listener").LoopbackListener;

const observer = html.navigation.observer;

/// A loopback server answering every request with a page titled "second", 300 ms late: the second navigation is
/// still fetching - not mature - when the first one's commit runs.
const SlowSite = struct {
    listener: LoopbackListener,
    thread: ?std.Thread = null,
    active: std.atomic.Value(u32) = .init(0),

    fn start(self: *SlowSite) !void {
        self.* = .{ .listener = try LoopbackListener.open(.{}) };
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
    }

    fn stop(self: *SlowSite) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        while (self.active.load(.acquire) != 0) std.Thread.yield() catch {};
    }

    fn serve(self: *SlowSite) void {
        while (self.listener.accept()) |stream| {
            _ = self.active.fetchAdd(1, .acq_rel);
            const thread = std.Thread.spawn(.{}, answer, .{ self, stream }) catch {
                _ = self.active.fetchSub(1, .acq_rel);
                stream.close(std.testing.io);
                continue;
            };
            thread.detach();
        }
    }

    fn answer(self: *SlowSite, stream: std.Io.net.Stream) void {
        defer _ = self.active.fetchSub(1, .acq_rel);
        defer stream.close(std.testing.io);
        var input: [4096]u8 = undefined;
        var reader = stream.reader(std.testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) reader.interface.fillMore() catch return;
        std.Io.sleep(std.testing.io, .fromMilliseconds(300), .awake) catch {};
        const body = "<!doctype html><title>second</title>";
        var output: [512]u8 = undefined;
        var writer = stream.writer(std.testing.io, &output);
        writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: {d}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n{s}", .{ body.len, body }) catch return;
        writer.interface.flush() catch {};
    }
};

/// Run `body` on a thread of its own: each test starts its own Browser.
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

/// The tab's observer: at the first navigation's ready-to-commit it queues the start of the second; it records
/// what commits.
const Overlap = struct {
    browser: *browser_mod.Browser,
    navigables: *html.window.Navigables,
    tab: u64,
    first: []const u8,
    second: []const u8,
    queued: bool = false,
    started_second: bool = false,
    /// The URLs the tab committed, in order. OWNED.
    committed: std.ArrayListUnmanaged([]u8) = .empty,

    fn deinit(self: *Overlap) void {
        for (self.committed.items) |url| testing.allocator.free(url);
        self.committed.deinit(testing.allocator);
    }

    fn notify(context: *anyopaque, milestone: *const observer.Milestone) void {
        const self: *Overlap = @ptrCast(@alignCast(context));
        if (milestone.navigable_id != self.tab) return;
        switch (milestone.event) {
            .ready_to_commit => |r| if (!self.queued and std.mem.eql(u8, r.url, self.first)) {
                self.queued = true;
                const bc = self.navigables.byId(self.tab) orelse return;
                _ = dom.history_traversal.queueTask(self.navigables, bc, .{ .callback = startSecond, .context = self, .drop = ignore });
            },
            .committed => |c| {
                const url = testing.allocator.dupe(u8, c.url) catch return;
                self.committed.append(testing.allocator, url) catch testing.allocator.free(url);
            },
            else => {},
        }
    }

    fn startSecond(context: ?*anyopaque) void {
        const self: *Overlap = @ptrCast(@alignCast(context.?));
        self.browser.navigateInPlace(self.second) catch return;
        self.started_second = true;
    }

    fn ignore(_: ?*anyopaque) void {}

    fn stop(self: *Overlap) void {
        const current = self.navigables.observer orelse return;
        if (current.context == @as(*anyopaque, self)) self.navigables.observer = null;
    }
};

fn laterNavigationCommitsAfterTheMatureOne() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>start</title><body>", .{ .base_url = "http://example.test/start" });
    try until(browser, "document.readyState === 'complete'");
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    var site: SlowSite = undefined;
    try site.start();
    defer site.stop();
    var second_buffer: [64]u8 = undefined;
    const first = "data:text/html,<title>first</title>";
    const second = try std.fmt.bufPrint(&second_buffer, "http://127.0.0.1:{d}/second", .{site.listener.port()});
    var overlap: Overlap = .{ .browser = browser, .navigables = navigables, .tab = tab, .first = first, .second = second };
    defer overlap.deinit();
    navigables.observer = .{ .context = &overlap, .notify = Overlap.notify };
    defer overlap.stop();

    try browser.navigateInPlace(first);
    // The second started while the first was mature, and the tab ends on it.
    try until(browser, "document.title === 'second'");
    try testing.expect(overlap.started_second);
    // The first committed too, before it.
    try testing.expectEqual(@as(usize, 2), overlap.committed.items.len);
    try testing.expectEqualStrings(first, overlap.committed.items[0]);
    try testing.expectEqualStrings(second, overlap.committed.items[1]);
}

test "a navigation started while an earlier one is mature (its finalize queued) commits after it, as Chrome's does" {
    try onFreshThread(laterNavigationCommitsAfterTheMatureOne);
}
