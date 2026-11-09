//! HTML "close a top-level traversable" -> "destroy a top-level traversable"
//! step 2: for the traversable's documents, "destroy a document and its
//! descendants" - every child navigable's active document is destroyed, and
//! "destroy a document" step 2 is "abort a document", which cancels the
//! fetches it started, firing nothing (dom.document_fetches: each owner's
//! `discard`). A Browser's end ran that only for its top-level document: its
//! iframes' documents ended with their realms, never aborted, so an <img>
//! whose "update the image data" was in flight in a frame document kept its
//! counted hold on the element (HTMLImageElement's load_ref) past every
//! realm's end, and refcount_teardown's check found its tree alive at the
//! agent's end (lane wr1 b7: tests/html/parser_implied_end_tags_test's
//! '<image src=x>' case followed by a nested iframe; refcount 7a's
//! ended-realm net had freed that tree only while its last wrapper outlived
//! the frame's realm). Blink stops a frame's loaders as it detaches it
//! (LocalFrame::DetachImpl: loader_.StopAllLoaders(), then DetachChildren()),
//! Gecko's nsDocShell::Destroy stops its loads before it destroys its
//! children, WebKit's FrameLoader::detachFromParent stops all loaders.
//!
//! Each test runs a real Browser on a thread of its own, on
//! std.testing.allocator: a node left at the agent's end is an error log
//! (refcount_teardown.agentEnded), which fails the test.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "http://example.test/browser-end" });
    return browser;
}

fn imageThenNestedFrame() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context.?;
    // The bisected pair of tests/html/parser_implied_end_tags_test, as that
    // test runs it: an <img> whose update is in flight in a frame document -
    // its fetch cannot finish before the Browser ends - then the frame
    // document replaced (document.open removes the tree; the img's update
    // holds it) by one with a nested iframe. Reading `frame.body` wraps the
    // body alone; P8 drops that unmodified wrapper in a scavenge while the
    // frame's realm lives, so refcount 7a's ended-realm net never fires for
    // the removed tree: only the img's update holds it at the Browser's end.
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe')).contentDocument;
        \\  const seen = [];
        \\  for (const markup of ['<image src=x>', '<iframe><p>x</iframe>y']) {
        \\    frame.open(); frame.write('<!doctype html><body>' + markup); frame.close();
        \\    seen.push(frame.body.innerHTML);
        \\    seen.push(new DOMParser().parseFromString('<!doctype html><body>' + markup, 'text/html').body.innerHTML);
        \\  }
        \\  return seen.join('|');
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("<img src=\"x\">|<img src=\"x\">|<iframe><p>x</iframe>y|<iframe><p>x</iframe>y", result);
    // The Browser ends with the update still in flight: its frame document
    // is destroyed and aborted, the img's hold goes, and the removed tree is
    // freed before the agent ends (else refcount_teardown.agentEnded logs it
    // as alive: an error, which fails this test).
}

test "a Browser's end destroys its frames' documents: an <img> update in flight in a frame document lets its element go" {
    try onFreshThread(imageThenNestedFrame);
}

fn nestedFramesWithPendingFetches() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context.?;
    // Two levels of frames, each document with an image update in flight
    // whose tree document.open then removes - only the update holds it.
    const result = try page.evaluateScriptToString(
        \\(() => {
        \\  const outer = document.body.appendChild(document.createElement('iframe')).contentDocument;
        \\  outer.open(); outer.write('<!doctype html><body><image src=a>'); outer.close();
        \\  const seen = [outer.body.innerHTML];
        \\  outer.open(); outer.write('<!doctype html><body><iframe></iframe>'); outer.close();
        \\  const inner = outer.querySelector('iframe').contentDocument;
        \\  inner.open(); inner.write('<!doctype html><body><p><image src=b></p>'); inner.close();
        \\  seen.push(inner.body.innerHTML);
        \\  inner.open(); inner.write('<!doctype html><body><iframe></iframe>'); inner.close();
        \\  seen.push(inner.body.innerHTML);
        \\  return seen.join('|');
        \\})()
    , testing.allocator);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("<img src=\"a\">|<p><img src=\"b\"></p>|<iframe></iframe>", result);
}

test "a Browser's end destroys every nested frame's document, and their fetches end" {
    try onFreshThread(nestedFramesWithPendingFetches);
}
