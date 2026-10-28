//! Lane keepalive2, phase B: fetchLater()'s deferred fetch records
//! (dom.deferred_fetches) - queued in their client's fetch group, sent when
//! the group is terminated (an unloading document cleanup step), when the
//! back/forward cache stores the page (a store step) or when activateAfter
//! comes, never once aborted - and the fetches they become outliving their
//! realm on the agent's network side.
//!
//! Each test runs a Browser on a thread of its own against a loopback server
//! (module1_http_server.zig) that counts the requests it receives, through
//! the Browser's proxy. fetchLater() itself is Codex row 126's: these tests
//! queue as it will, after its steps 1-13.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const browser_mod = @import("browser");
const dom = @import("dom");
const engine = @import("engine");
const fetch = @import("fetch");
const runtime = @import("runtime");
const http = @import("module1_http_server.zig");
const deferred_fetches = dom.deferred_fetches;

const routes = [_]http.Route{
    .{ .path = "/ka2/later", .content_type = "text/plain", .body = "ok" },
    .{ .path = "/ka2/aborted", .content_type = "text/plain", .body = "ok" },
    .{ .path = "/ka2/after", .content_type = "text/plain", .body = "ok" },
    .{ .path = "/ka2/stored", .content_type = "text/plain", .body = "ok" },
};

const Page = struct {
    server: *http.Server,
    browser: *browser_mod.Browser,
    proxy_buf: [64]u8 = undefined,

    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        return self.openWith(allocator, "<!doctype html><body></body>");
    }

    fn openWith(self: *Page, allocator: std.mem.Allocator, html: []const u8) !void {
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
        try page.loadHTML(html, .{ .base_url = "http://ka2.test/start" });
    }

    fn close(self: *Page) void {
        self.browser.deinit();
        self.server.stop();
    }

    fn window(self: *Page) !*runtime.Instance {
        const page = self.browser.current_context orelse return error.TestUnexpectedResult;
        return page.window_instance orelse error.TestUnexpectedResult;
    }

    /// A GET for `path`, as fetchLater()'s Request constructor leaves it -
    /// not yet populated from its client.
    fn request(self: *Page, path: []const u8) !*fetch.internal.InternalRequest {
        const global = try self.window();
        var url_buf: [128]u8 = undefined;
        const url = try std.fmt.bufPrint(&url_buf, "http://ka2.test{s}", .{path});
        return fetch.internal.InternalRequest.init(global.ctx.allocator, url);
    }

    fn group(self: *Page) !*dom.document_fetches.FetchGroup {
        return dom.global_settings.fetchGroupOf(try self.window()) orelse error.TestUnexpectedResult;
    }

    fn fetches(self: *Page) *fetch.algorithms.AgentFetches {
        return &self.browser.agent_host.fetches;
    }

    fn turnUntilCount(self: *Page, path: []const u8, n: u32) !void {
        var turns: usize = 0;
        while (self.server.count(path) < n and turns < 100) : (turns += 1) {
            _ = try self.browser.runEventLoopBlocking(20);
        }
    }

    /// A new AbortController's signal, held by the page's script as
    /// `globalThis.ka2Controller`.
    fn signal(self: *Page) !*runtime.Instance {
        const owned = try self.browser.evaluateScript("globalThis.ka2Controller = new AbortController(); ka2Controller.signal");
        defer owned.release();
        const global = try self.window();
        return engine.convertToPlatformObject(global.ctx, owned.borrow()) orelse error.TestUnexpectedResult;
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

test "a deferred fetch is held by its fetch group until the page goes, then sent - kept by the agent - and activated" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const before = page.fetches().inFlight();
            const activated = try deferred_fetches.queue(try page.window(), try page.request("/ka2/later"), .{ .total_request_length = 32 });
            defer activated.release();
            try std.testing.expectEqual(@as(usize, 1), (try page.group()).deferred.count());
            try std.testing.expect(!activated.value);
            // Nothing is sent while the page stands.
            _ = try page.browser.runEventLoopBlocking(50);
            try std.testing.expectEqual(@as(u32, 0), page.server.count("/ka2/later"));
            try std.testing.expectEqual(before, page.fetches().inFlight());
            // The page goes: its unloading cleanup steps terminate its fetch
            // group, which processes its deferred fetches.
            try page.browser.navigate("about:blank", .window);
            try std.testing.expect(activated.value);
            try std.testing.expectEqual(before + 1, page.fetches().inFlight());
            try page.turnUntilCount("/ka2/later", 1);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/later"));
        }
    }.body);
}

