//! Lane keepalive2, phase A: a keepalive fetch outlives its realm. Fetch 2.4
//! "When a fetch group is terminated" step 1 terminates only the records
//! whose request's keepalive is false; a keepalive one goes on without its
//! client, on its agent's network side (fetch.algorithms.AgentFetches), and
//! ends when it is over or when its agent ends. WebKit's design, not its
//! code: NetworkResourceLoader::abort keeps a keepalive load with no
//! response yet (m_isKeptAlive, transferKeptAliveLoad) and its NetworkSession
//! aborts the kept loads when it ends.
//!
//! Each test runs a Browser on a thread of its own against a loopback server
//! (module1_http_server.zig) that counts the requests it receives, through
//! the Browser's proxy. A page's realm retires when the page is navigated
//! away (Browser.navigate sweeps the agent's fetches at once), before the
//! network was ever pumped: a fetch that is terminated there never reaches
//! the server.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const fetch = @import("fetch");
const runtime = @import("runtime");
const http = @import("module1_http_server.zig");
const keepalive_fetch = dom.keepalive_fetch;

const routes = [_]http.Route{
    // Answered at once.
    .{ .path = "/ka2/beacon", .content_type = "text/plain", .body = "ok" },
    // Answered after a while: the fetch is in flight when the Browser ends.
    .{ .path = "/ka2/slow", .content_type = "text/plain", .body = "late", .delay_ms = 1500 },
};

/// What an observer heard, in order.
const Heard = struct {
    responses: usize = 0,
    ends: usize = 0,

    fn observer(self: *Heard) keepalive_fetch.Observer {
        return .{ .context = self, .response = response, .ended = ended };
    }

    fn response(context: *anyopaque, status: u16) void {
        const self: *Heard = @ptrCast(@alignCast(context));
        self.responses += 1;
        _ = status;
    }

    fn ended(context: *anyopaque) void {
        const self: *Heard = @ptrCast(@alignCast(context));
        self.ends += 1;
    }
};

/// Counts the calls of the reporters a test puts on its request.
const Reports = struct {
    csp: usize = 0,
    timing: usize = 0,
    integrity: usize = 0,

    fn cspReport(context: *anyopaque, violation: *const fetch.internal.request.CspViolation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        _ = violation;
        self.csp += 1;
    }

    fn timingReport(context: *anyopaque, report: *const fetch.internal.TimingReport) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        _ = report;
        self.timing += 1;
    }

    fn integrityReport(context: *anyopaque, violation: *const fetch.internal.request.IntegrityViolation) void {
        const self: *Reports = @ptrCast(@alignCast(context));
        _ = violation;
        self.integrity += 1;
    }

    fn total(self: *const Reports) usize {
        return self.csp + self.timing + self.integrity;
    }
};

/// A Browser whose page is http://ka2.test/start, its requests going to the
/// loopback server through its proxy.
const Page = struct {
    server: *http.Server,
    browser: *browser_mod.Browser,
    proxy_buf: [64]u8 = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        self.server = try http.Server.start(allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        self.browser = try browser_mod.Browser.init(allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        errdefer self.browser.deinit();
        try self.browser.navigate("about:blank", .window);
        const page = self.browser.current_context orelse return error.TestUnexpectedResult;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://ka2.test/start" });
    }

    /// The Browser ends first: a fetch it kept must go with it, before the
    /// server stops answering.
    fn close(self: *Page) void {
        self.browser.deinit();
        self.server.stop();
    }

    fn window(self: *Page) !*runtime.Instance {
        const page = self.browser.current_context orelse return error.TestUnexpectedResult;
        return page.window_instance orelse error.TestUnexpectedResult;
    }

    /// A keepalive POST to `path` whose client is the page's window.
    fn request(self: *Page, path: []const u8) !*fetch.internal.InternalRequest {
        const global = try self.window();
        const allocator = global.ctx.allocator;
        var url_buf: [128]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "http://ka2.test{s}", .{path});
        const r = try fetch.internal.InternalRequest.init(allocator, url);
        errdefer r.deinit();
        try r.setMethod("POST");
        const body = try fetch.internal.Body.fromBytes(allocator, "ka2");
        body.source = .{ .bytes = body.data.items };
        r.body = .{ .body = body };
        r.keepalive = true;
        r.initiator_type = .beacon;
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(r, client.request);
        return r;
    }

    /// The window agent's fetches: its scheduler and every fetch in flight.
    fn fetches(self: *Page) *fetch.algorithms.AgentFetches {
        return &self.browser.agent_host.fetches;
    }

    /// The page goes: its realm retires and the agent's fetches are swept
    /// (Fetch "terminate the fetch group" for its settings object).
    fn leave(self: *Page) !void {
        try self.browser.navigate("about:blank", .window);
    }

    /// Turn the event loop until `done` says so, or about two seconds pass.
    fn turnUntil(self: *Page, context: anytype, comptime done: fn (@TypeOf(context)) bool) !void {
        var turns: usize = 0;
        while (!done(context) and turns < 100) : (turns += 1) {
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

fn beaconArrived(page: *Page) bool {
    return page.server.count("/ka2/beacon") >= 1;
}

fn slowArrived(page: *Page) bool {
    return page.server.count("/ka2/slow") >= 1;
}

/// The agent's fetches are back to `before`.
const Idle = struct {
    page: *Page,
    before: usize,

    fn reached(self: Idle) bool {
        return self.page.fetches().inFlight() == self.before;
    }
};

test "a keepalive dispatch whose realm retires before the network ran still reaches the server, and its dispatch ends" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            var heard: Heard = .{};
            _ = try keepalive_fetch.start(try page.window(), try page.request("/ka2/beacon"), .{ .observer = heard.observer() });
            // Nothing has been sent: the network is pumped by the event loop.
            try std.testing.expectEqual(@as(u32, 0), page.server.count("/ka2/beacon"));
            try page.leave();
            // The dispatch is over for its client - its realm is gone - and
            // it heard no response; the fetch is the agent's now.
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try std.testing.expectEqual(@as(usize, 1), heard.ends);
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            try page.turnUntil(&page, beaconArrived);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/beacon"));
            // Over once its response is in: the agent lets it go.
            try page.turnUntil(Idle{ .page = &page, .before = before }, Idle.reached);
            try std.testing.expectEqual(before, page.fetches().inFlight());
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
        }
    }.body);
}

