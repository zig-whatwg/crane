//! A realm a navigation replaced lives while script reaches it - whatever
//! becomes of the realm that replaced it (lane rep1 batch 2). HTML "destroy a
//! document" leaves the Window to whoever still holds something of it; a
//! function of the old page that another window keeps still runs in its own
//! realm, and reads its own Window's storage.
//!
//! The host's page: page A's realm is replaced by page B's, B's by C's. Once
//! nothing reaches B's realm the collector takes it - and A's realm, which
//! the engine had hung under B's (E1), must not end with it while a popup
//! still holds a function of A. websockets/unload-a-document/001.html is the
//! popup form of the same case (rep1_popup_owner_test.zig).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

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

fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

fn collect(browser: *browser_mod.Browser) !void {
    for (0..4) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

fn hostPageReplacedTwice() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>A</title>", .{ .base_url = "http://example.test/a" });
    try until(browser, "document.readyState === 'complete'");
    // Page A leaves a function with a popup, which outlives A's document.
    try page.runScript(
        \\sessionStorage.setItem('k', 'v');
        \\globalThis.keeper = window.open('about:blank', 'keeper');
        \\keeper.fromA = function () { return String(sessionStorage.getItem('k')) + ',' + document.title; };
    );
    try page.loadHTML("<!doctype html><title>B</title>", .{ .base_url = "http://example.test/b" });
    try until(browser, "document.title === 'B'");
    try page.loadHTML("<!doctype html><title>C</title>", .{ .base_url = "http://example.test/c" });
    try until(browser, "document.title === 'C'");
    // Nothing reaches B's realm: the collector takes it.
    try collect(browser);
    try expectEval(page, "(() => { const k = window.open('', 'keeper'); try { return k.fromA(); } catch (e) { return e.name; } })()", "v,A");
}

test "the host page's first realm, replaced twice, still runs and reads its own Window after the realm between is collected" {
    try onFreshThread(hostPageReplacedTwice);
}

/// The agent's native contexts (realms), live and detached, after the
/// collector ran: what a chain of replaced realms would keep.
fn realmCount(browser: *browser_mod.Browser) !usize {
    if (engine.capabilities.heap_statistics == .unsupported) return error.SkipZigTest;
    try collect(browser);
    const stats = engine.heapStatistics(browser.agent orelse return error.NoAgent);
    return stats.realm_count;
}

fn hostPageNavigatedOften() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    var url_buf: [64]u8 = undefined;
    var title_buf: [64]u8 = undefined;
    // A few loads first, so what a load leaves once (tables, caches) is in
    // the baseline.
    for (0..5) |i| {
        const url = try std.fmt.bufPrint(&url_buf, "http://example.test/warm{d}", .{i});
        try page.loadHTML("<!doctype html><title>warm</title>", .{ .base_url = url });
    }
    const baseline = try realmCount(browser);
    // 50 more loads; nothing holds a replaced realm. Each replaced realm is
    // hung under its successor (E1) and passes up when that one is collected
    // (endCollectedRealm): none may stay alive under the page for its life.
    for (0..50) |i| {
        const url = try std.fmt.bufPrint(&url_buf, "http://example.test/p{d}", .{i});
        const title = try std.fmt.bufPrint(&title_buf, "<!doctype html><title>p{d}</title>", .{i});
        try page.loadHTML(title, .{ .base_url = url });
    }
    const after = try realmCount(browser);
    if (after > baseline + 2) {
        std.debug.print("realms after 50 loads: {d}, baseline {d}\n", .{ after, baseline });
        return error.ReplacedRealmsKept;
    }
}

test "a host page loaded 50 times with nothing holding its old realms keeps no chain of replaced realms" {
    try onFreshThread(hostPageNavigatedOften);
}
