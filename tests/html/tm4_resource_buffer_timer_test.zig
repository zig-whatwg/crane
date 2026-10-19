//! Overflow delivery shares the realm's one-shot timer ordering. Each
//! pending callback owns its allocation until delivery or timer teardown.
const std = @import("std");
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const timing = @import("dom").performance_timeline;
const dom = @import("dom");
const html = @import("html");
const http = @import("module1_http_server.zig");

const Timer = struct {
    entry: ?struct { callback: runtime.TimerCallback, data: ?*anyopaque, drop: runtime.TimerDrop } = null,
    arms: usize = 0,
    runs: usize = 0,
    drops: usize = 0,
    delay: u64 = 99,
    fail: bool = false,

    fn interface(self: *Timer) runtime.TimerInterface {
        return .{ .ctx = self, .vtable = &vtable };
    }

    fn plain(_: *anyopaque, _: u64, _: runtime.TimerCallback, _: ?*anyopaque) runtime.TimerId {
        @panic("resource-buffer delivery must own its pending callback");
    }

    fn owned(raw: *anyopaque, ms: u64, callback: runtime.TimerCallback, data: ?*anyopaque, drop_fn: runtime.TimerDrop) runtime.TimerId {
        const self: *Timer = @ptrCast(@alignCast(raw));
        if (self.fail) return 0;
        std.debug.assert(self.entry == null);
        self.entry = .{ .callback = callback, .data = data, .drop = drop_fn };
        self.arms += 1;
        self.delay = ms;
        return @intCast(self.arms);
    }

    fn clear(_: *anyopaque, _: runtime.TimerId) bool {
        return false;
    }

    fn run(self: *Timer) void {
        const entry = self.entry orelse return;
        self.entry = null;
        self.runs += 1;
        entry.callback(entry.data);
    }

    fn drop(self: *Timer) void {
        const entry = self.entry orelse return;
        self.entry = null;
        self.drops += 1;
        entry.drop(entry.data);
    }

    const vtable: runtime.TimerVTable = .{ .setTimeout = plain, .setTimeoutOwned = owned, .clearTimeout = clear };
};

const Scenario = enum { burst, drop, failed, absent };

const Trial = struct {
    scenario: Scenario,
    result: anyerror!void = {},

    fn run(self: *Trial) void {
        self.result = self.check();
    }

    fn check(self: *Trial) !void {
        const allocator = std.testing.allocator;
        var browser = try browser_mod.Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigate("about:blank", .window);
        const page = browser.current_context orelse return error.TestUnexpectedResult;
        try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
        try page.runScript(
            \\performance.clearResourceTimings();
            \\performance.setResourceTimingBufferSize(0);
            \\globalThis.bufferEvents = 0;
            \\performance.onresourcetimingbufferfull = () => {
            \\  ++bufferEvents;
            \\  performance.setResourceTimingBufferSize(10);
            \\};
        );
        const realm = page.realm orelse return error.TestUnexpectedResult;
        const timeline = timing.timelineOf(realm) orelse return error.TestUnexpectedResult;
        const saved_timer = realm.timer;
        const saved_loop = realm.event_loop;
        defer {
            realm.timer = saved_timer;
            realm.event_loop = saved_loop;
        }
        var timer: Timer = .{ .fail = self.scenario == .failed };
        defer timer.drop();
        realm.timer = if (self.scenario == .absent) null else timer.interface();
        // No task queue hides a failed timer allocation. Delivery belongs
        // to the timer API, including when no ordinary task loop is set.
        realm.event_loop = null;
        var fixture: Fixture = .{ .realm = realm, .timeline = timeline };
        try engine.runInRealm(realm, Fixture.add, &fixture);
        try fixture.result;
        if (self.scenario == .failed or self.scenario == .absent) {
            try std.testing.expect(timer.entry == null);
            try std.testing.expect(!timeline.resource.full_event_pending);
            try std.testing.expectEqual(@as(usize, 1), timeline.resource.secondary_buffer.items.len);
            return;
        }
        try std.testing.expectEqual(@as(usize, 1), timer.arms);
        try std.testing.expectEqual(@as(u64, 0), timer.delay);
        try std.testing.expect(timeline.resource.full_event_pending);
        try engine.runInRealm(realm, Fixture.add, &fixture);
        try fixture.result;
        try std.testing.expectEqual(@as(usize, 1), timer.arms);
        try std.testing.expectEqual(@as(usize, 2), timeline.resource.secondary_buffer.items.len);
        if (self.scenario == .drop) {
            timer.drop();
            try std.testing.expect(!timeline.resource.full_event_pending);
            try page.runScript("if (bufferEvents !== 0) throw Error('drop delivered an event')");
        } else {
            timer.run();
            try std.testing.expect(!timeline.resource.full_event_pending);
            try std.testing.expectEqual(@as(usize, 2), timeline.resource.current_size);
            try std.testing.expectEqual(@as(usize, 0), timeline.resource.secondary_buffer.items.len);
            try page.runScript("if (bufferEvents !== 1) throw Error('wrong event count')");
        }
        timing.setResourceTimingBufferSize(timeline, 0);
        try engine.runInRealm(realm, Fixture.add, &fixture);
        try fixture.result;
        try std.testing.expectEqual(@as(usize, 2), timer.arms);
        try std.testing.expect(timeline.resource.full_event_pending);
    }
};

