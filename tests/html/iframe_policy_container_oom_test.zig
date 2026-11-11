//! An iframe's new document gets its policy container, or the navigation
//! that would make it stops: never a document with an empty one. And an
//! iframe src navigation that runs out of memory starts no navigation; it
//! never panics.
//!
//! HTMLIFrameElement made the clones a child navigation needs with
//! `clone(allocator) catch null` - the source snapshot params' container
//! ("navigate" step 4), "determine navigation params policy container"'s
//! inherited clones (`catch return null`), the one a session history entry
//! keeps, and a javascript: URL's String document's. On out of memory the
//! new document then kept the empty container it is created with: no CSP
//! (lane leaks2's fail-open table). Each failure now stops the navigation
//! (or does not start it), and the frame keeps the document it had.
//!
//! The sweeps: a page with an enforced `<meta>` CSP and two iframes - one
//! with a srcdoc, which inherits it (step 2: a clone of its container
//! document's), and one without. Each round fails the i-th allocation made
//! while a frame navigates again - the srcdoc frame to a new srcdoc; the
//! other to a javascript: URL whose String is a document, or to a data: URL
//! (a local scheme: step 3 inherits the initiator's container) - and then
//! checks the frame's active document: it must have the page's policy. A
//! navigation with memory to spare, before the sweep, is the control: the
//! frame shows a new document.
//!
//! Red on lane/int4 (lane leaks5): both src sweeps panicked in
//! HTMLIFrameElement.resolveSrc, whose every allocation was `catch
//! unreachable`. Lane leaks4's javascript: sweep set src on the srcdoc
//! frame, which changes nothing (HTML 4.8.5 processes src only for a frame
//! with no srcdoc attribute), so it navigated nothing and passed vacuously.
//! The Browser's allocator is a FailingAllocator over c_allocator, which
//! fails every allocation from the i-th on until the round ends (an
//! out-of-memory path elsewhere may leak; that is not this test's).
//!
//! Two sweeps more: the parent's policy also has upgrade-insecure-requests,
//! so every navigation inherits the parent's navigation upgrade tuples (UIR
//! 3.3), whose copy allocates; and a new iframe, whose initial about:blank
//! document inherits its creator's container ("create a new browsing
//! context and document" step 19.2), which out of memory left empty.
//! And a contentWindow read while memory is still out, after each failing
//! round of a srcdoc re-navigation (`sweepContentWindow`).
//!
//! Lane v8up b3e: that sweep used to REQUIRE a round that left the frame
//! with no Window (`NoRoundLeftTheFrameWithoutAWindow`), as proof that it
//! reached the out-of-memory path the null fallback was for. That state was
//! the bug: a navigation whose new realm could not be made released the
//! navigable's realm while its browsing context still answered the old
//! Window as active, kept (or, out of memory again, ended) the old realm,
//! and the next navigation's abort made a DOMException in the ended realm
//! ("a platform object made in a realm no Browser owns": FAIL on chat2,
//! FLAKY on server1). The fix keeps the old realm and Window - the
//! navigation fails, the old document stays - so the sweep now counts that
//! path itself (IFrameIntegration.realm_replacements_failed, at least one
//! round) and asserts more each round: the frame answers a Window, never
//! null; script reads it with memory to spare; and the frame navigates
//! again after the first such round and after the sweep. A round whose new
//! realm failed after the engine handed the WindowProxy on (V8 cannot attach
//! a detached global again) leaves script no Window through the proxy (a
//! SecurityError on member reads): the frame must then recover on its next
//! navigation.
//!
//! Lane leaks5 saw the frames stop navigating partway through these sweeps
//! - the srcdoc frame from failing allocation 102, the javascript: frame
//! from 91 - and took it for a navigable wedged by out of memory. Lane nav1
//! measured both (tests/html/navigable_failed_commit_oom_test.zig): the
//! srcdoc frame from round 102 is the navigation rate limiter ("allowed to
//! perform a navigation or history update", 200 per 10 s, which a sweep's
//! rounds outrun), not a wedge - with the count reset, every round's next
//! navigation succeeds; and the javascript: frame from 91 is a javascript:
//! URL running nothing in the destroyed document a round that failed after
//! the old document unloaded leaves showing (its script needs a fully
//! active document), which any other navigation replaces. So the rounds
//! after those test nothing new here, and the control is the navigation
//! before the sweep, which must show a new document.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const page_html =
    \\<!doctype html>
    \\<head><meta http-equiv="Content-Security-Policy" content="img-src 'none'; upgrade-insecure-requests"></head>
    \\<body><iframe id="s" srcdoc="<p>first</p>"></iframe><iframe id="n"></iframe></body>
;

