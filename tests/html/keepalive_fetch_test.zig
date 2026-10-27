//! dom.keepalive_fetch: the shared fire-and-forget dispatch that sendBeacon,
//! Reporting's uploads and hyperlink auditing's pings start their requests
//! through. Each runs a Browser on a thread of its own - its window agent's
//! fetches and scheduler on the agent's host - against a port nothing
//! listens on: the transfer is started at once and refused only when the
//! network next pumps, so a test can look at a dispatch while it is in
//! flight.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const fetch = @import("fetch");
const keepalive_fetch = dom.keepalive_fetch;

const refused_url = "http://127.0.0.1:65533/keepalive";

/// What an observer heard, in order.
const Heard = struct {
    responses: usize = 0,
    status: u16 = 999,
    ends: usize = 0,
    ended_after_response: bool = false,

    fn observer(self: *Heard) keepalive_fetch.Observer {
        return .{ .context = self, .response = response, .ended = ended };
    }

    fn response(context: *anyopaque, status: u16) void {
        const self: *Heard = @ptrCast(@alignCast(context));
        self.responses += 1;
        self.status = status;
    }

    fn ended(context: *anyopaque) void {
        const self: *Heard = @ptrCast(@alignCast(context));
        self.ends += 1;
        self.ended_after_response = self.responses == 1;
    }
};

/// A Browser with a page at http://127.0.0.1:65533/, on this thread.
const Page = struct {
    browser: *browser_mod.Browser,
    page: *browser_mod.Context,

    fn open(allocator: std.mem.Allocator) !Page {
        const browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.TestUnexpectedResult;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://127.0.0.1:65533/start" });
        return .{ .browser = browser, .page = page };
    }

    fn close(self: *Page) void {
        self.browser.deinit();
    }

    fn window(self: *Page) !*@import("runtime").Instance {
        return self.page.window_instance orelse error.TestUnexpectedResult;
    }

    /// A keepalive POST of `length` bytes whose client is the page's window.
    fn request(self: *Page, length: usize) !*fetch.internal.InternalRequest {
        const global = try self.window();
        const allocator = global.ctx.allocator;
        const r = try fetch.internal.InternalRequest.init(allocator, refused_url);
        errdefer r.deinit();
        try r.setMethod("POST");
        const bytes = try allocator.alloc(u8, length);
        defer allocator.free(bytes);
        @memset(bytes, '*');
        const body = try fetch.internal.Body.fromBytes(allocator, bytes);
        body.source = .{ .bytes = body.data.items };
        r.body = .{ .body = body };
        r.keepalive = true;
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(r, client.request);
        return r;
    }

    /// The window agent's fetches: its scheduler and every fetch in flight.
    fn fetches(self: *Page) *fetch.algorithms.AgentFetches {
        return &self.browser.agent_host.fetches;
    }

    /// Turn the event loop until `heard` hears its dispatch end.
    fn turnUntilEnded(self: *Page, heard: *const Heard) !void {
        var turns: usize = 0;
        while (heard.ends == 0 and turns < 100) : (turns += 1) {
            _ = try self.browser.runEventLoopBlocking(20);
        }
    }
};

fn onThread(comptime body: fn () anyerror!void) !void {
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
    if (run.failure) |err| return err;
}

test "a dispatch is in flight at once, hears its response, then ends and frees itself" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            var heard: Heard = .{};
            const dispatch = try keepalive_fetch.start(try page.window(), try page.request(16), .{ .observer = heard.observer() });
            try std.testing.expect(dispatch != null);
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try page.turnUntilEnded(&heard);
            // A refused connection is a network error: status 0.
            try std.testing.expectEqual(@as(usize, 1), heard.responses);
            try std.testing.expectEqual(@as(u16, 0), heard.status);
            try std.testing.expectEqual(@as(usize, 1), heard.ends);
            try std.testing.expect(heard.ended_after_response);
            try std.testing.expectEqual(before, page.fetches().inFlight());
        }
    }.body);
}

test "send is fire-and-forget: accepted, and nothing is left once the fetch ends" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            try std.testing.expect(try keepalive_fetch.send(try page.window(), try page.request(8), .{}));
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            var turns: usize = 0;
            while (page.fetches().inFlight() != before and turns < 100) : (turns += 1) {
                _ = try page.browser.runEventLoopBlocking(20);
            }
            try std.testing.expectEqual(before, page.fetches().inFlight());
        }
    }.body);
}

test "cancel ends the transport synchronously and the observer hears nothing" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            const scheduler = &page.fetches().scheduler;
            const transfers_before = scheduler.inFlight();
            var heard: Heard = .{};
            const dispatch = (try keepalive_fetch.start(try page.window(), try page.request(4), .{ .observer = heard.observer() })) orelse
                return error.TestUnexpectedResult;
            try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
            dispatch.cancel();
            try std.testing.expectEqual(before, page.fetches().inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
            _ = try page.browser.runEventLoopBlocking(20);
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try std.testing.expectEqual(@as(usize, 0), heard.ends);
        }
    }.body);
}

test "a dispatch whose realm retires ends without a response, and its keepalive fetch goes on, kept by the agent" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            var heard: Heard = .{};
            _ = try keepalive_fetch.start(try page.window(), try page.request(4), .{ .observer = heard.observer() });
            // The page ends: its realm retires, and Fetch terminates the
            // fetch group (Browser.navigate sweeps at once) - all but its
            // keepalive records (Fetch 2.4 "terminated" step 1). The
            // dispatch's client is gone; the fetch is the agent's.
            try page.browser.navigate("about:blank", .window);
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try std.testing.expectEqual(@as(usize, 1), heard.ends);
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            // Refused when the network next pumps: over, and let go.
            try turnUntilIdle(&page, before);
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
        }
    }.body);
}