const Fixture = struct {
    realm: runtime.Context,
    timeline: *timing.Timeline,
    result: anyerror!void = {},

    fn add(raw: ?*anyopaque) void {
        const self: *Fixture = @ptrCast(@alignCast(raw.?));
        self.result = self.makeEntry();
    }

    fn makeEntry(self: *Fixture) !void {
        const entry = try interfaces.PerformanceResourceTiming.init(std.testing.allocator, self.realm);
        const generation = runtime.SlabAllocator.generationOf(entry);
        defer entry.releaseIfUnwrapped(generation);
        try timing.initializeEntry(entry, 1, .resource, "https://example.test/resource", 2);
        try timing.addResourceTimingEntry(self.timeline, entry);
    }
};

fn check(scenario: Scenario) !void {
    var trial: Trial = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, Trial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "resource buffer arms one owned zero-delay timer per overflow burst" {
    try check(.burst);
}

test "dropping resource-buffer delivery releases its callback and permits a later burst" {
    try check(.drop);
}

test "failed resource-buffer timer allocation leaves the pending flag clear" {
    try check(.failed);
}

test "a realm without timers leaves resource-buffer delivery retryable" {
    try check(.absent);
}

const CacheScenario = enum { restore, gone, evict_queued };

/// Real kept Windows exercise the document-activity hook without replacing
/// any process-wide implementation. The timer is the only injected service.
const CacheTrial = struct {
    scenario: CacheScenario,
    result: anyerror!void = {},

    fn run(self: *CacheTrial) void {
        self.result = self.check();
    }

    fn check(self: *CacheTrial) !void {
        const allocator = std.testing.allocator;
        const routes = [_]http.Route{
            .{ .path = "/a.html", .content_type = "text/html", .body = "<!doctype html><body>A</body>" },
            .{ .path = "/b.html", .content_type = "text/html", .body = "<!doctype html><body>B</body>" },
        };
        const server = try http.Server.start(allocator, &routes);
        defer server.stop();
        var proxy_buf: [64]u8 = undefined;
        const proxy = try server.proxyUrl(&proxy_buf);
        const browser = try browser_mod.Browser.init(allocator, .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        defer browser.deinit();
        try browser.navigateWithOptions("http://tm4.test/host.html", .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>host</body>", .{ .base_url = "http://tm4.test/host.html" });
        try page.runScript("window.open('http://tm4.test/a.html', '_blank', 'noopener')");
        const host_realm = browser.getRealm() orelse return error.NoRealm;
        const host_window = timing.globalOf(host_realm) orelse return error.NoWindow;
        const host_context = dom.browser_state.browsingContextOf(host_window);
        const navigables = dom.browser_state.navigablesOf(host_realm) orelse return error.NoNavigables;
        var popup: ?*html.BrowsingContext = null;
        var turns: usize = 0;
        while (turns < 500 and popup == null) : (turns += 1) {
            _ = try browser.runEventLoopBlocking(10);
            for (navigables.contexts()) |candidate| {
                if (candidate.parent == null and !candidate.orphaned and !candidate.is_closed and
                    (host_context == null or candidate != host_context.?)) popup = candidate;
            }
        }
        const context = popup orelse return error.NoPopup;
        const realm = try waitForPage(browser, context, "/a.html");
        try evaluate(realm,
            \\performance.clearResourceTimings();
            \\performance.setResourceTimingBufferSize(0);
            \\globalThis.bufferEvents = 0;
            \\performance.onresourcetimingbufferfull = () => {
            \\  ++bufferEvents;
            \\  performance.setResourceTimingBufferSize(10);
            \\};
        );
        const timeline = timing.timelineOf(realm) orelse return error.NoTimeline;
        const window = timing.globalOf(realm) orelse return error.NoWindow;
        try evaluate(realm, "location.href = '/b.html'");
        const second = try waitForPage(browser, context, "/b.html");
        try std.testing.expect(dom.bfcache.holds(window));
        try std.testing.expectEqual(dom.document_activity.Activity.inactive, dom.document_activity.activity(window, runtime.SlabAllocator.generationOf(window)));

        var timer: Timer = .{};
        defer timer.drop();
        const saved_timer = realm.timer;
        defer if (realm.hasEngine()) {
            realm.timer = saved_timer;
        };
        realm.timer = timer.interface();
        // Native reports can arrive while a page is kept. No script is run
        // in the cached realm: only entry creation and its traced edges.
        var fixture: Fixture = .{ .realm = realm, .timeline = timeline };
        for (0..2) |_| {
            try engine.runInRealm(realm, Fixture.add, &fixture);
            try fixture.result;
        }
        try std.testing.expectEqual(@as(usize, 1), timer.arms);
        try std.testing.expectEqual(@as(usize, 2), timeline.resource.secondary_buffer.items.len);
        if (self.scenario == .gone) {
            dom.bfcache.evict(window, null);
            _ = try browser.runEventLoopBlocking(10);
            try std.testing.expectEqual(false, realm.hasEngine());
            timer.run();
            try std.testing.expectEqual(@as(usize, 1), timer.runs);
            try std.testing.expectEqual(@as(usize, 0), timer.drops);
            return;
        }
        timer.run();
        timer.drop(); // Delivery transferred to the task queue: no timer drop.
        try std.testing.expectEqual(@as(usize, 1), timer.runs);
        try std.testing.expectEqual(@as(usize, 0), timer.drops);
        for (0..3) |_| _ = try browser.runEventLoopBlocking(10);
        try std.testing.expect(timeline.resource.full_event_pending);
        try std.testing.expectEqual(@as(usize, 0), timeline.resource.current_size);
        if (self.scenario == .evict_queued) {
            dom.bfcache.evict(window, null);
            _ = try browser.runEventLoopBlocking(10);
            try std.testing.expectEqual(false, realm.hasEngine());
            return;
        }
        try evaluate(second, "history.back()");
        try std.testing.expectEqual(realm, try waitForPage(browser, context, "/a.html"));
        _ = try browser.runEventLoopBlocking(10);
        try std.testing.expect(!timeline.resource.full_event_pending);
        try std.testing.expectEqual(@as(usize, 2), timeline.resource.current_size);
        try evaluate(realm, "if (bufferEvents !== 1) throw Error('two inactive overflows must deliver one event')");
    }
};

fn ignoreError(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn evaluate(realm: runtime.Context, source: []const u8) !void {
    const result = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = ignoreError });
    std.testing.allocator.free(result);
}

fn waitForPage(browser: *browser_mod.Browser, context: *html.BrowsingContext, path: []const u8) !runtime.Context {
    const script = try std.fmt.allocPrint(std.testing.allocator, "location.pathname === '{s}' && document.readyState === 'complete'", .{path});
    defer std.testing.allocator.free(script);
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const window: *runtime.Instance = @ptrCast(@alignCast(context.getActiveWindow() orelse continue));
        const result = try engine.evaluateClassicScriptToString(window.ctx, .{ .utf8 = script }, "", null, std.testing.allocator, .{ .report = ignoreError });
        defer std.testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) {
            _ = try browser.runEventLoopBlocking(10);
            return window.ctx;
        }
    }
    return error.TimedOut;
}

fn checkCache(scenario: CacheScenario) !void {
    var trial: CacheTrial = .{ .scenario = scenario };
    const thread = try std.Thread.spawn(.{}, CacheTrial.run, .{&trial});
    thread.join();
    try trial.result;
}

test "two overflows while inactive deliver one buffer event after reactivation" {
    try checkCache(.restore);
}

test "a buffer timer whose cached realm was evicted drops without running script" {
    try checkCache(.gone);
}

test "evicting a cached realm releases buffer delivery handed to its task queue" {
    try checkCache(.evict_queued);
}
