//! A frame navigation that runs out of memory leaves its navigable usable:
//! the next navigation, with memory to spare, shows a new document.
//!
//! Lane leaks5 reported a "wedged navigable": after an out-of-memory round
//! of tests/html/iframe_policy_container_oom_test.zig's sweeps, a srcdoc
//! frame (from failing allocation 102) and a javascript: frame (from 91)
//! never navigated again. Lane nav1 measured what stopped them:
//!
//! - srcdoc, from round 102: "allowed to perform a navigation or history
//!   update" (BrowsingContext.allowedToNavigateOrUpdateHistory, 200
//!   navigations per 10 s, Blink's NavigationRateLimiter). The sweep makes
//!   two navigations a round, faster than that; a trace of navigate()'s
//!   returns shows the limiter's at round 102, with the frame otherwise
//!   intact. With the frame's count reset each round (`resetRateLimit`),
//!   every round of the sweep navigates again - including the 83 rounds
//!   whose failure came after the old document had unloaded (no realm for
//!   the new document, "replaceRealm").
//! - javascript:, from 91: a round that fails after the unload leaves the
//!   navigable on its unloaded, destroyed document, and "evaluate a
//!   javascript: URL" runs script in the navigable's active document, which
//!   is no longer fully active - so a javascript: URL does nothing there
//!   (HTML runs no task of a document that is not fully active). Any other
//!   navigation replaces it: this test's recovery for that frame is a data:
//!   URL.
//!
//! What remains, stated: HTML makes the new document before it unloads the
//! old one ("attempt to populate the history entry's document" precedes
//! "deactivate"), so in the spec a failure cannot leave a destroyed active
//! document. Crane unloads before it makes the new document's realm,
//! because that realm takes over the navigable's WindowProxy (the old
//! global must be detached first), so a failure after the unload leaves
//! the destroyed document showing until the next navigation. Staging the
//! realm before the unload is engine teardown order - a lifetime lane's.
//!
//! Each round fails the i-th allocation made while the frame re-navigates,
//! then navigates it again with memory to spare and requires the new
//! document - a different Document, showing that navigation's text. The
//! Browser's allocator is a FailingAllocator over c_allocator, which fails
//! every allocation from the i-th on until the round's event loop turn ends
//! (an out-of-memory path elsewhere may leak; that is not this test's).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const page_html =
    \\<!doctype html>
    \\<body><iframe id="s" srcdoc="<p id=t>first</p>"></iframe><iframe id="n"></iframe></body>
;

const Navigation = enum {
    srcdoc,
    javascript_url,

    fn frame(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s')",
            .javascript_url => "document.getElementById('n')",
        };
    }

    /// The navigation each round fails: the frame to a document whose `p#t`
    /// says `text`.
    fn script(self: Navigation, allocator: std.mem.Allocator, text: []const u8) ![]u8 {
        return switch (self) {
            .srcdoc => std.fmt.allocPrint(allocator, "document.getElementById('s').srcdoc = '<p id=t>{s}</p>';", .{text}),
            .javascript_url => std.fmt.allocPrint(allocator, "document.getElementById('n').src = 'javascript:\"<p id=t>{s}</p>\"';", .{text}),
        };
    }

    /// The navigation that must work afterwards, with memory to spare. A
    /// javascript: URL runs in the frame's active document, which a failed
    /// round may have unloaded already ("evaluate a javascript: URL" needs
    /// it fully active), so the javascript: frame is checked with a data:
    /// URL, a navigation that needs nothing of the document it replaces.
    fn recovery(self: Navigation, allocator: std.mem.Allocator, text: []const u8) ![]u8 {
        return switch (self) {
            .srcdoc => self.script(allocator, text),
            .javascript_url => std.fmt.allocPrint(allocator, "document.getElementById('n').src = 'data:text/html,<p id=t>{s}</p>';", .{text}),
        };
    }
};