test "an aborted deferred fetch leaves its group and is never sent" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const signal = try page.signal();
            const aborted = try deferred_fetches.queue(try page.window(), try page.request("/ka2/aborted"), .{ .total_request_length = 32, .signal = signal });
            defer aborted.release();
            const sent = try deferred_fetches.queue(try page.window(), try page.request("/ka2/later"), .{ .total_request_length = 32 });
            defer sent.release();
            try std.testing.expectEqual(@as(usize, 2), (try page.group()).deferred.count());
            // The signal is pinned while its record is pending: a collection
            // does not take it, and abort() reaches the abort steps.
            const collected = try page.browser.evaluateScript("globalThis.gc && gc(); ka2Controller.abort(); 0");
            collected.release();
            try std.testing.expectEqual(@as(usize, 1), (try page.group()).deferred.count());
            try page.browser.navigate("about:blank", .window);
            try std.testing.expect(!aborted.value);
            try std.testing.expect(sent.value);
            try page.turnUntilCount("/ka2/later", 1);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/later"));
            try std.testing.expectEqual(@as(u32, 0), page.server.count("/ka2/aborted"));
        }
    }.body);
}

test "a deferred fetch whose activateAfter comes is sent while its page stands" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const activated = try deferred_fetches.queue(try page.window(), try page.request("/ka2/after"), .{ .total_request_length = 32, .activate_after_ms = 0 });
            defer activated.release();
            try std.testing.expect(!activated.value);
            try page.turnUntilCount("/ka2/after", 1);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/after"));
            try std.testing.expect(activated.value);
            try std.testing.expectEqual(@as(usize, 0), (try page.group()).deferred.count());
            // The page's end has nothing left to send.
            try page.browser.navigate("about:blank", .window);
            try page.turnUntilCount("/ka2/after", 2);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/after"));
        }
    }.body);
}

test "a page the back/forward cache stores sends its deferred fetches" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const activated = try deferred_fetches.queue(try page.window(), try page.request("/ka2/stored"), .{ .total_request_length = 32 });
            defer activated.release();
            // The store steps the cache runs for a kept page's realm.
            dom.bfcache.runStoreSteps((try page.window()).ctx);
            try std.testing.expect(activated.value);
            try std.testing.expectEqual(@as(usize, 0), (try page.group()).deferred.count());
            try page.turnUntilCount("/ka2/stored", 1);
            try std.testing.expectEqual(@as(u32, 1), page.server.count("/ka2/stored"));
        }
    }.body);
}

test "a Browser that ends with a deferred fetch pending, its timer armed and its signal pinned, frees them all" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            var closed = false;
            defer if (!closed) page.close();
            const signal = try page.signal();
            const activated = try deferred_fetches.queue(try page.window(), try page.request("/ka2/later"), .{
                .total_request_length = 32,
                .activate_after_ms = 60_000,
                .signal = signal,
            });
            // The result's hold outlives the Browser, as a FetchLaterResult
            // a host kept would: the record lets its own go.
            defer activated.release();
            try std.testing.expectEqual(@as(usize, 1), (try page.group()).deferred.count());
            // The Browser ends: its page's cleanup steps send the record
            // (kept, then ended with the agent), its timer is cleared and its
            // pin released; the testing allocator finds nothing left.
            closed = true;
            page.close();
            try std.testing.expect(activated.value);
        }
    }.body);
}

/// The page's document.
fn documentOf(page: *Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.TestUnexpectedResult;
    return context.document_instance orelse error.TestUnexpectedResult;
}

const all_allowed: deferred_fetches.Policy = .{ .deferred_fetch = true, .deferred_fetch_minimal = true };

