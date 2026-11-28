//! A fetch timestamp taken after the time origin, inside the origin's
//! coarsening tick, reads one tick - never 0, which means "not set" (lane
//! tbfix1).
//!
//! Resource Timing "convert fetch timestamp" returns the relative high
//! resolution coarse time: the moment floored onto Crane's 125 us grid,
//! minus the time origin, which is on the same grid. Crane's navigation
//! starts its fetch about 50-120 us after navigate() is entered (the time
//! origin, as in Chrome and Safari), so the first fetch's start - a
//! same-origin redirect's redirectStart, and on a reused connection
//! fetchStart and secureConnectionStart - read 0 whenever both moments fell
//! in one tick: navigation-timing/nav2-test-redirect-server.html (startTime <
//! redirectStart), secure-connection-start-non-zero.https.html,
//! nav2-test-timing-persistent.html and
//! test-timing-attributes-dependent-on-document-load.html failed or passed
//! by whether the gap crossed a tick (60/60 runs agreed, lane crane-red1).
//!
//! WebKit's networkLoadTimeToDOMHighResTimeStamp (PerformanceResourceTiming.cpp,
//! 306074@main, in Safari 27.2) returns 0 for a time at or before the
//! origin and raises a reduced 0 to one tick; unload, DOM and load marks
//! keep the plain relative time (PerformanceNavigationTiming::
//! millisecondsSinceOrigin). Each moment below is injected, so the tick
//! each one falls in is fixed: no race.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const dom = @import("dom");
const fetch = @import("fetch");
const browser_mod = @import("browser");

/// Crane's coarsening tick in ms (hr_time.coarsen.DEFAULT_RESOLUTION_MS).
const tick: f64 = 0.125;

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
}

fn evaluateNumber(browser: *browser_mod.Browser, source: []const u8) !f64 {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToUnrestrictedDouble(realm, held.borrow());
}

fn waitForComplete(browser: *browser_mod.Browser) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        const held = try browser.evaluateScript("document.readyState === 'complete'");
        defer held.release();
        const realm = browser.getRealm() orelse return error.NoRealm;
        if (engine.toBoolean(realm, held.borrow())) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

/// A moment 10 us past a tick boundary of the clock fetch reads, in ms: a
/// time origin whose tick has 115 us left.
fn originInsideATick() f64 {
    const now = fetch.algorithms.http_fetch.getCurrentTimeMs();
    return @floor(now / tick) * tick + 0.010;
}

const Navigation = struct {
    /// The navigation's start - the time origin - in unsafe ms.
    navigation_start: f64,
    /// Its fetch's start time, in unsafe ms.
    fetch_start: f64,
    /// Same-origin redirects that began with the fetch and ended 1 ms later.
    redirect_count: u16 = 0,
    /// The previous document's unload event, in unsafe ms (0: none).
    unload_event_start: f64 = 0,
    unload_event_end: f64 = 0,
};

/// Load `url`'s page and give its document the navigation timing entry of
/// `navigation`, whose fetch ran on a reused secure connection (every
/// connection time is the fetch's post-redirect start: Fetch "clamp and
/// coarsen connection timing info" step 1).
fn navigate(browser: *browser_mod.Browser, url: []const u8, navigation: Navigation) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body>tbfix1", .{ .base_url = url });
    try waitForComplete(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;

    const start = navigation.fetch_start;
    const post_redirect_start = if (navigation.redirect_count > 0) start + 1 else start;
    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    defer timing_info.deinit();
    timing_info.start_time = start;
    timing_info.post_redirect_start_time = post_redirect_start;
    if (navigation.redirect_count > 0) {
        // Fetch "HTTP-redirect fetch" steps 16-17.
        timing_info.redirect_start_time = start;
        timing_info.redirect_end_time = start + 1;
    }
    timing_info.final_connection_timing_info = fetch.internal.ConnectionTimingInfo.forReusedConnection(post_redirect_start);
    timing_info.final_connection_timing_info.?.alpn_negotiated_protocol = "http/1.1";
    timing_info.final_network_request_start_time = post_redirect_start + 1;
    timing_info.final_network_response_start_time = post_redirect_start + 2;
    timing_info.end_time = post_redirect_start + 3;
    const report: fetch.internal.TimingReport = .{
        .timing_info = &timing_info,
        .url = url,
        .initiator_type = .other,
        .cache_state = "",
        .body_info = .{},
        .response_status = 200,
    };
    try dom.performance_timeline.createNavigationTimingEntry(realm, .{
        .report = &report,
        .redirect_count = navigation.redirect_count,
        .navigation_type = .navigate,
        .navigation_start = navigation.navigation_start,
        .unload_event_start = navigation.unload_event_start,
        .unload_event_end = navigation.unload_event_end,
    });
}

