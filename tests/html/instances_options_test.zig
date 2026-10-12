//! A Browser's options are its own (instances B3): two Browsers on two
//! threads at once, one with a user agent string, a proxy and
//! accept_insecure_certs of its own, the other with the defaults. Each one's
//! navigator.userAgent and navigator.appVersion - in its window and in its
//! worker - are its own, the `User-Agent` its requests send is its own, its
//! requests go through its own proxy, and its TLS verification is its own.
//!
//! Before, all of it was compile-time or the process's: one user agent
//! string for every Browser, no proxy at all (a request's proxy was a TODO),
//! and one trust store the host set for every Browser.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const dom = @import("dom");
const fetch = @import("fetch");

const custom_user_agent = "Mozilla/5.0 (Inst5; Test) CraneA/1.0";
const custom_app_version = "5.0 (Inst5; Test) CraneA/1.0";

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn expectScript(browser: *browser_mod.Browser, source: []const u8) !void {
    if (!try truthy(browser, source)) {
        std.debug.print("false: {s}\n", .{source});
        return error.ScriptAnsweredFalse;
    }
}

fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 500) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("timed out waiting for: {s}\n", .{source});
    return error.TimedOut;
}

const Shared = struct {
    arrived: std.atomic.Value(u32) = .init(0),

    fn meet(self: *Shared, point: u32) !void {
        _ = self.arrived.fetchAdd(1, .acq_rel);
        var spins: usize = 0;
        while (self.arrived.load(.acquire) < 2 * point) : (spins += 1) {
            if (spins > 20_000_000) return error.TheOtherBrowserNeverArrived;
            std.Thread.yield() catch {};
        }
    }
};

const Side = struct {
    index: usize,
    shared: *Shared,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
            _ = self.shared.arrived.fetchAdd(4, .acq_rel);
        };
    }

    fn custom(self: *const Side) bool {
        return self.index == 0;
    }

    fn config(self: *const Side) browser_mod.BrowserConfig {
        if (!self.custom()) return .{ .persist_storage = false, .snapshot_path = "" };
        return .{
            .persist_storage = false,
            .snapshot_path = "",
            .user_agent = custom_user_agent,
            .proxy = .{ .manual = .{ .http = "http://127.0.0.1:9", .no_proxy = "localhost" } },
            .accept_insecure_certs = true,
        };
    }

    fn steps(self: *Side) !void {
        const browser = try browser_mod.Browser.init(testing.allocator, self.config());
        defer browser.deinit();
        try browser.navigateWithOptions("http://inst5.test/page.html", .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://inst5.test/page.html" });
        const window = page.window_instance orelse return error.NoWindow;
        const network = dom.browser_state.networkOf(window.ctx) orelse return error.NoNetwork;

        try self.shared.meet(1);
        var buffer: [512]u8 = undefined;
        const expected_ua = if (self.custom()) custom_user_agent else fetch.internal.user_agent.default_user_agent;
        const expected_version = if (self.custom()) custom_app_version else fetch.internal.user_agent.app_version;
        // HTML NavigatorID: the environment default `User-Agent` value -
        // the Browser's - and appVersion from it.
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "navigator.userAgent === '{s}'", .{expected_ua}));
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "navigator.appVersion === '{s}'", .{expected_version}));
        // A worker's navigator reads its Browser's too.
        try expectScript(browser,
            \\globalThis.workerUA = null;
            \\const w = new Worker('data:text/javascript,postMessage([navigator.userAgent, navigator.appVersion])');
            \\w.onmessage = e => { workerUA = e.data; };
            \\true
        );
        try waitFor(browser, "workerUA !== null");
        try expectScript(browser, try std.fmt.bufPrint(&buffer, "workerUA[0] === '{s}' && workerUA[1] === '{s}'", .{ expected_ua, expected_version }));

        // Fetch's `User-Agent` is the Browser's: a request its realm makes
        // carries its network context, whose value the request sends.
        try testing.expectEqualStrings(expected_ua, network.userAgent());
        const request = try fetch.internal.InternalRequest.init(testing.allocator, "http://b.inst5.test/x");
        defer request.deinit();
        var client = try dom.global_settings.requestClient(window);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
        try request.setMethod("PUT");
        const preflight = try fetch.algorithms.http_fetch.corsPreflightFetchStart(testing.allocator, request);
        defer fetch.algorithms.http_fetch.freeNetworkRequest(testing.allocator, preflight);
        var sent: ?[]const u8 = null;
        for (preflight.headers) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "User-Agent")) sent = header.value;
        }
        try testing.expectEqualStrings(expected_ua, sent orelse return error.NoUserAgent);

        // Its proxy and TLS verification are its own.
        if (self.custom()) {
            const proxy = preflight.proxy orelse return error.NoProxy;
            try testing.expectEqualStrings("http://127.0.0.1:9", proxy.url);
            try testing.expectEqualStrings("localhost", proxy.no_proxy.?);
            // No https proxy given: an https request goes direct.
            try testing.expectEqualStrings("", (network.proxyFor("https://inst5.test/") orelse return error.NoProxy).url);
            try testing.expect(!preflight.cert_options.verify_peer);
            try testing.expect(!preflight.cert_options.verify_host);
        } else {
            try testing.expect(preflight.proxy == null);
            try testing.expect(preflight.cert_options.verify_peer);
            try testing.expect(preflight.cert_options.verify_host);
        }
        try self.shared.meet(2);
    }
};

test "two Browsers on two threads have options of their own: user agent, proxy, certificate checks" {
    var shared: Shared = .{};
    var sides = [_]Side{ .{ .index = 0, .shared = &shared }, .{ .index = 1, .shared = &shared } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}

test "a PAC file and proxy auto-detection are not supported" {
    try testing.expectError(error.NotSupported, browser_mod.Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .{ .pac = "http://inst5.test/proxy.pac" },
    }));
    try testing.expectError(error.NotSupported, browser_mod.Browser.init(testing.allocator, .{
        .persist_storage = false,
        .snapshot_path = "",
        .proxy = .autodetect,
    }));
}
