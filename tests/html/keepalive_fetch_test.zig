//! dom.keepalive_fetch: the shared fire-and-forget dispatch that sendBeacon,
//! Reporting's uploads and hyperlink auditing's pings start their requests
//! through. Each runs a Browser on a thread of its own (per-thread fetch and
//! scheduler state), against a port nothing listens on: the transfer is
//! started at once and refused only when the network next pumps, so a test
//! can look at a dispatch while it is in flight.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const fetch = @import("fetch");
const async_fetch = fetch.algorithms.async_fetch;
const network = fetch.network;
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
            const before = async_fetch.inFlight();
            var heard: Heard = .{};
            const dispatch = try keepalive_fetch.start(try page.window(), try page.request(16), .{ .observer = heard.observer() });
            try std.testing.expect(dispatch != null);
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try page.turnUntilEnded(&heard);
            // A refused connection is a network error: status 0.
            try std.testing.expectEqual(@as(usize, 1), heard.responses);
            try std.testing.expectEqual(@as(u16, 0), heard.status);
            try std.testing.expectEqual(@as(usize, 1), heard.ends);
            try std.testing.expect(heard.ended_after_response);
            try std.testing.expectEqual(before, async_fetch.inFlight());
        }
    }.body);
}

test "send is fire-and-forget: accepted, and nothing is left once the fetch ends" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = async_fetch.inFlight();
            try std.testing.expect(try keepalive_fetch.send(try page.window(), try page.request(8), .{}));
            try std.testing.expectEqual(before + 1, async_fetch.inFlight());
            var turns: usize = 0;
            while (async_fetch.inFlight() != before and turns < 100) : (turns += 1) {
                _ = try page.browser.runEventLoopBlocking(20);
            }
            try std.testing.expectEqual(before, async_fetch.inFlight());
        }
    }.body);
}

test "cancel ends the transport synchronously and the observer hears nothing" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = async_fetch.inFlight();
            const scheduler = network.scheduler.threadScheduler();
            const transfers_before = scheduler.inFlight();
            var heard: Heard = .{};
            const dispatch = (try keepalive_fetch.start(try page.window(), try page.request(4), .{ .observer = heard.observer() })) orelse
                return error.TestUnexpectedResult;
            try std.testing.expectEqual(transfers_before + 1, scheduler.inFlight());
            dispatch.cancel();
            try std.testing.expectEqual(before, async_fetch.inFlight());
            try std.testing.expectEqual(transfers_before, scheduler.inFlight());
            _ = try page.browser.runEventLoopBlocking(20);
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try std.testing.expectEqual(@as(usize, 0), heard.ends);
        }
    }.body);
}

test "a dispatch whose realm retires is terminated, and ends without a response" {
    try onThread(struct {
        fn body() !void {
            var page = try Page.open(std.testing.allocator);
            defer page.close();
            const before = async_fetch.inFlight();
            var heard: Heard = .{};
            _ = try keepalive_fetch.start(try page.window(), try page.request(4), .{ .observer = heard.observer() });
            // The page ends: its realm retires, and Fetch terminates the
            // fetch group (Browser.navigate sweeps at once).
            try page.browser.navigate("about:blank", .window);
            try std.testing.expectEqual(@as(usize, 0), heard.responses);
            try std.testing.expectEqual(@as(usize, 1), heard.ends);
            try std.testing.expectEqual(before, async_fetch.inFlight());
        }
    }.body);
}
