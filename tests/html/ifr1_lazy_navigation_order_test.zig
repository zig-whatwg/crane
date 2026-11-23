//! Lane ifr1: a lazy frame's deferred navigation against a reload of its
//! initial about:blank, in the order that lost it. The lazy load intersection
//! observer's callback is queued right behind the reload (not a rendering
//! opportunity later), and the lazy navigation's request is held at the
//! server until the reload has finished - the order a loaded host produced
//! for iframe-loading-lazy-reload-location-reload.html and
//! -navigation-reload.html (8 and 4 of 30 runs at twelve runners). The frame
//! must end on its lazy URL, as the browsers' does.
//!
//! Pages come from a loopback HTTP server (module1_http_server.zig) through
//! the Browser's proxy: a held route answers only when the test releases it.
const std = @import("std");
const testing = std.testing;
const dom = @import("dom");
const browser_mod = @import("browser");
const http = @import("module1_http_server.zig");

const Browser = browser_mod.Browser;
const host_url = "http://ifr1.test/host.html";

const routes = [_]http.Route{
    .{ .path = "/src.html", .content_type = "text/html", .body = "<!doctype html><p id=p>lazy</p>", .held = true },
};

const Fixture = struct {
    server: *http.Server,
    browser: *Browser,
    proxy_buf: [64]u8 = undefined,

    fn start() !*Fixture {
        const self = try testing.allocator.create(Fixture);
        errdefer testing.allocator.destroy(self);
        self.server = try http.Server.start(testing.allocator, &routes);
        errdefer self.server.stop();
        const proxy = try self.server.proxyUrl(&self.proxy_buf);
        self.browser = try Browser.init(testing.allocator, .{
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        errdefer self.browser.deinit();
        try self.browser.navigateWithOptions(host_url, .window, .{ .skip_load = true });
        const context = self.browser.current_context orelse return error.NoPage;
        try context.loadHTML("<!doctype html><body></body>", .{ .base_url = host_url });
        return self;
    }

    fn stop(self: *Fixture) void {
        self.browser.deinit();
        self.server.stop();
        testing.allocator.destroy(self);
    }

    fn run(self: *Fixture, source: []const u8) !void {
        const context = self.browser.current_context orelse return error.NoPage;
        context.runScript(source) catch |err| {
            std.debug.print("script failed: {s}\n", .{source});
            return err;
        };
    }

    fn evaluate(self: *Fixture, source: []const u8) ![]u8 {
        const context = self.browser.current_context orelse return error.NoPage;
        return context.evaluateScriptToString(source, testing.allocator);
    }

    fn document(self: *Fixture) *@import("runtime").Instance {
        return self.browser.current_context.?.document_instance.?;
    }

    fn pump(self: *Fixture, turns: usize) !void {
        var turn: usize = 0;
        while (turn < turns) : (turn += 1) _ = try self.browser.runEventLoopBlocking(5);
    }

    fn pumpUntil(self: *Fixture, condition: []const u8, turns: usize) !void {
        var turn: usize = 0;
        while (turn < turns) : (turn += 1) {
            _ = try self.browser.runEventLoopBlocking(5);
            const value = try self.evaluate(condition);
            defer testing.allocator.free(value);
            if (std.mem.eql(u8, value, "true")) return;
        }
        const value = try self.evaluate(condition);
        defer testing.allocator.free(value);
        std.debug.print("condition never held: {s} -> {s}\n", .{ condition, value });
        return error.ConditionNeverHeld;
    }
};

fn reloadFirst(comptime reload: []const u8) !void {
    const f = try Fixture.start();
    defer f.stop();
    try f.run(
        \\globalThis.frame = document.createElement('iframe');
        \\frame.loading = 'lazy';
        \\frame.hidden = true;
        \\frame.src = 'http://ifr1.test/src.html';
        \\document.body.appendChild(frame);
    );
    try f.run(reload ++ "; frame.hidden = false;");
    // The observer's check now, its callback queued right behind the reload.
    dom.lazy_load_observer.updateObservations(f.document());
    // The reload finishes - its document is the frame's - before the lazy
    // navigation's response is let go.
    try f.pump(40);
    f.server.release("/src.html");
    try f.pumpUntil("frame.contentWindow.location.href === 'http://ifr1.test/src.html'", 400);
    try f.pump(10);
    const href = try f.evaluate("frame.contentWindow.location.href");
    defer testing.allocator.free(href);
    try testing.expectEqualStrings("http://ifr1.test/src.html", href);
    try testing.expectEqual(@as(u32, 1), f.server.count("/src.html"));
}

test "a lazy frame loads after a location.reload() of its initial about:blank, whichever is queued first" {
    try reloadFirst("frame.contentWindow.location.reload()");
}

test "a lazy frame loads after a navigation.reload() of its initial about:blank, whichever is queued first" {
    try reloadFirst("frame.contentWindow.navigation.reload()");
}
