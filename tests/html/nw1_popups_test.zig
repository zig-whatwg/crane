//! A popup belongs to the user agent, not to the Window that opened it (HTML
//! 7.3.1.2: top-level traversables are the user agent's; window.opener is the
//! opener BROWSING CONTEXT's WindowProxy). Once a load gives the opener's
//! navigable a new Window (lane newwin1, B3/B5), the popups the old Window
//! opened move with the navigable (B7): the new Window keeps them, their
//! realms follow the opener's WindowProxy (engine WindowRealmOptions.auxiliary,
//! E2), and the realm their next document's realm is made under is the
//! opener's current one - never the realm the opener's navigation replaced.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");
const runtime = @import("runtime");

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
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
    // No snapshot: the startup path JavaScriptCore runs on.
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Run the page's tasks until `condition` (a script) is true, bounded at 5 s.
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

/// Collect, and let the tasks a collection queues run - a detached realm's
/// end among them - a few times over.
fn collect(browser: *browser_mod.Browser) !void {
    for (0..3) |_| {
        const page = browser.current_context orelse return error.NoPage;
        try page.runScript("TestUtils.gc(); TestUtils.gc();");
        _ = try browser.runEventLoopBlocking(20);
    }
}

fn popupOutlivesOpenersLoad() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    // The popup realm outlives its opener load on purpose; its nodes are the final sweep's.
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "a popup outlives the load of its opener, which is what this tests");
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><title>one</title>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    try page.runScript("globalThis.popup = window.open('about:blank', 'kept'); popup.marker = 'popup';");
    const held = try page.evaluateScript("popup");
    defer held.release();

    // The opener's navigable gets a new Window; the old one's realm is let
    // go and collected.
    try page.loadHTML("<!doctype html><title>two</title>", .{ .base_url = "http://example.test/two" });
    try collect(browser);
    const realm = page.realm orelse return error.NoRealm;
    const global = try engine.getProperty(realm, .{ .instance = page.window_instance.? }, "window");
    defer global.release();
    try engine.setProperty(realm, global.value, "heldPopup", held.value);
    // The popup lives on, and its opener is the navigable's WindowProxy -
    // the new Window.
    try expectEval(page, "[heldPopup.closed, heldPopup.marker, heldPopup.opener === window].join()", "false,popup,true");
    // Its first document replaces its initial about:blank one and keeps the
    // Window (step 6); the next needs a new realm made under its opener's -
    // the opener's current realm, not the one its load replaced.
    try page.runScript("heldPopup.location.href = 'javascript:\"<p id=p>next</p>\"';");
    try until(browser, "heldPopup.document.getElementById('p') !== null");
    try expectEval(page, "typeof heldPopup.marker", "string");
    try page.runScript("heldPopup.location.href = 'javascript:\"<p id=q>after</p>\"';");
    try until(browser, "heldPopup.document.getElementById('q') !== null");
    try expectEval(page, "[typeof heldPopup.marker, heldPopup.opener === window].join()", "undefined,true");
}

test "a popup outlives a load that gives its opener's navigable a new Window, and its next realm is made under the opener's current one" {
    try onFreshThread(popupOutlivesOpenersLoad);
}
