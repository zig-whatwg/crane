//! An iframe's new document gets its policy container, or the navigation
//! that would make it stops: never a document with an empty one.
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
//! The sweep: a page with an enforced `<meta>` CSP and a srcdoc iframe,
//! which inherits it (step 2: a clone of its container document's). Each
//! round fails the i-th allocation made while the frame navigates again -
//! to a new srcdoc, or to a javascript: URL whose String is a document - and
//! then checks the frame's active document: it must have the page's policy.
//!
//! Not red on main: neither sweep found a document with an empty container
//! there. The fail-open the clones had shows in a local-scheme frame (data:,
//! blob:: "determine navigation params policy container" step 3 inherits the
//! initiator's clone), and a sweep of an `iframe.src = 'data:...'`
//! navigation panics first, in resolveSrc's `catch unreachable` on out of
//! memory (HTMLIFrameElement.resolveSrc; lane leaks4's report). The Browser's allocator is a FailingAllocator over c_allocator
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
    \\<head><meta http-equiv="Content-Security-Policy" content="img-src 'none'"></head>
    \\<body><iframe id="s" srcdoc="<p>first</p>"></iframe></body>
;

/// What the frame's active document has.
const FrameDocument = union(enum) {
    /// No document: a navigation whose realm could not be made leaves the
    /// frame without one - closed: nothing runs in it.
    none,
    /// A Document with no internal state, so no policy container: what the
    /// frame names after an out-of-memory path outside this test's sites
    /// (reported, not this lane's: lane leaks4's report).
    no_container,
    /// Its CSP list's policies; maxInt for an unenforceable list.
    policies: usize,
};

fn frameDocument(page: anytype, realm: runtime.Context, navigation: Navigation) !FrameDocument {
    const owned = try page.evaluateScript(navigation.frame());
    defer owned.release();
    const iframe = engine.convertToPlatformObject(realm, owned.value) orelse return error.NoIframe;
    // Through the frame's Window, not contentDocument: a data: document is
    // cross-origin, and Zig code runs no access check.
    const window = (try interfaces.HTMLIFrameElement.get_contentWindow(iframe)) orelse return .none;
    const document = interfaces.Window.get_document(window) catch return .none;
    const container = dom.policy_containers.of(document) orelse return .no_container;
    if (container.csp_list.unenforceable) return .{ .policies = std.math.maxInt(usize) };
    return .{ .policies = container.csp_list.policies.items.len };
}

const Navigation = enum {
    srcdoc,
    javascript_url,

    /// The frame the navigation is of.
    fn frame(self: Navigation) []const u8 {
        _ = self;
        return "document.getElementById('s')";
    }

    fn script(self: Navigation) []const u8 {
        return switch (self) {
            .srcdoc => "document.getElementById('s').srcdoc = '<p>again</p>';",
            .javascript_url => "document.getElementById('s').src = 'javascript:\"<p>string</p>\"';",
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
    // The frame inherited the page's policy.
    try testing.expectEqual(FrameDocument{ .policies = 1 }, try frameDocument(page, realm, navigation));

    var round: usize = 0;
    while (round < rounds) : (round += 1) {
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
                std.debug.print("{s}: failing allocation {d}: the frame's document has no policy container (not this test's sites)\n", .{ @tagName(navigation), round });
                continue;
            },
            .policies => |count| count,
        };
        if (policies == 0) {
            std.debug.print("{s}: failing allocation {d} of the navigation left the frame's document with no policy\n", .{ @tagName(navigation), round });
            return error.FailedOpen;
        }
        // A sweep past the navigation's last allocation fails nothing.
        if (!failing.has_induced_failure) break;
    }
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
