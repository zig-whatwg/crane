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
