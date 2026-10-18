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
//! checks the frame's active document: it must have the page's policy. The
//! round that fails nothing is the control: the frame shows a new document.
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

    fn script(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s').srcdoc = '<p>again</p>';",
            .javascript_url => "document.getElementById('n').src = 'javascript:\"<p>string</p>\"';",
            // A local-scheme URL: "determine navigation params policy
            // container" inherits the initiator's container (step 3).
            .data_url => "document.getElementById('n').src = 'data:text/html,<p>data</p>';",
            // A new iframe's initial about:blank document, which "create a
            // new browsing context and document" step 19.2 gives a clone of
            // its creator's container.
            .new_frame => "window.f = undefined; window.f = document.createElement('iframe'); document.body.appendChild(window.f);",
        };
    }
};

fn sweep(navigation: Navigation, rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
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

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
        const before = frameWindowDocument(page, realm, navigation) catch null;
        const before_generation: u64 = if (before) |d| runtime.SlabAllocator.generationOf(d) else 0;
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript(navigation.script()) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        failing.fail_index = std.math.maxInt(usize);
        const found = frameDocument(page, realm, navigation) catch |err| {
            std.debug.print("{s}: failing allocation {d}: the frame could not be read: {s}\n", .{ @tagName(navigation), round, @errorName(err) });
            return err;
        };
        const policies = switch (found) {
            .none => continue,
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
        // A sweep past the navigation's last allocation fails nothing: the
        // control round. With memory to spare the navigation ran, and the
        // frame shows a new document - a src set on a frame that has a
        // srcdoc attribute changes nothing (HTML 4.8.5), and the javascript:
        // sweep once navigated nothing at all, so passed vacuously.
        if (!failing.has_induced_failure) {
            const after = (frameWindowDocument(page, realm, navigation) catch null) orelse return error.NoFrameDocument;
            if (after == before and runtime.SlabAllocator.generationOf(after) == before_generation) {
                std.debug.print("{s}: the control round navigated nothing\n", .{@tagName(navigation)});
                return error.NothingNavigated;
            }
            return;
        }
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
