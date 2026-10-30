//! A frame navigation that runs out of memory never leaves its navigable
//! showing a document the collector may free.
//!
//! Lane nav2, item 0. tests/html/iframe_policy_container_oom_test.zig's
//! data: URL sweep crashed intermittently on main 6567b4e6578 (1 run in 3 on
//! the chat mirror; Codex row 129's Q24 first): a Bus error hashing an
//! interface name in template_registry.getTemplateForIsolate, under
//! Document.abortDocument's retainValue of the frame's active document, from
//! the next round's HTMLIFrameElement.runBeforeUnload - a wrap of a Document
//! whose slab slot no longer held a Document. Intermittent because the free
//! waited for a collection.
//!
//! This test makes the collection happen: each round fails the i-th
//! allocation of a frame's navigation to a data: URL (every allocation from
//! the i-th on, until the round's turn of the loop ends), records what the
//! navigable shows and its slab generation, collects garbage twice with
//! memory to spare, and reads the navigable again. The document it shows
//! must still be the one recorded - a document the navigable shows is never
//! freed under it. Then the next round navigates the frame again, which
//! aborts that document first (HTML "navigate" step 24.3).
//!
//! The navigable is read through its browsing context, never through
//! iframe.contentWindow, which makes a new child navigable when the frame
//! has no realm (HTMLIFrameElement.get_contentWindow) and would replace the
//! document this test watches.
//!
//! The cause, and the native cases below: a Window's teardown frees its
//! document and calls Navigables.forgetWindow(window, document), which
//! cleared a context's active document only when that context's active
//! window was the Window being torn down. A frame whose commit failed after
//! its realm swap (or whose replacement realm could not be made) had a new
//! active window - or none - and still named the old Window's document.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;
const Navigables = html_core.window.Navigables;

// ----------------------------------------------------------------------------
// Navigables.forgetWindow itself: it compares pointers and reads nothing, so
// stand-in addresses serve as the Windows and documents.
// ----------------------------------------------------------------------------

const StandIns = struct {
    old_window: u8 = 0,
    old_document: u8 = 0,
    new_window: u8 = 0,
    other_window: u8 = 0,
    other_document: u8 = 0,

    fn ptr(byte: *u8) *anyopaque {
        return @ptrCast(byte);
    }
};

test "forgetWindow clears a context's active document whatever its active window is" {
    const allocator = testing.allocator;
    var objects: StandIns = .{};
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer top.deinit();
    // A frame whose commit failed after its realm swap: a new active window,
    // the old Window's document still named.
    const swapped = try BrowsingContext.initChild(allocator, top);
    defer swapped.deinit();
    swapped.active_window = StandIns.ptr(&objects.new_window);
    swapped.active_document = StandIns.ptr(&objects.old_document);
    // A frame whose replacement realm could not be made: no active window.
    const windowless = try BrowsingContext.initChild(allocator, top);
    defer windowless.deinit();
    windowless.active_window = null;
    windowless.active_document = StandIns.ptr(&objects.old_document);
    // A frame naming another Window and document: untouched.
    const other = try BrowsingContext.initChild(allocator, top);
    defer other.deinit();
    other.active_window = StandIns.ptr(&objects.other_window);
    other.active_document = StandIns.ptr(&objects.other_document);
    // The Window's own context: both cleared, as before.
    const own = try BrowsingContext.initChild(allocator, top);
    defer own.deinit();
    own.active_window = StandIns.ptr(&objects.old_window);
    own.active_document = StandIns.ptr(&objects.old_document);

    navigables.forgetWindow(StandIns.ptr(&objects.old_window), StandIns.ptr(&objects.old_document));

    try testing.expect(swapped.active_document == null);
    try testing.expect(swapped.active_window == StandIns.ptr(&objects.new_window));
    try testing.expect(windowless.active_document == null);
    try testing.expect(windowless.active_window == null);
    try testing.expect(other.active_window == StandIns.ptr(&objects.other_window));
    try testing.expect(other.active_document == StandIns.ptr(&objects.other_document));
    try testing.expect(own.active_window == null);
    try testing.expect(own.active_document == null);
}

test "forgetWindow reaches a retired context: it stays on the live list until freeRetired" {
    const allocator = testing.allocator;
    var objects: StandIns = .{};
    var navigables = Navigables.init(allocator);
    defer navigables.deinit();
    const top = try BrowsingContext.initTopLevel(allocator, &navigables);
    defer top.deinit();
    // A removed iframe's context: a Window was active in it, so discard
    // retires it rather than freeing it (freed by navigables.deinit's
    // freeRetired).
    const removed = try BrowsingContext.initChild(allocator, top);
    removed.active_window = StandIns.ptr(&objects.new_window);
    removed.active_document = StandIns.ptr(&objects.old_document);
    try testing.expect(!removed.discard());
    try testing.expectEqual(@as(usize, 1), navigables.retired.items.len);
    var on_live = false;
    for (navigables.live.items) |ctx| {
        if (ctx == removed) on_live = true;
    }
    try testing.expect(on_live);

    navigables.forgetWindow(StandIns.ptr(&objects.old_window), StandIns.ptr(&objects.old_document));
    try testing.expect(removed.active_document == null);
    try testing.expect(removed.active_window == StandIns.ptr(&objects.new_window));
    navigables.forgetWindow(StandIns.ptr(&objects.new_window), null);
    try testing.expect(removed.active_window == null);
}

