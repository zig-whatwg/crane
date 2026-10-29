//! Lane coi1, in a Browser:
//!
//! - a popup navigation whose opener policy needs a browsing context group
//!   switch severs the opener: the opener's WindowProxy for the popup reads
//!   `closed` true and no frames, and the new page's `opener` is null and
//!   its name empty (HTML "obtain a browsing context to use for a navigation
//!   response" steps 10-14; COOP's popup tests);
//! - a window's cross-origin isolated capability is its browsing context
//!   group's "concrete" mode AND its document being allowed to use the
//!   "cross-origin-isolated" feature, and a SharedArrayBuffer is cloned
//!   only with it (HTML StructuredSerializeInternal step 14.1).

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

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
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

fn switchSeversTheOpener() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><title>opener</title>");
    // The opener's opener policy, as a `Cross-Origin-Opener-Policy:
    // noopener-allow-popups` response would have given it. A same-origin
    // blob: popup inherits it (a top-level local document), and a
    // "noopener-allow-popups" response always switches from the popup's
    // initial about:blank document.
    const document = page.document_instance orelse return error.NoDocument;
    const container = dom.policy_containers.of(document) orelse return error.NoPolicyContainer;
    container.opener_policy = .{ .value = .noopener_allow_popups };
    try page.runScript(
        \\globalThis.result = null;
        \\globalThis.channel = new BroadcastChannel('coi1');
        \\channel.onmessage = e => { result = e.data; };
        \\const source = "<script>new BroadcastChannel('coi1').postMessage([window.opener === null, JSON.stringify(window.name)].join());<\/script>";
        \\globalThis.popup = window.open(URL.createObjectURL(new Blob([source], { type: 'text/html' })), 'named');
    );
    try runUntil(browser, page, "result !== null");
    // The new page has no opener, and no name.
    try expectEval(page, "result", "true,\"\"");
    // The opener's WindowProxy for the popup is the replaced browsing
    // context's: closed, with no frames.
    try expectEval(page, "[popup.closed, popup.length].join()", "true,0");
}

test "a browsing context group switch severs a popup from its opener" {
    try onFreshThread(switchSeversTheOpener);
}

fn noSwitchKeepsTheOpener() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser, "<!doctype html><title>opener</title>");
    const document = page.document_instance orelse return error.NoDocument;
    const container = dom.policy_containers.of(document) orelse return error.NoPolicyContainer;
    // same-origin: the same-origin blob: popup inherits it, and matching
    // policies of one origin need no switch (blob-popup.https.html).
    container.opener_policy = .{ .value = .same_origin };
    try page.runScript(
        \\globalThis.result = null;
        \\globalThis.channel = new BroadcastChannel('coi1-kept');
        \\channel.onmessage = e => { result = e.data; };
        \\const source = "<script>new BroadcastChannel('coi1-kept').postMessage(String(window.opener !== null));<\/script>";
        \\globalThis.popup = window.open(URL.createObjectURL(new Blob([source], { type: 'text/html' })), 'kept');
    );
    try runUntil(browser, page, "result !== null");
    try expectEval(page, "result", "true");
    try expectEval(page, "[popup.closed, popup.opener === window].join()", "false,true");
    // The opener navigates the popup to about:blank: the document's origin
    // is its initiator's, and its opener policy the initiator's top-level
    // document's - the same policy, of the same origin: no switch
    // (navigate-to-aboutblank.https.html).
    try page.runScript("popup.location.href = 'about:blank';");
    try runUntil(browser, page, "(() => { try { return popup.location.href === 'about:blank'; } catch (e) { return false; } })()");
    try expectEval(page, "[popup.closed, popup.opener === window].join()", "false,true");
}

test "matching opener policies keep a popup's opener" {
    try onFreshThread(noSwitchKeepsTheOpener);
}

fn capabilityFollowsTheGroup() !void {
    const browser = try startBrowser();
    defer browser.deinit();
    const page = try loadedPage(browser,
        \\<!doctype html><title>isolated</title>
        \\<iframe id=allowed srcdoc="<p>allowed</p>"></iframe>
        \\<iframe id=denied allow="cross-origin-isolated 'none'" srcdoc="<p>denied</p>"></iframe>
    );
    try runUntil(browser, page, "[...document.querySelectorAll('iframe')].every(f => f.contentDocument && f.contentDocument.readyState === 'complete')");
    const sab_clone =
        \\(() => { try { new MessageChannel().port1.postMessage(new WebAssembly.Memory({ shared: true, initial: 1, maximum: 1 }).buffer); return 'cloned'; } catch (e) { return e.name; } })()
    ;
    // A group that is not cross-origin isolated: no capability, no clone.
    try expectEval(page, "String(crossOriginIsolated)", "false");
    try expectEval(page, sab_clone, "DataCloneError");

    // The page's group made "concrete" - what a switch for a
    // same-origin-plus-COEP response does.
    const window = page.window_instance orelse return error.NoWindow;
    const bc = dom.browser_state.browsingContextOf(window) orelse return error.NoBrowsingContext;
    bc.cross_origin_isolation_mode = .concrete;
    try expectEval(page, "String(crossOriginIsolated)", "true");
    try expectEval(page, sab_clone, "cloned");
    // The frames joined the group earlier; a frame whose document may not
    // use the feature has no capability.
    for (bc.children.items) |child| child.cross_origin_isolation_mode = .concrete;
    try expectEval(page, "String(document.getElementById('allowed').contentWindow.crossOriginIsolated)", "true");
    try expectEval(page, "String(document.getElementById('denied').contentWindow.crossOriginIsolated)", "false");
    // "logical" keeps origin keying but grants no capability.
    bc.cross_origin_isolation_mode = .logical;
    try expectEval(page, "String(crossOriginIsolated)", "false");
    try expectEval(page, "String(originAgentCluster)", "true");
}

test "crossOriginIsolated is the group's concrete mode and the feature, and gates SharedArrayBuffer cloning" {
    try onFreshThread(capabilityFollowsTheGroup);
}
