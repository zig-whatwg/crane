//! A window.open() popup that is closed frees everything it made (lane
//! leaks6, item 1).
//!
//! Lane httpcache1 saw a native Browser test that opened and closed a popup
//! leak one allocation, intermittently - once in two runs, with and without
//! an HTTP cache - and stopped closing popups in its own test to stay green
//! (tmp/plans/httpcache1-red.md), so nothing pinned it. These tests open and
//! close popups in every order that changes who tears what down:
//!
//! - the opener closes the popup after its document has loaded;
//! - the opener closes it at once, while its navigation is still in flight;
//! - the popup closes itself from its own load event;
//! - an about:blank popup (no navigation at all), closed at once;
//! - popups never closed, which the Browser's end tears down (the control).
//!
//! Each run is a Browser of its own on a thread of its own, allocating from a
//! leak-checking DebugAllocator of its own (AGENTS.md: a shared
//! std.testing.allocator makes two Browsers take turns), and each scenario
//! runs several times, since the leak was intermittent. The two-thread
//! variant runs two Browsers that open and close popups at once.
const std = @import("std");
const Browser = @import("browser").Browser;
const http = @import("hc1_http_server.zig");

const routes = [_]http.Route{
    .{ .path = "/popup.html", .body = "<!doctype html><p>popup", .content_type = "text/html", .cache_control = "no-store" },
    .{ .path = "/self-close.html", .content_type = "text/html", .cache_control = "no-store", .body =
    \\<!doctype html><p>closing
    \\<script>addEventListener('load', () => window.close());</script>
    },
};

const page_url = "http://leaks6.test/page.html";

/// How many popups one run opens, and how many runs a scenario makes: the
/// leak was seen once in two runs of one popup.
const popups_per_run = 4;
const runs_per_scenario = 4;

const Scenario = enum {
    close_after_load,
    close_before_load,
    popup_closes_itself,
    about_blank_closed_at_once,
    never_closed,
    /// The opener closes the loaded popup and the Browser ends at once,
    /// before the event loop turns again: what lane httpcache1's test did
    /// (its page answered right after w.close(), and the Browser ended).
    close_then_browser_ends,

    /// An async function's body that opens and closes the popups, its result
    /// the number it opened.
    fn body(self: Scenario) []const u8 {
        return switch (self) {
            .close_after_load =>
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open('/popup.html');
            \\  await loaded(w, '/popup.html');
            \\  w.close();
            \\  await closed(w);
            \\}
            \\return N;
            ,
            .close_before_load =>
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open('/popup.html');
            \\  w.close();
            \\  await closed(w);
            \\}
            \\return N;
            ,
            .popup_closes_itself =>
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open('/self-close.html');
            \\  await closed(w);
            \\}
            \\return N;
            ,
            .about_blank_closed_at_once =>
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open();
            \\  w.close();
            \\  await closed(w);
            \\}
            \\return N;
            ,
            .never_closed =>
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open('/popup.html');
            \\  await loaded(w, '/popup.html');
            \\}
            \\return N;
            ,
            // The popups are closed after the script, from Zig: runOnce.
            .close_then_browser_ends =>
            \\globalThis.popups = [];
            \\for (let i = 0; i < N; ++i) {
            \\  const w = window.open('/popup.html');
            \\  await loaded(w, '/popup.html');
            \\  popups.push(w);
            \\}
            \\return N;
            ,
        };
    }
};

const helpers = std.fmt.comptimePrint("const N = {d};", .{popups_per_run}) ++
    \\const tick = () => new Promise(r => setTimeout(r, 10));
    \\const loaded = async (w, path) => {
    \\  for (let i = 0; i < 500; ++i) {
    \\    await tick();
    \\    try { if (w.document && w.document.readyState === 'complete' && w.location.pathname === path) return; } catch (e) {}
    \\  }
    \\  throw new Error('the popup never loaded');
    \\};
    \\const closed = async (w) => {
    \\  for (let i = 0; i < 500; ++i) {
    \\    if (w.closed) { for (let j = 0; j < 5; ++j) await tick(); return; }
    \\    await tick();
    \\  }
    \\  throw new Error('the popup never closed');
    \\};
;

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