test "a top-level document's deferred-fetch quota: 512 KiB, 64 KiB per request origin, less its pending records" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.open(std.testing.allocator);
            defer page.close();
            const document = try documentOf(&page);
            try std.testing.expectEqual(document, deferred_fetches.controlDocumentOf(document));
            const kib = 1024;
            // Steps 6-7: a top-level control document allowed both features
            // has 640 - 128 KiB, of which one request origin may use 64.
            try std.testing.expectEqual(@as(u64, 64 * kib), deferred_fetches.availableQuota(document, "http://ka2.test", all_allowed));
            // Not allowed "deferred-fetch": none. Not allowed the minimal
            // feature: all 640 KiB, still 64 per origin.
            try std.testing.expectEqual(@as(u64, 0), deferred_fetches.availableQuota(document, "http://ka2.test", .{ .deferred_fetch = false, .deferred_fetch_minimal = true }));
            try std.testing.expectEqual(@as(u64, 64 * kib), deferred_fetches.availableQuota(document, "http://ka2.test", .{ .deferred_fetch = true, .deferred_fetch_minimal = false }));
            // Step 8.2: a pending record counts against both, for its own
            // URL's origin.
            const first = try deferred_fetches.queue(try page.window(), try page.request("/ka2/later"), .{ .total_request_length = 1000 });
            defer first.release();
            try std.testing.expectEqual(@as(u64, 64 * kib - 1000), deferred_fetches.availableQuota(document, "http://ka2.test", all_allowed));
            try std.testing.expectEqual(@as(u64, 64 * kib), deferred_fetches.availableQuota(document, "http://other.test", all_allowed));
            // An opaque request origin is same origin with no record.
            try std.testing.expectEqual(@as(u64, 64 * kib), deferred_fetches.availableQuota(document, "null", all_allowed));
            // Eight more of 60 KiB to a third origin: the total left,
            // 512 KiB - 1000 - 480 KiB, is below any origin's 64.
            var holds: [8]*deferred_fetches.Activated = undefined;
            for (&holds) |*hold| {
                const global = try page.window();
                const r = try fetch.internal.InternalRequest.init(global.ctx.allocator, "http://third.test/ka2/later");
                hold.* = try deferred_fetches.queue(global, r, .{ .total_request_length = 60 * kib });
            }
            defer for (holds) |hold| hold.release();
            try std.testing.expectEqual(@as(u64, 512 * kib - 1000 - 480 * kib), deferred_fetches.availableQuota(document, "http://elsewhere.test", all_allowed));
            // The third origin itself is past its 64 KiB: none.
            try std.testing.expectEqual(@as(u64, 0), deferred_fetches.availableQuota(document, "http://third.test", all_allowed));
        }
    }.body);
}

test "a same-origin frame's document is controlled by its parent's, and its records count against the parent's quota" {
    try onThread(struct {
        fn body() !void {
            var page: Page = undefined;
            try page.openWith(std.testing.allocator, "<!doctype html><body><iframe srcdoc='<p>child'></iframe></body>");
            defer page.close();
            const context = page.browser.current_context orelse return error.TestUnexpectedResult;
            var turns: usize = 0;
            while (turns < 50) : (turns += 1) {
                const ready = try context.evaluateScriptToString("String(frames.length == 1 && frames[0].document.readyState == 'complete')", std.testing.allocator);
                defer std.testing.allocator.free(ready);
                if (std.mem.eql(u8, ready, "true")) break;
                _ = try page.browser.runEventLoopBlocking(20);
            }
            const top = try documentOf(&page);
            const owned = try page.browser.evaluateScript("frames[0].document");
            defer owned.release();
            const child = engine.convertToPlatformObject(top.ctx, owned.borrow()) orelse return error.TestUnexpectedResult;
            try std.testing.expect(child != top);
            // A srcdoc document has its container document's origin.
            try std.testing.expectEqual(top, deferred_fetches.controlDocumentOf(child));
            const child_window = (try @import("interfaces").Document.get_defaultView(child)) orelse return error.TestUnexpectedResult;
            const r = try fetch.internal.InternalRequest.init(child_window.ctx.allocator, "http://ka2.test/ka2/later");
            const activated = try deferred_fetches.queue(child_window, r, .{ .total_request_length = 2000 });
            defer activated.release();
            // Its record is in the frame's fetch group, and the shared quota
            // - asked from either document - counts it.
            try std.testing.expectEqual(@as(u64, 64 * 1024 - 2000), deferred_fetches.availableQuota(top, "http://ka2.test", all_allowed));
            try std.testing.expectEqual(@as(u64, 64 * 1024 - 2000), deferred_fetches.availableQuota(child, "http://ka2.test", all_allowed));
        }
    }.body);
}