/// What the frame's active document has.
const FrameDocument = union(enum) {
    /// No document: a navigation whose realm could not be made leaves the
    /// frame without one - closed: nothing runs in it.
    none,
    /// A Document with no internal state, so no policy container: what
    /// lane leaks4 saw the frame name after an out-of-memory path. Closed
    /// now - every CSP decision against such a document is Blocked
    /// (dom.csp_violations.documentCspList, the Window's settings answer
    /// PolicyContainer.unavailable) - and printed with the failing
    /// allocation's stack. Lane leaks5's sweeps on lane/int4 met none.
    no_container,
    /// Its CSP list's policies; maxInt for an unenforceable list.
    policies: usize,
};

/// The frame's Window's document, or null.
fn frameWindowDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !?*runtime.Instance {
    const owned = try page.evaluateScript(navigation.frame());
    defer owned.release();
    // No frame: a new one whose creation ran out of memory.
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return null;
    // Through the frame's Window, not contentDocument: a data: document is
    // cross-origin, and Zig code runs no access check.
    const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return null;
    return interfaces.Window.get_document(window) catch null;
}

fn frameDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !FrameDocument {
    const document = (try frameWindowDocument(page, realm, navigation)) orelse return .none;
    const container = dom.policy_containers.of(document) orelse return .no_container;
    if (container.csp_list.unenforceable) return .{ .policies = std.math.maxInt(usize) };
    return .{ .policies = container.csp_list.policies.items.len };
}

const Navigation = enum {
    srcdoc,
    javascript_url,
    data_url,
    new_frame,

    /// The frame the navigation is of: the srcdoc frame, or the frame with
    /// no srcdoc attribute - a src set on a frame that has one changes
    /// nothing (HTML 4.8.5: "an iframe element ... with no srcdoc attribute
    /// specified has its src attribute set").
    fn frame(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s')",
            .javascript_url, .data_url => "document.getElementById('n')",
            .new_frame => "window.f",
        };
    }

    /// How far apart the allocations a sweep fails are: every one, except
    /// for a new frame, whose creation (a realm, a Window, a document and
    /// its elements) makes so many that a sweep of each takes minutes.
    fn stride(self: Navigation) usize {
        return switch (self) {
            .new_frame => 7,
            else => 1,
        };
    }

    /// Each round sets a new value (`window.k` counts them), so that each
    /// round's document is told apart from the last.
    fn script(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s').srcdoc = '<p>again ' + (window.k = (window.k || 0) + 1) + '</p>';",
            .javascript_url => "document.getElementById('n').src = 'javascript:\"<p>' + (window.k = (window.k || 0) + 1) + '</p>\"';",
            // A local-scheme URL: "determine navigation params policy
            // container" inherits the initiator's container (step 3).
            .data_url => "document.getElementById('n').src = 'data:text/html,<p>' + (window.k = (window.k || 0) + 1) + '</p>';",
            // A new iframe's initial about:blank document, which "create a
            // new browsing context and document" step 19.2 gives a clone of
            // its creator's container.
            // The last round's frame goes first: kept, each one's realm
            // stayed alive and V8 reached its heap limit.
            .new_frame => "if (window.f) window.f.remove(); window.f = undefined; window.f = document.createElement('iframe'); document.body.appendChild(window.f);",
        };
    }
};

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
    // The control: a new frame made with memory to spare.
    if (navigation == .new_frame) {
        try page.runScript(navigation.script());
        _ = try browser.runEventLoopBlocking(50);
    }
    // The frame inherited the page's policy.
    try testing.expectEqual(FrameDocument{ .policies = 1 }, try frameDocument(page, realm, navigation));
    // The control: with memory to spare, the navigation runs - the frame
    // shows a new document with the page's policy. A src set on a frame
    // that has a srcdoc attribute changes nothing (HTML 4.8.5): lane
    // leaks4's javascript: sweep did that, navigated nothing, and passed
    // vacuously.
    if (navigation != .new_frame) {
        const shown = (try frameWindowDocument(page, realm, navigation)) orelse return error.NoFrameDocument;
        const shown_generation = runtime.SlabAllocator.generationOf(shown);
        try page.runScript(navigation.script());
        var navigated = false;
        for (0..40) |_| {
            _ = try browser.runEventLoopBlocking(50);
            const now = (try frameWindowDocument(page, realm, navigation)) orelse continue;
            if (now != shown or runtime.SlabAllocator.generationOf(now) != shown_generation) {
                navigated = true;
                break;
            }
        }
        if (!navigated) {
            std.debug.print("{s}: the control navigation navigated nothing\n", .{@tagName(navigation)});
            return error.NothingNavigated;
        }
        try testing.expectEqual(FrameDocument{ .policies = 1 }, try frameDocument(page, realm, navigation));
    }

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        const before = frameWindowDocument(page, realm, navigation) catch null;
        const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round * navigation.stride();
        page.runScript(navigation.script()) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        failing.fail_index = std.math.maxInt(usize);
        const found = frameDocument(page, realm, navigation) catch |err| {
            std.debug.print("{s}: failing allocation {d}: the frame could not be read: {s}\n", .{ @tagName(navigation), round, @errorName(err) });
            return err;
        };
        const policies = switch (found) {
            // No document: the frame shows nothing, which runs nothing.
            // The sweep's end is still the round that failed nothing - a
            // navigation the rate limiter refused. It used to skip that
            // check, and the frame never showed .none for long: it went on
            // naming the destroyed document a failed commit left, until the
            // collector freed it under the navigable (lane nav2, item 0).
            // Now the Window's teardown clears it, the srcdoc frame shows
            // .none until a navigation commits, and once the limiter refused
            // them all the sweep ran its 4,000 rounds (SweepDidNotEnd).
            .none => {
                if (!failing.has_induced_failure) return;
                continue;
            },
            .no_container => {
                const after = frameWindowDocument(page, realm, navigation) catch null;
                std.debug.print("{s}: failing allocation {d}: the frame's document has no policy container; before {?*} gen {d}, after {?*} gen {d}\n", .{
                    @tagName(navigation), round, before, before_generation, after, if (after) |d| runtime.SlabAllocator.generationOf(d) else 0,
                });
                if (failing.has_induced_failure) std.debug.dumpStackTrace(&failing.getStackTrace());
                continue;
            },
            .policies => |count| count,
        };
        if (policies == 0) {
            std.debug.print("{s}: failing allocation {d} of the navigation left the frame's document with no policy\n", .{ @tagName(navigation), round });
            return error.FailedOpen;
        }
        // A sweep past the navigation's last allocation fails nothing.
        if (!failing.has_induced_failure) return;
    }
    return error.SweepDidNotEnd;
}

