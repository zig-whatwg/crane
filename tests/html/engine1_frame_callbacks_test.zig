//! Lane engine1, two adapter paths that reach a frame's realm:
//!
//! - A callback whose realm's Window has had its Document destroyed does not
//!   run, though the realm is not detached yet: removing an iframe destroys
//!   its document at once and ends its realm at a task of its own, and a
//!   NodeFilter the frame made for its parent's NodeIterator must not be
//!   called in between (dom/traversal/TreeWalker-acceptNode-filter-cross-
//!   realm-null-browsing-context.html; Chrome and Firefox pass). The
//!   traversal throws instead.
//! - window[i] answers the i-th of the Window's document-tree child
//!   navigables - a shadow tree's iframe is not one - also when the child's
//!   Window is made by the access (Codex row 81 Q8).
//!
//! Each case runs on a thread of its own: a Browser's per-thread state.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

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

fn open(html: []const u8) !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML(html, .{ .base_url = "about:blank" });
    return browser;
}

fn expectText(browser: *browser_mod.Browser, source: []const u8, expected: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    const got = try engine.convertToDOMString(realm, held.borrow(), testing.allocator);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

fn removedFrameFilter() !void {
    const browser = try open("<!doctype html><body><div></div><iframe></iframe></body>");
    defer browser.deinit();
    try expectText(browser,
        \\(() => {
        \\  const iframe = document.querySelector('iframe');
        \\  const frame = iframe.contentWindow;
        \\  frame.eval('var called = false; var filter = function () { called = true; return 1; };');
        \\  const filter = frame.filter;
        \\  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_ELEMENT, filter);
        \\  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_ELEMENT, filter);
        \\  iframe.remove();
        \\  const out = [];
        \\  try { iterator.nextNode(); out.push('iterator returned'); } catch (e) { out.push('iterator threw'); }
        \\  try { walker.firstChild(); out.push('walker returned'); } catch (e) { out.push('walker threw'); }
        \\  out.push('called ' + frame.called);
        \\  return out.join(', ');
        \\})()
    , "iterator threw, walker threw, called false");
}

test "a NodeFilter of a frame whose document was destroyed is not called" {
    try onFreshThread(removedFrameFilter);
}

fn liveFrameFilter() !void {
    const browser = try open("<!doctype html><body><div></div><iframe></iframe></body>");
    defer browser.deinit();
    // The same filter while its frame is in the document runs.
    try expectText(browser,
        \\(() => {
        \\  const frame = document.querySelector('iframe').contentWindow;
        \\  frame.eval('var called = false; var filter = function () { called = true; return 1; };');
        \\  const iterator = document.createNodeIterator(document.body, NodeFilter.SHOW_ELEMENT, frame.filter);
        \\  return iterator.nextNode().localName + ' ' + frame.called;
        \\})()
    , "body true");
}

test "a NodeFilter of a frame still in its document is called" {
    try onFreshThread(liveFrameFilter);
}

fn indexedShadowFrame() !void {
    const browser = try open(
        \\<!doctype html><body><iframe name="first"></iframe><div id="host"><template shadowrootmode="open"><iframe name="shadowed"></iframe></template></div><iframe name="second"></iframe></body>
    );
    defer browser.deinit();
    // window[1] before any contentWindow: the second DOCUMENT-TREE iframe's
    // Window, made by the access - not the shadow tree's iframe, which the
    // parser made between them, so it sits between them among the browsing
    // context's raw children.
    try expectText(browser,
        \\(() => {
        \\  const at1 = window[1];
        \\  const iframes = document.querySelectorAll('iframe');
        \\  return String(at1 === iframes[1].contentWindow);
        \\})()
    , "true");
}

test "window[i] indexes the document-tree child navigables, making the child's Window" {
    try onFreshThread(indexedShadowFrame);
}