fn runInPage(browser: *Browser, body: []const u8) ![]u8 {
    const launch = try std.mem.concat(browser.allocator, u8, &.{
        "globalThis.answer = 'pending'; (async () => {",
        helpers,
        body,
        "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + e; }); 'ok'",
    });
    defer browser.allocator.free(launch);
    const started = try evaluate(browser, launch);
    browser.allocator.free(started);
    for (0..2000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

/// One run: a Browser that runs `scenario` and ends. Its allocator's leak
/// check is the verdict.
fn runOnce(comptime frames: usize, server: *http.Server, scenario: Scenario) !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = frames }) = .init;
    var leaked = false;
    {
        var proxy_buf: [64]u8 = undefined;
        const proxy = try server.proxyUrl(&proxy_buf);
        const browser = try Browser.init(debug.allocator(), .{
            .persist_storage = false,
            .snapshot_path = "",
            .proxy = .{ .manual = .{ .http = proxy, .no_proxy = "" } },
        });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
        const got = try runInPage(browser, scenario.body());
        defer browser.allocator.free(got);
        try std.testing.expectEqualStrings(std.fmt.comptimePrint("{d}", .{popups_per_run}), got);
        if (scenario == .close_then_browser_ends) {
            // Each close() queues "definitely close"; no task runs again.
            const closing = try evaluate(browser, "popups.forEach(w => w.close()); popups.every(w => w.closed) ? 'closing' : 'open'");
            defer browser.allocator.free(closing);
            try std.testing.expectEqualStrings("closing", closing);
        } else {
            // The closes' last tasks.
            for (0..10) |_| _ = try browser.runEventLoopBlocking(10);
        }
    }
    leaked = debug.deinit() == .leak;
    if (leaked) return error.Leaked;
}

const Outcome = struct {
    failure: ?anyerror = null,
};

fn runOnThread(comptime frames: usize, server: *http.Server, scenario: Scenario, outcome: *Outcome) void {
    runOnce(frames, server, scenario) catch |err| {
        outcome.failure = err;
    };
}

/// `runs_per_scenario` runs of `scenario`, each on a fresh thread; the
/// number that leaked.
fn leakingRuns(server: *http.Server, scenario: Scenario) !usize {
    var leaking: usize = 0;
    for (0..runs_per_scenario) |_| {
        var outcome: Outcome = .{};
        const thread = try std.Thread.spawn(.{}, runOnThread, .{ 0, server, scenario, &outcome });
        thread.join();
        if (outcome.failure) |err| switch (err) {
            error.Leaked => leaking += 1,
            else => return err,
        };
    }
    return leaking;
}

fn expectNoLeak(scenario: Scenario) !void {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    const leaking = try leakingRuns(server, scenario);
    if (leaking != 0) {
        std.debug.print("{s}: {d} of {d} runs leaked\n", .{ @tagName(scenario), leaking, runs_per_scenario });
        return error.Leaked;
    }
}

test "leaks6 popup: the opener closes it after it loaded, and nothing leaks" {
    try expectNoLeak(.close_after_load);
}

test "leaks6 popup: the opener closes it before it loaded, and nothing leaks" {
    try expectNoLeak(.close_before_load);
}

test "leaks6 popup: the popup closes itself from its load event, and nothing leaks" {
    try expectNoLeak(.popup_closes_itself);
}

test "leaks6 popup: an about:blank popup closed at once leaks nothing" {
    try expectNoLeak(.about_blank_closed_at_once);
}

test "leaks6 popup: popups never closed are freed with the Browser (control)" {
    try expectNoLeak(.never_closed);
}

test "leaks6 popup: popups closed just before the Browser ends leak nothing" {
    try expectNoLeak(.close_then_browser_ends);
}

test "leaks6 popup: two Browsers open and close popups at once, and neither leaks" {
    const server = try http.Server.start(std.testing.allocator, &routes);
    defer server.stop();
    var leaking: usize = 0;
    for (0..runs_per_scenario) |_| {
        var a: Outcome = .{};
        var b: Outcome = .{};
        const ta = try std.Thread.spawn(.{}, runOnThread, .{ 0, server, Scenario.close_after_load, &a });
        const tb = try std.Thread.spawn(.{}, runOnThread, .{ 0, server, Scenario.close_before_load, &b });
        ta.join();
        tb.join();
        for ([_]Outcome{ a, b }) |o| if (o.failure) |err| switch (err) {
            error.Leaked => leaking += 1,
            else => return err,
        };
    }
    if (leaking != 0) {
        std.debug.print("two Browsers: {d} of {d} Browser runs leaked\n", .{ leaking, 2 * runs_per_scenario });
        return error.Leaked;
    }
}
