//! A load that replaces a page's loaded document gives the new document a new
//! Window (lane newwin1, B3): HTML "create and initialize a Document object"
//! step 7 - "create a new realm" whose global object is a new Window and whose
//! global this binding is the browsing context's WindowProxy. Step 6 keeps the
//! active window only for the initial about:blank document's successor. The
//! WindowProxy keeps its identity (engine.createWindowRealm .window_proxy_of),
//! and the old page's globals, window listeners and timers end with its
//! Window instead of carrying into the next page (the newdoc lane's
//! follow-up, NEW WINDOW PER REPLACING LOAD).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const dom = @import("dom");
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

/// Run the page's tasks until its document has loaded (bounded at 5 s).
fn untilLoaded(browser: *browser_mod.Browser, page: *browser_mod.Context) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const state = try page.evaluateScriptToString("document.readyState", testing.allocator);
        defer testing.allocator.free(state);
        if (std.mem.eql(u8, state, "complete")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.PageNeverLoaded;
}

const page_one =
    \\<!doctype html><title>one</title><script>
    \\globalThis.pageOneGlobal = 1;
    \\addEventListener('ping', () => { document.title = 'heard by page one'; });
    \\setTimeout(() => { window.name = 'page one timer'; }, 400);
    \\</script>
;

fn replacingLoad() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_one, .{ .base_url = "http://example.test/one" });
    try untilLoaded(browser, page);
    const first_window = page.window_instance orelse return error.NoWindow;
    const first_realm = page.realm orelse return error.NoRealm;
    // What the first page's realm holds of its `window`: the WindowProxy.
    const proxy = try page.evaluateScript("window");
    defer proxy.release();

    try page.loadHTML("<!doctype html><title>two</title><body>two</body>", .{ .base_url = "http://example.test/two" });
    // Step 7: a new Window, in a new realm.
    try testing.expect(page.window_instance.? != first_window);
    try testing.expect(page.realm.? != first_realm);
    // The WindowProxy is the same object: what the first page held of it
    // reaches the new Window and its document.
    const realm = page.realm.?;
    const global = try engine.getProperty(realm, .{ .instance = page.window_instance.? }, "window");
    defer global.release();
    try engine.setProperty(realm, global.value, "heldProxy", proxy.value);
    try expectEval(page, "[heldProxy === window, heldProxy === self, heldProxy.document.title].join()", "true,true,two");
    // The first page's globals, window listeners and timers went with its
    // Window.
    try expectEval(page, "typeof pageOneGlobal", "undefined");
    try page.runScript("dispatchEvent(new Event('ping'));");
    try expectEval(page, "document.title", "two");
    _ = try browser.runEventLoopBlocking(600);
    try expectEval(page, "window.name", "");
}

test "a load that replaces a loaded page gives it a new Window behind the same WindowProxy" {
    try onFreshThread(replacingLoad);
}

fn firstLoadKeepsWindow() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    // The embedder's injection point: what it puts in the realm-creation
    // Window before the first load is the first page's.
    try page.runScript("globalThis.injected = 7;");
    const window = page.window_instance orelse return error.NoWindow;
    try page.loadHTML("<!doctype html><script>globalThis.sawInjected = globalThis.injected;</script>", .{ .base_url = "http://example.test/first" });
    try testing.expectEqual(window, page.window_instance.?);
    try expectEval(page, "String(sawInjected)", "7");
}

test "a fresh page's first load keeps the Window its initial about:blank document had" {
    try onFreshThread(firstLoadKeepsWindow);
}

fn unloadThenNewWindow() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(
        \\<!doctype html><script>
        \\addEventListener('beforeunload', () => { window.opener_log = (window.opener_log || '') + 'b'; });
        \\addEventListener('pagehide', () => { window.name += 'pagehide@' + document.URL + ';'; });
        \\addEventListener('unload', () => { window.name += 'unload;'; });
        \\</script>
    , .{ .base_url = "http://example.test/one" });
    try untilLoaded(browser, page);
    // The old page's unload handlers ran in its own realm, with `window`
    // still its own Window; the name they set is the browsing context's
    // (HTML 7.2.2.1: window.name is the navigable's target name), which the
    // new Window reports - and its script ran after them.
    try page.loadHTML("<!doctype html><script>globalThis.seen = window.name;</script>", .{ .base_url = "http://example.test/two" });
    try expectEval(page, "seen", "pagehide@http://example.test/one;unload;");
}

test "the replaced page unloads in its own Window before the new page's script runs" {
    try onFreshThread(unloadThenNewWindow);
}
