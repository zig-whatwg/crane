//! A navigated document's time origin is the navigation's start, before its
//! fetch's (lane flaky6).
//!
//! navigation-timing/secure-connection-start-non-zero.https.html asserts
//! secureConnectionStart > 0 for an https page. On a reused connection Fetch's
//! "clamp and coarsen connection timing info" step 1 makes every connection
//! time the fetch's post-redirect start, so secureConnectionStart is fetchStart
//! - in the spec and in Chrome, Firefox and Safari alike. Crane took the time
//! origin at that same moment (the fetch's start time), so fetchStart and
//! secureConnectionStart were 0 whenever an earlier file in the runner's
//! process had left a connection to the server: 100 of 100 runs after
//! navigation-timing/content-encoding.https.html in one process, 0 of 100
//! alone (frozen main ba98b89087). Chrome and Safari take the time origin when
//! the navigation starts, before the fetch, as Navigation Timing's
//! navigationStart (after prompting to unload) describes it.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const engine = @import("engine");
const dom = @import("dom");
const fetch = @import("fetch");
const browser_mod = @import("browser");

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
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

/// Load `url`'s page and give its document the navigation timing entry of a
/// navigation that started at `navigation_start` (0: not recorded) and whose
/// fetch started at `fetch_start` on a reused connection (every connection
/// time is the fetch's post-redirect start: clamp and coarsen connection
/// timing info, step 1).
fn navigateOnReusedConnection(browser: *browser_mod.Browser, url: []const u8, navigation_start: f64, fetch_start: f64) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body>reused", .{ .base_url = url });
    try waitForComplete(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;

    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    defer timing_info.deinit();
    timing_info.start_time = fetch_start;
    timing_info.post_redirect_start_time = fetch_start;
    timing_info.final_connection_timing_info = fetch.internal.ConnectionTimingInfo.forReusedConnection(fetch_start);
    timing_info.final_connection_timing_info.?.alpn_negotiated_protocol = "http/1.1";
    timing_info.final_network_request_start_time = fetch_start + 1;
    timing_info.final_network_response_start_time = fetch_start + 2;
    timing_info.end_time = fetch_start + 3;
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
        .redirect_count = 0,
        .navigation_type = .navigate,
        .navigation_start = navigation_start,
    });
}

test "a reused connection's secureConnectionStart is fetchStart, after the navigation's start" {
    const browser = try startBrowser();
    defer browser.deinit();
    const navigation_start = fetch.algorithms.http_fetch.getCurrentTimeMs();
    try navigateOnReusedConnection(browser, "https://flaky6-reused.test/page.html", navigation_start, navigation_start + 2);
    const entry = "performance.getEntriesByType('navigation')[0]";
    // The time origin is the navigation's start: its fetch began 2 ms later.
    const fetch_start = try evaluateNumber(browser, entry ++ ".fetchStart");
    try testing.expect(fetch_start >= 1.875 and fetch_start <= 2.125);
    // A reused secure connection's times are fetchStart (Fetch clamp step 1;
    // Blink, Gecko and WebKit agree): not 0.
    try testing.expectEqual(fetch_start, try evaluateNumber(browser, entry ++ ".secureConnectionStart"));
    try testing.expectEqual(fetch_start, try evaluateNumber(browser, entry ++ ".connectStart"));
    try testing.expectEqual(fetch_start, try evaluateNumber(browser, entry ++ ".domainLookupStart"));
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, entry ++ ".startTime"));
}

test "a navigation with no recorded start keeps its fetch's start as its time origin" {
    const browser = try startBrowser();
    defer browser.deinit();
    const fetch_start = fetch.algorithms.http_fetch.getCurrentTimeMs();
    try navigateOnReusedConnection(browser, "https://flaky6-unrecorded.test/page.html", 0, fetch_start);
    // No navigation start (0): the time origin is the fetch's start time, as
    // HTML's "create and initialize a Document object" step 8 reads.
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, "performance.getEntriesByType('navigation')[0].fetchStart"));
}