/// The page window's fetch group.
fn groupOf(page: *Page) !*dom.document_fetches.FetchGroup {
    return dom.global_settings.fetchGroupOf(try page.window()) orelse error.TestUnexpectedResult;
}

/// Turn the event loop until no fetch is left in flight on the agent.
fn turnUntilIdle(page: *Page, before: usize) !void {
    var turns: usize = 0;
    while (page.fetches().inFlight() != before and turns < 100) : (turns += 1) {
        _ = try page.browser.runEventLoopBlocking(20);
    }
    try std.testing.expectEqual(before, page.fetches().inFlight());
}

test "a counted dispatch reserves its body in its fetch group, and is rejected past 64 KiB" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const window = try page.window();
            const group = try groupOf(&page);
            const quota = dom.document_fetches.FetchGroup.keepalive_quota;
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
            const before = page.fetches().inFlight();
            // Over the quota alone: rejected, nothing sent, and the request
            // freed (std.testing.allocator).
            try std.testing.expect(!try keepalive_fetch.send(window, try page.request(quota + 1), .{}));
            try std.testing.expectEqual(before, page.fetches().inFlight());
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
            // Exactly the quota: accepted, and in flight.
            try std.testing.expect(try keepalive_fetch.send(window, try page.request(quota), .{}));
            try std.testing.expectEqual(quota, group.inflight_keepalive_bytes);
            // One byte more is sendBeacon's synchronous false.
            try std.testing.expect(!try keepalive_fetch.send(window, try page.request(1), .{}));
            // A ping load is exempt (the browsers' majority), and so is a
            // request that is not keepalive.
            try std.testing.expect(try keepalive_fetch.send(window, try page.request(1), .{ .load = .ping }));
            const plain = try page.request(quota + 1);
            plain.keepalive = false;
            try std.testing.expect(try keepalive_fetch.send(window, plain, .{}));
            try std.testing.expectEqual(quota, group.inflight_keepalive_bytes);
            try std.testing.expectEqual(before + 3, page.fetches().inFlight());
            // Every fetch ends (refused): the bytes come back, once.
            try turnUntilIdle(&page, before);
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
            try std.testing.expect(try keepalive_fetch.send(window, try page.request(quota), .{}));
            try turnUntilIdle(&page, before);
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
        }
    }.body);
}

test "a canceled dispatch's bytes leave its fetch group at once" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const group = try groupOf(&page);
            const dispatch = (try keepalive_fetch.start(try page.window(), try page.request(1000), .{})) orelse
                return error.TestUnexpectedResult;
            try std.testing.expectEqual(@as(u64, 1000), group.inflight_keepalive_bytes);
            dispatch.cancel();
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
        }
    }.body);
}

test "fetch() with keepalive reserves its body, and one over the budget never starts and rejects" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const group = try groupOf(&page);
            const before = page.fetches().inFlight();
            try page.page.runScript(
                \\window.log = [];
                \\const url = 'http://127.0.0.1:65533/keepalive';
                \\const big = '*'.repeat(65536);
                \\fetch(url, {keepalive: true, method: 'POST', body: big})
                \\  .catch(e => log.push('first:' + e.name));
                \\fetch(url, {keepalive: true, method: 'POST', body: '*'})
                \\  .catch(e => log.push('second:' + e.name));
                \\// No body, no budget: it starts even when the budget is full.
                \\fetch(url, {keepalive: true}).catch(e => log.push('third:' + e.name));
            );
            // The second never reached the network.
            try std.testing.expectEqual(before + 2, page.fetches().inFlight());
            try std.testing.expectEqual(@as(u64, 65536), group.inflight_keepalive_bytes);
            try turnUntilIdle(&page, before);
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
            _ = try page.browser.runEventLoopBlocking(20);
            const log = try page.page.evaluateScriptToString("log.slice().sort().join()", std.testing.allocator);
            defer std.testing.allocator.free(log);
            // The refused connections are network errors too.
            try std.testing.expectEqualStrings("first:TypeError,second:TypeError,third:TypeError", log);
        }
    }.body);
}

test "aborting a keepalive fetch() returns its bytes at once" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const group = try groupOf(&page);
            const before = page.fetches().inFlight();
            try page.page.runScript(
                \\window.controller = new AbortController();
                \\fetch('http://127.0.0.1:65533/keepalive', {keepalive: true, method: 'POST',
                \\  body: '*'.repeat(1000), signal: controller.signal}).catch(() => {});
            );
            try std.testing.expectEqual(@as(u64, 1000), group.inflight_keepalive_bytes);
            try page.page.runScript("controller.abort()");
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
            try turnUntilIdle(&page, before);
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
        }
    }.body);
}

test "window.stop() ends a keepalive fetch() and returns its bytes" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const group = try groupOf(&page);
            try page.page.runScript(
                \\fetch('http://127.0.0.1:65533/keepalive', {keepalive: true, method: 'POST',
                \\  body: '*'.repeat(1000)}).catch(() => {});
            );
            try std.testing.expectEqual(@as(u64, 1000), group.inflight_keepalive_bytes);
            try page.page.runScript("window.stop()");
            try std.testing.expectEqual(@as(u64, 0), group.inflight_keepalive_bytes);
        }
    }.body);
}