test "a kept keepalive fetch reports to no one: the request's client reporters are gone with its realm" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            var reports: Reports = .{};
            const r = try page.request("/ka2/beacon");
            // The client's reporters, as a counting stand-in: a report after
            // the realm retired would reach a global that is gone.
            r.csp_violation_reporter = .{ .context = &reports, .report = &Reports.cspReport };
            r.timing_reporter = .{ .context = &reports, .report = &Reports.timingReport };
            r.integrity_violation_reporter = .{ .context = &reports, .report = &Reports.integrityReport };
            _ = try keepalive_fetch.start(try page.window(), r, .{});
            try page.leave();
            // Kept: its request names no reporter of the realm that went.
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            const kept = page.fetches().live.items[page.fetches().live.items.len - 1];
            try std.testing.expect(kept.job.request.csp_violation_reporter == null);
            try std.testing.expect(kept.job.request.timing_reporter == null);
            try std.testing.expect(kept.job.request.integrity_violation_reporter == null);
            try page.turnUntil(&page, beaconArrived);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/beacon"));
            try page.turnUntil(Idle{ .page = &page, .before = before }, Idle.reached);
            try std.testing.expectEqual(before, page.fetches().inFlight());
            // Its response and its body's end were heard by no one.
            try std.testing.expectEqual(@as(usize, 0), reports.total());
        }
    }.body);
}

test "a Browser that ends with a kept keepalive fetch in flight frees it with its agent" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            var closed = false;
            defer if (!closed) page.close();
            const before = page.fetches().inFlight();
            _ = try keepalive_fetch.start(try page.window(), try page.request("/ka2/slow"), .{});
            try page.leave();
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            // The request is at the server, whose answer is still to come.
            try page.turnUntil(&page, slowArrived);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/slow"));
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            // The Browser ends now: the kept fetch ends with its agent, and
            // the testing allocator finds nothing of it left.
            closed = true;
            page.close();
        }
    }.body);
}

test "a kept keepalive fetch is terminated once it has run kept for the agent's limit" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            _ = try keepalive_fetch.start(try page.window(), try page.request("/ka2/slow"), .{});
            try page.leave();
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            // Within the limit, a sweep leaves it.
            _ = page.fetches().sweep();
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            // Past it (Chromium's bound, shortened here), the next sweep ends
            // it, and no one hears.
            if (comptime !@hasField(fetch.algorithms.AgentFetches, "kept_limit_ms")) {
                return error.TestExpectedKeptLimit;
            } else {
                page.fetches().kept_limit_ms = 0;
                try std.testing.expect(page.fetches().sweep());
                try std.testing.expectEqual(before, page.fetches().inFlight());
            }
        }
    }.body);
}

test "a keepalive dispatch that ends while its client is there is not kept, and a request without keepalive is terminated with its realm" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            var heard: Heard = .{};
            _ = try keepalive_fetch.start(try page.window(), try page.request("/ka2/beacon"), .{ .observer = heard.observer() });
            // Its response comes (the whole body: a dispatch collects it),
            // and it ends with its client there.
            try page.turnUntil(&heard, struct {
                fn f(h: *Heard) bool {
                    return h.ends == 1;
                }
            }.f);
            try std.testing.expectEqual(@as(usize, 1), heard.responses);
            try std.testing.expectEqual(before, page.fetches().inFlight());
            // A plain request - keepalive false - whose realm goes is
            // terminated as before.
            const plain = try page.request("/ka2/slow");
            plain.keepalive = false;
            var plain_heard: Heard = .{};
            _ = try keepalive_fetch.start(try page.window(), plain, .{ .observer = plain_heard.observer() });
            try page.leave();
            try std.testing.expectEqual(@as(usize, 1), plain_heard.ends);
            try std.testing.expectEqual(before, page.fetches().inFlight());
        }
    }.body);
}
