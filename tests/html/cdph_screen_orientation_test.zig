//! A window's screen and its ScreenOrientation (lane cdph;
//! specs/w3c/screen-orientation.md): screen.* and devicePixelRatio answer the
//! tab's screen - a host's emulated device (html_core host_overrides Screen:
//! CDP Emulation.setDeviceMetricsOverride), else the platform's last
//! `screen_changed(tab, screen)`, else its screenInfo; screen.orientation is
//! [SameObject] with [[type]] and [[angle]], its `change` fired by the
//! screen orientation change steps (a changed screen, and HTML "update the
//! visibility state" step 4 for a document visible again); lock() rejects
//! as Chrome desktop does (NotSupportedError), after the common safety
//! checks.
//!
//! Written in the CDP phase (user directive 2026-11-21 5:48 PM ET: implement
//! now, run every test in one later pass).
const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const html = @import("html");
const dom = @import("dom");
const browser_mod = @import("browser");

/// Run `body` on a thread of its own: each test starts its own Browser.
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
    if (run.failure) |err| return err;
}

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
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

/// Two frames of the page, so that every task queued before has run.
fn settle(browser: *browser_mod.Browser, page: *browser_mod.Context) !void {
    try page.runScript("globalThis.settled = false; requestAnimationFrame(() => requestAnimationFrame(() => { settled = true; }));");
    try until(browser, "settled");
}

fn post(browser: *browser_mod.Browser, event: platform.PlatformEvent) !void {
    const realm = browser.getRealm() orelse return error.NoRealm;
    const browser_platform = html.platform_state.of(realm) orelse return error.NoBrowserPlatform;
    platform.adapter.postEvent(browser_platform, &event);
}

const portrait: platform.ScreenInfo = .{
    .width = 1080,
    .height = 1920,
    .avail_width = 1080,
    .avail_height = 1880,
    .color_depth = 24,
    .pixel_depth = 24,
    .device_pixel_ratio = 2,
    .orientation = .portrait_primary,
    .orientation_angle = 90,
};

const page_markup =
    \\<!doctype html><body><iframe id=f></iframe>
    \\<script>
    \\globalThis.changes = [];
    \\screen.orientation.onchange = (e) => changes.push(screen.orientation.type + '@' + screen.orientation.angle + ':' + e.isTrusted + e.bubbles);
    \\globalThis.frameChanges = [];
    \\f.contentWindow.screen.orientation.addEventListener('change', () => frameChanges.push(f.contentWindow.screen.orientation.type));
    \\globalThis.deviceTall = matchMedia('(device-height: 1920px)');
    \\</script>
;

fn loaded(browser: *browser_mod.Browser) !*browser_mod.Context {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_markup, .{ .base_url = "http://example.test/one" });
    try until(browser, "document.readyState === 'complete'");
    return page;
}

fn topOf(browser: *browser_mod.Browser, tab: u64) !*html.BrowsingContext {
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return error.NoNavigables;
    for (navigables.contexts()) |bc| {
        if (bc.parent == null and bc.id == tab) return bc;
    }
    return error.NoTab;
}

fn platformScreenAndChange() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    // The headless platform's screen, and [SameObject].
    try expectEval(page, "[screen.width, screen.height, screen.availHeight, devicePixelRatio, screen.orientation.type, screen.orientation.angle, screen.orientation === screen.orientation, deviceTall.matches].join()", "1920,1080,1040,1,landscape-primary,0,true,false");
    const tab = browser.hostTraversableId() orelse return error.NoTab;

    try post(browser, .{ .kind = .screen_changed, .tab = tab, .screen = portrait });
    try until(browser, "changes.length === 1 && frameChanges.length === 1");
    try expectEval(page, "[screen.width, screen.height, screen.availHeight, devicePixelRatio, changes.join(), frameChanges.join(), deviceTall.matches].join('|')", "1080|1920|1880|2|portrait-primary@90:truefalse|portrait-primary|true");

    // The same screen again is no change: no second event.
    try post(browser, .{ .kind = .screen_changed, .tab = 0, .screen = portrait });
    try settle(browser, page);
    try expectEval(page, "changes.length", "1");
}

