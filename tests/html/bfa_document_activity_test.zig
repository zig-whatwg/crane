//! HTML 8.1.7.1, "a task is runnable if its document is either null or fully
//! active", as the window event loop applies it (lane bfcache-a): a task
//! whose document is not fully active, and may be again, waits in its queue;
//! one whose document never can be again is dropped without running.
//! dom.document_activity classifies a document as fully active, inactive or
//! gone; these tests pin each answer on real documents of a real Browser -
//! every case dropped before this lane must still be gone. No production
//! path makes a document inactive before the back/forward cache keeps one
//! (phase B): the event loop's keep-in-place is pinned by its own unit tests
//! (src/browser/event_loop.zig), with an injected classifier.
//!
//! tests/html is one executable: the engine may already be started.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const browser_mod = @import("browser");

const Activity = dom.document_activity.Activity;
const page_url = "http://bfa.test/page.html";

fn startBrowser() !*browser_mod.Browser {
    return browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
}

/// The platform object `source` evaluates to. Script must keep it alive (a
/// global names it): the instance is borrowed from its wrapper.
fn instanceOf(browser: *browser_mod.Browser, source: []const u8) !*runtime.Instance {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the Browser's event loop until `source` answers true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    var turns: usize = 0;
    while (turns < 1000) : (turns += 1) {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn activityOf(instance: *runtime.Instance) Activity {
    return dom.document_activity.activity(instance, runtime.SlabAllocator.generationOf(instance));
}

fn loadPage(browser: *browser_mod.Browser, html: []const u8) !void {
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML(html, .{ .base_url = page_url });
    try waitFor(browser, "document.readyState === 'complete'");
}

/// A task that counts whether it ran or was dropped.
const Probe = struct {
    ran: u32 = 0,
    dropped: u32 = 0,

    fn run(data: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(data.?));
        self.ran += 1;
    }

    fn drop(data: ?*anyopaque) void {
        const self: *Probe = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
    }

    fn task(self: *Probe, document: *runtime.Instance) runtime.EventLoopTask {
        return .{
            .callback = &run,
            .context = self,
            .drop = &drop,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
        };
    }
};

test "gone: a document a load replaced before it loaded - its task is dropped at the next drain, never run" {
    const browser = try startBrowser();
    defer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const context = browser.current_context orelse return error.NoPage;
    const loop = browser.event_loop orelse return error.NoLoop;

    try context.loadHTML("<!doctype html><p>first", .{ .base_url = page_url });
    // Not loaded yet: its load event's task is still queued.
    const first = try instanceOf(browser, "globalThis.bfaFirst = document");
    try testing.expectEqual(Activity.fully_active, activityOf(first));
    var probe: Probe = .{};
    loop.eventLoop().queueTask(probe.task(first));

    // A load replaces it before it loaded: it is not unloaded (its destroy
    // is a task of its own, DestroyReplacedDocument), but its window lets go
    // of it at once (Window.setDocument: the old document's defaultView is
    // null) - no navigable will show it again.
    try context.loadHTML("<!doctype html><p>second", .{ .base_url = page_url });
    try testing.expectEqual(Activity.gone, activityOf(first));
    _ = loop.runOnceBlocking(0);
    try testing.expectEqual(@as(u32, 0), probe.ran);
    try testing.expectEqual(@as(u32, 1), probe.dropped);
}

test "a fully active page, frame and frame window are fully active" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><iframe id=f srcdoc='<p>frame'></iframe>");
    try waitFor(browser, "document.getElementById('f').contentDocument.readyState === 'complete'");
    try testing.expectEqual(Activity.fully_active, activityOf(try instanceOf(browser, "document")));
    try testing.expectEqual(Activity.fully_active, activityOf(try instanceOf(browser, "globalThis.bfaFrameDoc = document.getElementById('f').contentDocument")));
    try testing.expectEqual(Activity.fully_active, activityOf(try instanceOf(browser, "globalThis.bfaFrameWin = document.getElementById('f').contentWindow")));
}

test "gone: a document whose slot moved on (freed)" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><p>page");
    const document = try instanceOf(browser, "document");
    const generation = runtime.SlabAllocator.generationOf(document);
    try testing.expectEqual(Activity.gone, dom.document_activity.activity(document, generation +% 1));
}

test "gone: a document with no window (never given a browsing context)" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><p>page");
    const made = try instanceOf(browser, "globalThis.bfaMade = document.implementation.createHTMLDocument('x')");
    try testing.expectEqual(Activity.gone, activityOf(made));
    const parsed = try instanceOf(browser, "globalThis.bfaParsed = new DOMParser().parseFromString('<p>', 'text/html')");
    try testing.expectEqual(Activity.gone, activityOf(parsed));
}

test "gone: a frame's document that its navigation destroyed" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><iframe id=f srcdoc='<p>one'></iframe>");
    try waitFor(browser, "document.getElementById('f').contentDocument.body?.textContent === 'one'");
    const old = try instanceOf(browser, "globalThis.bfaOld = document.getElementById('f').contentDocument");
    try testing.expectEqual(Activity.fully_active, activityOf(old));
    _ = try browser.evaluateScript("document.getElementById('f').srcdoc = '<p>two'");
    try waitFor(browser, "document.getElementById('f').contentDocument.body?.textContent === 'two'");
    try testing.expectEqual(Activity.gone, activityOf(old));
}

test "gone: a removed frame's document and window (no navigable), and after its realm ends" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><iframe id=f srcdoc='<p>frame'></iframe>");
    try waitFor(browser, "document.getElementById('f').contentDocument.readyState === 'complete'");
    const frame_document = try instanceOf(browser, "globalThis.bfaDoc = document.getElementById('f').contentDocument");
    const frame_window = try instanceOf(browser, "globalThis.bfaWin = document.getElementById('f').contentWindow");
    const generation = runtime.SlabAllocator.generationOf(frame_document);
    _ = try browser.evaluateScript("document.getElementById('f').remove()");
    // Its navigable is discarded: no navigable has the window, and the
    // document is destroyed.
    try testing.expectEqual(Activity.gone, activityOf(frame_window));
    try testing.expectEqual(Activity.gone, dom.document_activity.activity(frame_document, generation));
    // A task ends the frame's realm ("destroy a child navigable"): still gone.
    _ = try browser.runEventLoopBlocking(20);
    try testing.expectEqual(Activity.gone, dom.document_activity.activity(frame_document, generation));
}

test "gone: a closed popup's window" {
    const browser = try startBrowser();
    defer browser.deinit();
    try loadPage(browser, "<!doctype html><p>page");
    const popup = try instanceOf(browser, "globalThis.bfaPopup = window.open('about:blank', 'bfa-popup')");
    try testing.expectEqual(Activity.fully_active, activityOf(popup));
    _ = try browser.evaluateScript("bfaPopup.close()");
    try waitFor(browser, "bfaPopup.closed");
    _ = try browser.runEventLoopBlocking(20);
    try testing.expectEqual(Activity.gone, activityOf(popup));
}