/// The frame's Window's document, or null.
fn frameDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !?*runtime.Instance {
    const owned = try page.evaluateScript(navigation.frame());
    defer owned.release();
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return null;
    const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return null;
    return interfaces.Window.get_document(window) catch null;
}

/// Whether the frame's document shows `text` in its p#t - read in Zig, which
/// runs no access check (a data: document is cross-origin to the page).
fn frameShows(page: anytype, realm: runtime.Context, navigation: Navigation, text: []const u8) !bool {
    const document = (try frameDocument(page, realm, navigation)) orelse return false;
    const element = (interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("t")) catch return false) orelse return false;
    var content = (interfaces.Node.get_textContent(element) catch return false) orelse return false;
    defer content.deinit(element.ctx.allocator);
    return std.mem.eql(u8, content.asSlice(), text);
}

/// The frame's browsing context's navigation rate count starts again: a
/// sweep's hundreds of navigations within ten seconds would otherwise hit
/// "allowed to perform a navigation or history update" (200 per 10 s, as
/// Blink's NavigationRateLimiter) - a block that is not this test's.
fn resetRateLimit(page: anytype, realm: runtime.Context, navigation: Navigation) !void {
    const owned = try page.evaluateScript(navigation.frame());
    defer owned.release();
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return;
    const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return;
    const bc = dom.browser_state.browsingContextOf(window) orelse return;
    bc.navigation_rate_count = 0;
}

/// Navigate the frame to `text` with memory to spare and wait for it.
fn navigateAndWait(browser: anytype, page: anytype, realm: runtime.Context, navigation: Navigation, text: []const u8) !bool {
    try resetRateLimit(page, realm, navigation);
    const before = try frameDocument(page, realm, navigation);
    const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
    const script = try navigation.recovery(testing.allocator, text);
    defer testing.allocator.free(script);
    try page.runScript(script);
    for (0..40) |_| {
        _ = try browser.runEventLoopBlocking(50);
        const now = (try frameDocument(page, realm, navigation)) orelse continue;
        if (now == before and runtime.SlabAllocator.generationOf(now) == before_generation) continue;
        if (try frameShows(page, realm, navigation, text)) return true;
    }
    return false;
}

fn sweep(navigation: Navigation, rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // Out-of-memory rounds may leave a tree held (an OOM path elsewhere may leak, which is not this test's).
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "out-of-memory rounds may leave a tree held");
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);
    const realm = browser.getRealm() orelse return error.NoRealm;
    // The control: with memory to spare, the navigation shows its document.
    if (!try navigateAndWait(browser, page, realm, navigation, "control")) {
        std.debug.print("{s}: the control navigation navigated nothing\n", .{@tagName(navigation)});
        return error.NothingNavigated;
    }

    var round: usize = 0;
    var text_buffer: [32]u8 = undefined;
    while (round < rounds) : (round += 1) {
        // The failing round: allocation i of the navigation fails, and every
        // one after it in this turn of the loop.
        const failing_script = try navigation.script(testing.allocator, "failing");
        defer testing.allocator.free(failing_script);
        try resetRateLimit(page, realm, navigation);
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript(failing_script) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        failing.fail_index = std.math.maxInt(usize);
        const induced = failing.has_induced_failure;
        // The navigable is still usable: the next navigation shows its
        // document.
        const text = try std.fmt.bufPrint(&text_buffer, "round {d}", .{round});
        if (!try navigateAndWait(browser, page, realm, navigation, text)) {
            std.debug.print("{s}: after failing allocation {d}, the frame never navigated again\n", .{ @tagName(navigation), round });
            return error.WedgedNavigable;
        }
        // A round past the navigation's last allocation failed nothing.
        if (!induced) return;
    }
    return error.SweepDidNotEnd;
}

test "a srcdoc frame whose re-navigation ran out of memory navigates again" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.srcdoc, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a frame whose javascript: URL navigation ran out of memory navigates again" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.javascript_url, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
