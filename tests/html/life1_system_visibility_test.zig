//! HTML 6.2 "Page visibility": a traversable navigable's system visibility
//! state is the user agent's - the platform's `visibility_changed(tab,
//! visibility)` event (docs/platform-protocol.md 7), TabId the top-level
//! traversable's browsing context id, 0 every traversable of the Browser.
//! When it changes, each inclusive descendant navigable's active document
//! gets "update the visibility state" from a task (visibilitychange fires
//! there), and a document made later starts with the traversable's state
//! ("set the initial visibility state", no event). A hidden document has no
//! rendering opportunity; shown again, its frames resume (lane life1).
const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const html = @import("html");
const browser_mod = @import("browser");

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

/// Post `visibility_changed(tab, visibility)` to `browser`, as a platform's
/// observer would: through the Browser's EventSink, on this thread.
fn postVisibility(browser: *browser_mod.Browser, tab: platform.TabId, visibility: platform.Visibility) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const browser_platform = html.platform_state.of(realm) orelse return error.NoBrowserPlatform;
    const event: platform.PlatformEvent = .{ .kind = .visibility_changed, .tab = tab, .visibility = visibility };
    platform.adapter.postEvent(browser_platform, &event);
}

const page_markup =
    \\<!doctype html><body>
    \\<iframe id=f srcdoc="<script>parent.childEvents = []; document.addEventListener('visibilitychange', () => parent.childEvents.push(document.visibilityState));</script>"></iframe>
    \\<script>
    \\globalThis.events = [];
    \\document.addEventListener('visibilitychange', () => events.push(document.visibilityState));
    \\</script>
;

fn hiddenTabHidesItsDocuments() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_markup, .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete' && Array.isArray(globalThis.childEvents)");
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try postVisibility(browser, tab, .hidden);
    // The steps are tasks: nothing has changed when the post returns.
    try expectEval(page, "document.visibilityState", "visible");
    try until(browser, "document.visibilityState === 'hidden' && f.contentDocument.visibilityState === 'hidden'");
    try expectEval(page, "[events.join(), childEvents.join(), document.hidden, f.contentDocument.hidden].join('|')", "hidden|hidden|true|true");

    // The same state again is no change: no second event.
    try postVisibility(browser, tab, .hidden);
    _ = try browser.runEventLoopBlocking(50);
    try expectEval(page, "events.length", "1");

    // Tab 0 is every traversable of the Browser.
    try postVisibility(browser, 0, .visible);
    try until(browser, "document.visibilityState === 'visible' && f.contentDocument.visibilityState === 'visible'");
    try expectEval(page, "[events.join(), childEvents.join()].join('|')", "hidden,visible|hidden,visible");
}

test "the platform's visibility_changed hides each document of its tab from a task, firing visibilitychange" {
    try onFreshThread(hiddenTabHidesItsDocuments);
}

fn otherTabUntouched() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><script>globalThis.events = []; document.addEventListener('visibilitychange', () => events.push(document.visibilityState));</script>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    // A TabId that names no traversable of this Browser changes nothing.
    try postVisibility(browser, tab + 1_000_000, .hidden);
    _ = try browser.runEventLoopBlocking(50);
    try expectEval(page, "[document.visibilityState, events.length].join()", "visible,0");
}

test "visibility_changed for another tab leaves this one visible" {
    try onFreshThread(otherTabUntouched);
}

fn hiddenTabRendersNothing() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    try postVisibility(browser, tab, .hidden);
    try until(browser, "document.visibilityState === 'hidden'");
    // HTML update the rendering step 3: a hidden document has no rendering
    // opportunity, so its animation frame callbacks wait.
    try page.runScript("globalThis.frames_run = 0; requestAnimationFrame(() => frames_run++);");
    _ = try browser.runEventLoopBlocking(100);
    try expectEval(page, "frames_run", "0");
    // Shown again: the callback runs at the next opportunity.
    try postVisibility(browser, tab, .visible);
    try until(browser, "frames_run === 1");
}

test "a hidden tab's documents get no animation frame until the tab is visible again" {
    try onFreshThread(hiddenTabRendersNothing);
}

fn newDocumentStartsHidden() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    try postVisibility(browser, tab, .hidden);
    try until(browser, "document.visibilityState === 'hidden'");
    // A frame inserted now: its initial about:blank and its srcdoc document
    // start with the traversable's system visibility state - set, with no
    // visibilitychange ("set the initial visibility state").
    try page.runScript(
        \\globalThis.f = document.createElement('iframe');
        \\f.srcdoc = "<script>parent.seen = document.visibilityState; parent.changes = 0; document.addEventListener('visibilitychange', () => parent.changes++);</script>";
        \\document.body.append(f);
        \\globalThis.blank = f.contentDocument.visibilityState;
    );
    try until(browser, "globalThis.seen !== undefined");
    _ = try browser.runEventLoopBlocking(50);
    try expectEval(page, "[blank, seen, changes, f.contentDocument.hidden].join()", "hidden,hidden,0,true");
}

test "a document made while its tab is hidden starts hidden, without a visibilitychange" {
    try onFreshThread(newDocumentStartsHidden);
}