const entry = "performance.getEntriesByType('navigation')[0]";

test "a same-origin redirect that began inside the origin's tick has redirectStart one tick, not 0" {
    const browser = try startBrowser();
    defer browser.deinit();
    // nav2-test-redirect-server.html's case: the first fetch began 49 us
    // after the navigation (crane-red1's p50), in the same tick.
    const origin = originInsideATick();
    try navigate(browser, "https://tbfix1-redirect.test/page.html", .{
        .navigation_start = origin,
        .fetch_start = origin + 0.049,
        .redirect_count = 1,
    });
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, entry ++ ".startTime"));
    // After the origin, so not "no redirect": one tick.
    try testing.expectEqual(tick, try evaluateNumber(browser, entry ++ ".redirectStart"));
    // The redirect ended 1 ms after it began: past the first tick, the
    // plain relative coarse time (origin + 1.049 floors to origin's tick + 1).
    try testing.expectEqual(@as(f64, 1), try evaluateNumber(browser, entry ++ ".redirectEnd"));
    try testing.expectEqual(@as(f64, 1), try evaluateNumber(browser, entry ++ ".fetchStart"));
}

test "a reused secure connection whose fetch began inside the origin's tick has secureConnectionStart one tick" {
    const browser = try startBrowser();
    defer browser.deinit();
    // secure-connection-start-non-zero.https.html on a connection an earlier
    // https file left: every connection time is fetchStart, 33 us after the
    // navigation (crane-red1's p50).
    const origin = originInsideATick();
    try navigate(browser, "https://tbfix1-reused.test/page.html", .{
        .navigation_start = origin,
        .fetch_start = origin + 0.033,
    });
    try testing.expectEqual(tick, try evaluateNumber(browser, entry ++ ".fetchStart"));
    try testing.expectEqual(tick, try evaluateNumber(browser, entry ++ ".secureConnectionStart"));
    try testing.expectEqual(tick, try evaluateNumber(browser, entry ++ ".connectStart"));
    try testing.expectEqual(tick, try evaluateNumber(browser, entry ++ ".domainLookupStart"));
    // A later fetch time is its plain relative coarse time.
    try testing.expectEqual(@as(f64, 1), try evaluateNumber(browser, entry ++ ".requestStart"));
}

test "a fetch timestamp at the time origin stays 0" {
    const browser = try startBrowser();
    defer browser.deinit();
    // The time origin is the fetch's start when the navigation recorded no
    // start of its own, or the same moment: at the origin, not after it.
    const origin = originInsideATick();
    try navigate(browser, "https://tbfix1-at-origin.test/page.html", .{
        .navigation_start = origin,
        .fetch_start = origin,
        .redirect_count = 1,
    });
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, entry ++ ".redirectStart"));
    try testing.expectEqual(@as(f64, 1), try evaluateNumber(browser, entry ++ ".fetchStart"));
}

test "the previous document's unload marks inside the origin's tick keep their plain relative time" {
    const browser = try startBrowser();
    defer browser.deinit();
    // Not fetch timestamps: WebKit converts them with
    // PerformanceNavigationTiming::millisecondsSinceOrigin, which raises
    // nothing.
    const origin = originInsideATick();
    try navigate(browser, "https://tbfix1-unload.test/page.html", .{
        .navigation_start = origin,
        .fetch_start = origin + 0.049,
        .unload_event_start = origin + 0.060,
        .unload_event_end = origin + 0.070,
    });
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, entry ++ ".unloadEventStart"));
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, entry ++ ".unloadEventEnd"));
}