test "the platform's screen_changed reaches screen.*, devicePixelRatio, the media queries and one orientation change per document" {
    try onFreshThread(platformScreenAndChange);
}

fn emulatedDeviceWins() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    const top = try topOf(browser, tab);

    // An emulated phone (CDP's setDeviceMetricsOverride with a
    // screenOrientation) wins over the platform's screen.
    top.host_overrides.setScreen(1, .{ .width = 390, .height = 844, .device_pixel_ratio = 3, .orientation = .{ .type = .portrait_primary, .angle = 0 } });
    html.screen_info.changed(top);
    try until(browser, "changes.length === 1");
    try expectEval(page, "[screen.width, screen.availWidth, devicePixelRatio, changes.join()].join('|')", "390|390|3|portrait-primary@0:truefalse");

    // The platform's report under the emulation changes nothing seen.
    try post(browser, .{ .kind = .screen_changed, .tab = tab, .screen = portrait });
    try settle(browser, page);
    try expectEval(page, "[screen.width, changes.length].join()", "390,1");

    // Taken away: the platform's report answers, and the orientation moved.
    top.host_overrides.clearOwnedBy(top.allocator, 1);
    html.screen_info.changed(top);
    try until(browser, "changes.length === 2");
    try expectEval(page, "[screen.width, devicePixelRatio, changes[1]].join('|')", "1080|2|portrait-primary@90:truefalse");
}

test "an emulated device's screen wins over the platform's while set" {
    try onFreshThread(emulatedDeviceWins);
}

fn lockAndUnlock() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    try page.runScript(
        \\globalThis.lockResult = '';
        \\screen.orientation.lock('portrait').then(() => { lockResult = 'resolved'; }, (e) => { lockResult = e.name + ': ' + e.message; });
        \\globalThis.unlockResult = String(screen.orientation.unlock());
    );
    try until(browser, "lockResult !== ''");
    try expectEval(page, "lockResult + '|' + unlockResult", "NotSupportedError: screen.orientation.lock() is not available on this device.|undefined");

    // A hidden tab has no user attention: the common safety checks' step 1.
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    try post(browser, .{ .kind = .visibility_changed, .tab = tab, .visibility = .hidden });
    try until(browser, "document.hidden");
    try page.runScript(
        \\globalThis.hiddenLock = '';
        \\screen.orientation.lock('any').catch((e) => { hiddenLock = e.name; });
        \\try { screen.orientation.unlock(); globalThis.hiddenUnlock = 'returned'; } catch (e) { globalThis.hiddenUnlock = e.name; }
    );
    try until(browser, "hiddenLock !== ''");
    try expectEval(page, "hiddenLock + '|' + hiddenUnlock", "InvalidStateError|InvalidStateError");
}

test "lock() rejects as Chrome desktop does, after the common safety checks; unlock() returns" {
    try onFreshThread(lockAndUnlock);
}

fn visibleAgainHearsTheChange() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loaded(browser);
    const tab = browser.hostTraversableId() orelse return error.NoTab;
    try post(browser, .{ .kind = .visibility_changed, .tab = tab, .visibility = .hidden });
    try until(browser, "document.hidden");
    // A hidden document hears no change ("update the screen orientation"
    // step 1)...
    try post(browser, .{ .kind = .screen_changed, .tab = tab, .screen = portrait });
    try settle(browser, page);
    try expectEval(page, "[changes.length, screen.orientation.type].join()", "0,landscape-primary");
    // ...until it is visible again: HTML "update the visibility state" step
    // 4 runs the change steps, once.
    try post(browser, .{ .kind = .visibility_changed, .tab = tab, .visibility = .visible });
    try until(browser, "!document.hidden && changes.length === 1");
    try settle(browser, page);
    try expectEval(page, "[changes.join(), frameChanges.join()].join('|')", "portrait-primary@90:truefalse|portrait-primary");
}

test "a document visible again hears the orientation change it missed, once" {
    try onFreshThread(visibleAgainHearsTheChange);
}