test "a srcdoc iframe's re-navigation never commits a document without its container document's policy" {
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

test "a javascript: URL's String document never commits without the policies of the document it replaces" {
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

test "an iframe's src navigation to a data: URL never panics on out of memory, and never commits without the initiator's policy" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.data_url, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

test "a new iframe's initial about:blank document never starts without its creator's policy" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(.new_frame, 4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// `iframe.contentWindow` read while memory is still out, right after a
/// srcdoc re-navigation failed at the i-th allocation: null, or a Window.
///
/// HTMLIFrameElement.get_contentWindow fell back to the integration's
/// WindowProxy - a Zig struct inside IFrameIntegration, not a
/// runtime.Instance - cast to the WindowProxy typedef (*runtime.Instance)
/// when the navigable had no realm context and createChildNavigable failed,
/// or when its realm had no Window. A navigation whose new realm could not
/// be made leaves no realm context (replaceRealm: the old one is released,
/// and attachRealm fails); out of memory, createChildNavigable fails too.
/// Script and Zig callers then read the struct's bytes as a Window's state:
/// probably the "Document with no internal state" lane leaks4 saw through
/// contentWindow (not proven - lane/int4 reads it with memory to spare,
/// and rebuilds the frame).
fn sweepContentWindow(rounds: usize) !void {
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
    // The element, read with memory to spare: it stays in the page.
    const owned = try page.evaluateScript(Navigation.srcdoc.frame());
    defer owned.release();
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return error.NoIframe;
    // Its browsing context and navigable, which live as long as the element.
    const first_window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return error.NoWindow;
    const bc = dom.browser_state.browsingContextOf(first_window) orelse return error.NoBrowsingContext;
    const integration = dom.navigables.integrationOf(@ptrCast(bc)) orelse return error.NoNavigable;

    var round: usize = 0;
    var replacements_failed: usize = 0;
    var proxy_handed_on: usize = 0;
    while (round < rounds) : (round += 1) {
        // "Allowed to perform a navigation" (200 per 10 s) would stop the
        // sweep's navigations partway (lane nav1): not this test's.
        bc.navigation_rate_count = 0;
        const failed_before = integration.realm_replacements_failed;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript(Navigation.srcdoc.script()) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        const induced = failing.has_induced_failure;
        // Still out of memory: what the frame answers now - a Window, never
        // null and never its WindowProxy struct. A navigation that failed
        // left the frame on the Window it had.
        const window = interfaces.HTMLIFrameElement.get_contentWindow(iframe) catch null;
        failing.fail_index = std.math.maxInt(usize);
        const w = window orelse {
            std.debug.print("failing allocation {d}: the frame answers no Window\n", .{round});
            return error.FrameLeftWithoutAWindow;
        };
        if (!std.mem.eql(u8, w.vtable.name, "Window")) {
            std.debug.print("failing allocation {d}: contentWindow answered something that is not a Window\n", .{round});
            return error.NotAWindow;
        }
        const replacement_failed = integration.realm_replacements_failed != failed_before;
        if (replacement_failed) replacements_failed += 1;
        // No realm is ended while the browsing context answers its Window as
        // its active window.
        if (bc.getActiveWindow()) |raw_active| {
            const active: *runtime.Instance = @ptrCast(@alignCast(raw_active));
            if (runtime.instance_lifecycle.isCleanupStarted(active)) {
                std.debug.print("failing allocation {d}: the active window's realm was ended\n", .{round});
                return error.ActiveWindowEnded;
            }
        }
        // With memory to spare: the Window works - script reads its document.
        if (!try frameWindowWorks(page, realm)) {
            // Only a round whose new realm failed AFTER the engine handed
            // the WindowProxy on (window_proxy_of detaches the old global
            // before the new context is made, and V8 cannot attach it
            // again): the frame keeps its old realm and Window, which its
            // own script still reaches, but the proxy reaches no Window
            // until the next navigation. That navigation must complete and
            // give script a Window that works.
            if (!replacement_failed) {
                std.debug.print("failing allocation {d}: the frame's Window does not answer script\n", .{round});
                return error.WindowDoesNotWork;
            }
            // What script observes then, exactly: a proxy with no global,
            // whose member reads throw a SecurityError.
            if (!try frameProxyHasNoGlobal(page, realm)) {
                std.debug.print("failing allocation {d}: the handed-on proxy is not one with no global (a SecurityError on member reads)\n", .{round});
                return error.UnexpectedProxyState;
            }
            proxy_handed_on += 1;
            try navigatesWithMemoryToSpare(browser, page, iframe, bc);
            if (!try frameWindowWorks(page, realm)) {
                std.debug.print("failing allocation {d}: the frame's next Window does not answer script\n", .{round});
                return error.WindowDoesNotWork;
            }
        } else if (replacement_failed and replacements_failed == 1) {
            // The first round whose new realm could not be made: the frame
            // is on its old realm, and a navigation with memory to spare
            // completes.
            try navigatesWithMemoryToSpare(browser, page, iframe, bc);
        }
        if (!induced) break;
    }
    // The sweep reached the path it is for: a round whose new realm could
    // not be made. (It used to require a round that left the frame with no
    // Window at all - the state that path made, which was itself the bug.)
    // At least one round of each kind: a new realm that failed before the
    // WindowProxy hand-on, and one that failed after it.
    if (replacements_failed == proxy_handed_on) return error.NoRoundFailedBeforeTheHandOn;
    if (proxy_handed_on == 0) return error.NoRoundFailedAfterTheHandOn;
    std.log.info("rounds whose new realm could not be made: {d}, of which after the WindowProxy hand-on: {d}", .{ replacements_failed, proxy_handed_on });
    // And after the whole sweep, the frame still navigates.
    try navigatesWithMemoryToSpare(browser, page, iframe, bc);
}

/// Whether script in the page reads the frame's Window: its document's body.
fn frameWindowWorks(page: anytype, realm: runtime.Context) !bool {
    const owned = try page.evaluateScript("(() => { try { const w = document.getElementById('s').contentWindow; return w !== null && w.document !== undefined && w.document.body !== undefined; } catch (e) { return false; } })()");
    defer owned.release();
    return engine.toBoolean(realm, owned.value);
}

/// Whether script sees the frame's WindowProxy with no global behind it as
/// it does today (server1, lane v8up b3e): an object, whose member reads
/// throw a SecurityError - the access check finds no Window behind the
/// proxy and refuses (cross_origin.zig) - and nothing else.
fn frameProxyHasNoGlobal(page: anytype, realm: runtime.Context) !bool {
    const owned = try page.evaluateScript("(() => { const w = document.getElementById('s').contentWindow; if (w === null || typeof w !== 'object') return false; try { w.document; return false; } catch (e) { return e instanceof DOMException && e.name === 'SecurityError'; } })()");
    defer owned.release();
    return engine.toBoolean(realm, owned.value);
}

/// The srcdoc frame navigates with memory to spare: it shows a new document
/// within two seconds.
fn navigatesWithMemoryToSpare(browser: anytype, page: anytype, iframe: *runtime.Instance, bc: anytype) !void {
    bc.navigation_rate_count = 0;
    const before_window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return error.NoWindow;
    const before = interfaces.Window.get_document(before_window) catch null;
    const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
    try page.runScript(Navigation.srcdoc.script());
    for (0..40) |_| {
        _ = try browser.runEventLoopBlocking(50);
        const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse continue;
        const now = interfaces.Window.get_document(window) catch continue;
        if (now != before or runtime.SlabAllocator.generationOf(now) != before_generation) return;
    }
    std.debug.print("the frame did not navigate with memory to spare after a failed round\n", .{});
    return error.NothingNavigated;
}

test "an iframe's contentWindow out of memory after a failed navigation is its Window, never its WindowProxy struct, and the frame navigates again" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweepContentWindow(4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
