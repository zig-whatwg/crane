//! Navigation timing entries whose times WPT read intermittently wrong (lane
//! flaky4), each pinned here without the race that exposed it.
//!
//! 1. Navigation Timing 1's performance.timing.secureConnectionStart on a
//! page whose TLS handshake began in its time origin's coarsening tick.
//!
//! An https navigation's time origin is its fetch's start time (HTML "create
//! and initialize a Document object" step 8), and its connection's times are
//! relative to it - so a handshake that began within the same 100 us tick is
//! a relative 0. That 0 is a moment that happened, as connectStart's is: the
//! legacy attribute must give its epoch time for an https page and 0 only
//! where HTTPS is not used. navigation-timing/test-performance-attributes.sub.html
//! failed 34 of 50 isolated runs (frozen main 0aa6c6c8cf) on exactly this.
//!
//! 2. A service-worker-controlled navigation's fetchStart (the fetch event's
//! dispatch time, Navigation Timing's fetchStart getter step 3) once its body
//! has arrived after the entry was made: the body's end gave the entry back
//! the fetch's post-redirect start, so whether fetchStart followed the
//! worker's activation depended on whether the service worker's response
//! body was all there when the document was made -
//! service-workers/service-worker/navigation-timing-extended.https.html
//! failed 8 of 50 runs.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
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
/// fetch whose connection - DNS, TCP and, when `secure`, TLS - was all
/// obtained at the fetch's start time, the moment the time origin is.
fn navigateWithConnectionAtTimeOrigin(browser: *browser_mod.Browser, url: []const u8, secure: bool) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body>timing", .{ .base_url = url });
    try waitForComplete(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;

    const start = fetch.algorithms.http_fetch.getCurrentTimeMs();
    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    defer timing_info.deinit();
    timing_info.start_time = start;
    timing_info.post_redirect_start_time = start;
    timing_info.final_connection_timing_info = .{
        .domain_lookup_start_time = start,
        .domain_lookup_end_time = start,
        .connection_start_time = start,
        .connection_end_time = start,
        .secure_connection_start_time = if (secure) start else 0,
        .alpn_negotiated_protocol = "http/1.1",
    };
    timing_info.final_network_request_start_time = start;
    timing_info.final_network_response_start_time = start;
    timing_info.end_time = start;
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
    });
}

test "an https page's secureConnectionStart at its time origin is that time, not 0" {
    const browser = try startBrowser();
    defer browser.deinit();
    try navigateWithConnectionAtTimeOrigin(browser, "https://f4-legacy-secure.test/page.html", true);
    // The entry's own view: the handshake began at the time origin.
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, "performance.getEntriesByType('navigation')[0].secureConnectionStart"));
    const connect_start = try evaluateNumber(browser, "performance.timing.connectStart");
    try testing.expect(connect_start > 0);
    // Navigation Timing 1: for an https page, the time before the handshake -
    // here the time origin's epoch time, which connectStart is too.
    try testing.expectEqual(connect_start, try evaluateNumber(browser, "performance.timing.secureConnectionStart"));
    try testing.expectEqual(connect_start, try evaluateNumber(browser, "performance.timing.connectEnd"));
}

test "a page fetched without TLS keeps secureConnectionStart at 0" {
    const browser = try startBrowser();
    defer browser.deinit();
    try navigateWithConnectionAtTimeOrigin(browser, "http://f4-legacy-secure.test/page.html", false);
    try testing.expect(try evaluateNumber(browser, "performance.timing.connectStart") > 0);
    try testing.expectEqual(@as(f64, 0), try evaluateNumber(browser, "performance.timing.secureConnectionStart"));
}

/// A navigation answered by a service worker, whose entry is made while the
/// response's body is still arriving: the fetch started at `start`, the
/// worker took it at `start + 1` and dispatched its fetch event at
/// `start + 400` (after activating), and the body ends later.
fn navigateThroughServiceWorker(browser: *browser_mod.Browser, url: []const u8, start: f64) !void {
    try browser.navigateWithOptions(url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body>controlled", .{ .base_url = url });
    try waitForComplete(browser);
    const realm = browser.getRealm() orelse return error.NoRealm;

    var timing_info: fetch.internal.FetchTimingInfo = .{ .allocator = testing.allocator, .server_timing_headers = .empty };
    defer timing_info.deinit();
    timing_info.start_time = start;
    timing_info.post_redirect_start_time = start;
    timing_info.final_service_worker_start_time = start + 1;
    timing_info.service_worker_timing_info = .{ .start_time = start + 1, .fetch_event_dispatch_time = start + 400 };
    timing_info.final_connection_timing_info = fetch.internal.ConnectionTimingInfo.forReusedConnection(start);
    timing_info.final_network_request_start_time = start + 400;
    timing_info.final_network_response_start_time = start + 401;
    timing_info.end_time = start + 402;
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
        .service_worker_timing = timing_info.service_worker_timing_info,
        .body_arriving = true,
    });
}

test "a service worker's navigation keeps its fetch event's fetchStart once the body has arrived" {
    const browser = try startBrowser();
    defer browser.deinit();
    const start = fetch.algorithms.http_fetch.getCurrentTimeMs();
    try navigateThroughServiceWorker(browser, "https://f4-sw-fetch-start.test/page.html", start);
    const fetch_start = "performance.getEntriesByType('navigation')[0].fetchStart";
    // fetchStart is the fetch event's dispatch time, 400 ms after the time
    // origin (the fetch's start), on the 100 us grid or finer.
    const before = try evaluateNumber(browser, fetch_start);
    try testing.expect(before >= 399.8 and before <= 400.2);
    // The body arrives: the entry's sizes are its, and fetchStart is still
    // the dispatch time, not the fetch's start.
    const realm = browser.getRealm() orelse return error.NoRealm;
    dom.performance_timeline.navigationBodyEnded(realm, 61, 61);
    try testing.expectEqual(@as(f64, 61), try evaluateNumber(browser, "performance.getEntriesByType('navigation')[0].encodedBodySize"));
    try testing.expectEqual(before, try evaluateNumber(browser, fetch_start));
    try testing.expectEqual(@as(f64, 1), @round(try evaluateNumber(browser, "performance.getEntriesByType('navigation')[0].workerStart")));
}
