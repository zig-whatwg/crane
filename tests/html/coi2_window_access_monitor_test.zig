//! Lane coi2, in a Browser: when a use of a Window may be reported (HTML
//! 7.1.3.3, "check if an access between two browsing contexts should be
//! reported"). Only top-level contexts of one browsing context group in
//! different virtual browsing context groups report their uses of each
//! other, and their virtual IDs part only at "obtain a browsing context to
//! use for a navigation response" step 9.1 - a navigation that a report-only
//! opener policy would have moved to another group. That step starts the
//! Browser's access monitoring (runtime.BrowserScope.window_access_monitored,
//! which the engine reads before it asks anything about a use): Chromium's
//! CrossOriginOpenerPolicyAccessReportManager::InstallAccessMonitorsIfNeeded
//! at the main frame's commit, at the Browser's grain. A Browser where no
//! such navigation happened never pays for the question.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");

fn onFreshThread(comptime body: fn () anyerror!void) !void {
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
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn runUntil(browser: *browser_mod.Browser, page: *browser_mod.Context, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const value = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(value);
        if (std.mem.eql(u8, value, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn loadedPage(browser: *browser_mod.Browser, markup: []const u8) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(markup, .{ .base_url = "https://a.test/opener" });
    try runUntil(browser, page, "document.readyState === 'complete'");
    return page;
}

/// Open a same-origin blob: popup from `page` - it inherits the page's
/// opener policy, initial about:blank document and response alike - and
/// wait for its script to run.
fn openPopup(browser: *browser_mod.Browser, page: *browser_mod.Context, channel: []const u8) !void {
    var script: std.ArrayListUnmanaged(u8) = .empty;
    defer script.deinit(testing.allocator);
    try script.print(testing.allocator,
        \\globalThis.result = null;
        \\globalThis.channel = new BroadcastChannel('{s}');
        \\channel.onmessage = e => {{ result = e.data; }};
        \\globalThis.popup = window.open(URL.createObjectURL(new Blob(["<script>new BroadcastChannel('{s}').postMessage('ran');<\/script>"], {{ type: 'text/html' }})));
    , .{ channel, channel });
    try page.runScript(script.items);
    try runUntil(browser, page, "result !== null");
}

fn reportOnlySplitStartsMonitoring() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><title>opener</title>");
    try testing.expect(!browser.scope.window_access_monitored.load(.monotonic));
    // A `Cross-Origin-Opener-Policy-Report-Only: noopener-allow-popups`
    // page: its popup's navigation from the initial about:blank document
    // would switch groups if the report-only value were enforced, and does
    // not under the enforced unsafe-none (HTML "check if enforcing
    // report-only COOP would require a browsing context group switch" step
    // 3): a new virtual group ID in the same group (step 9.1).
    const document = page.document_instance orelse return error.NoDocument;
    const container = dom.policy_containers.of(document) orelse return error.NoPolicyContainer;
    try container.setOpenerPolicy(.{ .report_only_value = .noopener_allow_popups });
    try openPopup(browser, page, "coi2-split");
    try testing.expect(browser.scope.window_access_monitored.load(.monotonic));
    // The popup kept its opener: a use the monitoring is for.
    const kept = try page.evaluateScriptToString("String(popup.closed)", testing.allocator);
    defer testing.allocator.free(kept);
    try testing.expectEqualStrings("false", kept);
}

test "a report-only opener policy that parts a popup's virtual group starts the Browser's access monitoring" {
    try onFreshThread(reportOnlySplitStartsMonitoring);
}

fn noSplitLeavesMonitoringOff() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><title>opener</title>");
    const document = page.document_instance orelse return error.NoDocument;
    const container = dom.policy_containers.of(document) orelse return error.NoPolicyContainer;
    // Enforced same-origin, no report-only value: the same-origin popup
    // matches, and nothing would switch.
    try container.setOpenerPolicy(.{ .value = .same_origin });
    try openPopup(browser, page, "coi2-no-split");
    try testing.expect(!browser.scope.window_access_monitored.load(.monotonic));
}

test "a popup whose opener policies match leaves the Browser's access monitoring off" {
    try onFreshThread(noSplitLeavesMonitoringOff);
}