// ----------------------------------------------------------------------------
// The sweep.
// ----------------------------------------------------------------------------

const page_html =
    \\<!doctype html>
    \\<head><meta http-equiv="Content-Security-Policy" content="img-src 'none'; upgrade-insecure-requests"></head>
    \\<body><iframe id="n"></iframe></body>
;

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    const realm = browser.getRealm() orelse return error.NoRealm;
    const agent = browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    try engine.runInRealm(realm, Collect.steps, agent);
}

/// The page's document, read with memory to spare.
fn pageDocument(browser: *browser_mod.Browser) !*runtime.Instance {
    const held = try browser.evaluateScript("document");
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

/// The frame's navigable: the page document's one child navigable.
fn frameNavigable(browser: *browser_mod.Browser) !@FieldType(dom.navigables.ChildNavigable, "browsing_context") {
    const document = try pageDocument(browser);
    var children = dom.navigables.childNavigablesOf(document, testing.allocator);
    defer children.deinit(testing.allocator);
    if (children.items.len != 1) return error.NoFrameNavigable;
    return children.items[0].browsing_context;
}

fn shownDocument(browser: *browser_mod.Browser) !?*runtime.Instance {
    const navigable = try frameNavigable(browser);
    const document = navigable.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

fn sweep(rounds: usize) !void {
    var failing = std.testing.FailingAllocator.init(std.heap.c_allocator, .{});
    const browser = try browser_mod.Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    // Out-of-memory rounds may leave a tree held (an OOM path elsewhere may leak, which is not this test's).
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "out-of-memory rounds may leave a tree held");
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(page_html, .{ .base_url = "https://example.test/page.html" });
    _ = try browser.runEventLoopBlocking(50);

    // The control: with memory to spare, the frame navigates.
    const first = (try shownDocument(browser)) orelse return error.NoFrameDocument;
    const first_generation = runtime.SlabAllocator.generationOf(first);
    try page.runScript("document.getElementById('n').src = 'data:text/html,<p>control</p>';");
    var navigated = false;
    for (0..40) |_| {
        _ = try browser.runEventLoopBlocking(50);
        const now = (try shownDocument(browser)) orelse continue;
        if (now != first or runtime.SlabAllocator.generationOf(now) != first_generation) {
            navigated = true;
            break;
        }
    }
    if (!navigated) return error.NothingNavigated;

    var round: usize = 0;
    var script_buffer: [128]u8 = undefined;
    // Rounds after which the frame showed no document.
    var without_document: usize = 0;
    while (round < rounds) : (round += 1) {
        // "Allowed to perform a navigation or history update" (200 per 10 s)
        // would stop the rounds otherwise: not this test's.
        (try frameNavigable(browser)).navigation_rate_count = 0;
        const script = try std.fmt.bufPrint(&script_buffer, "document.getElementById('n').src = 'data:text/html,<p>{d}</p>';", .{round});
        failing.has_induced_failure = false;
        failing.fail_index = failing.alloc_index + round;
        page.runScript(script) catch {};
        _ = browser.runEventLoopBlocking(50) catch {};
        failing.fail_index = std.math.maxInt(usize);
        const induced = failing.has_induced_failure;

        // What the navigable shows now; then a collection, with memory to
        // spare. The document it shows is still that document.
        const shown = try shownDocument(browser);
        const shown_generation: u64 = if (shown) |d| runtime.SlabAllocator.generationOf(d) else 0;
        try collect(browser);
        _ = try browser.runEventLoopBlocking(10);
        const after = try shownDocument(browser);
        if (shown) |document| if (after == document and runtime.SlabAllocator.generationOf(document) != shown_generation) {
            std.debug.print("failing allocation {d}: the frame's navigable shows a document the collection freed\n", .{round});
            return error.ShownDocumentFreed;
        };
        // A frame a failed commit left with no document still navigates: the
        // next navigation the rate limiter allows, with memory to spare,
        // commits a new document - through src alone, never contentWindow,
        // which makes a new child navigable of its own.
        if (after == null) {
            without_document += 1;
            (try frameNavigable(browser)).navigation_rate_count = 0;
            const recovery = try std.fmt.bufPrint(&script_buffer, "document.getElementById('n').src = 'data:text/html,<p>recovered {d}</p>';", .{round});
            try page.runScript(recovery);
            var recovered = false;
            for (0..40) |_| {
                _ = try browser.runEventLoopBlocking(50);
                if (try shownDocument(browser) != null) {
                    recovered = true;
                    break;
                }
            }
            if (!recovered) {
                std.debug.print("failing allocation {d}: the frame left with no document never navigated again\n", .{round});
                return error.FrameNeverNavigatesAgain;
            }
        }
        // A round past the navigation's last allocation failed nothing.
        if (!induced) break;
    } else return error.SweepDidNotEnd;
    // The sweep reached the state the recovery is for.
    if (without_document == 0) return error.NoRoundLeftTheFrameWithoutADocument;
}

test "a frame navigation that runs out of memory never leaves its navigable showing a document a collection frees" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(4000) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
