//! Refcount step 7b: a realm's end by counts (lane rc7b; tmp/plans/
//! refcount9-design.md B4, tmp/plans/feature-queue.md "REFCOUNT step 7b").
//!
//! A realm's end lets go of the references the realm itself holds - its
//! Window's on its document, its documents' queued tasks (HTML "destroy a
//! document" step 5), its close watchers, its parsers - and then the counts
//! alone decide what is freed: a tree nothing else holds goes, and a node
//! another realm still holds stays, in its whole tree (decisions D1 and D6),
//! until that hold ends. WebKit and Blink keep such a node past its frame's
//! end; Crane's realm end used to free its document's tree whatever counted
//! it (refcount step 7a's net), and every holder that could name another
//! realm's node needed a generation net for that.
//!
//! Each test counts the live nodes of its Browser (dom.instance_bridge's
//! registry) before it makes a frame and after the frame's realm has ended:
//! every node the frame made must be freed by then - not at the Browser's
//! end, whose final sweep would hide a tree something still holds.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const dom = h.dom;
const onFreshThread = h.onFreshThread;

/// Task turns and collections until the frame's realm - removed, then
/// unreachable - is collected and its end has run (a task), and what its end
/// let go of has been freed (the agent's deferred teardown, between tasks).
fn settle(page: h.Page) !void {
    for (0..4) |_| {
        _ = try page.browser.runEventLoopBlocking(20);
        try page.run("TestUtils.gc(); TestUtils.gc(); 0;");
    }
    _ = try page.browser.runEventLoopBlocking(20);
    _ = try page.browser.runEventLoopBlocking(20);
}

fn liveNodes(page: h.Page) usize {
    return dom.instance_bridge.entryCount(page.browser.scope);
}

/// The page's own nodes, settled: what a test's frame must give back.
fn baseline(page: h.Page) !usize {
    try settle(page);
    return liveNodes(page);
}

fn expectAllFreed(page: h.Page, before: usize, what: []const u8) !void {
    try settle(page);
    const after = liveNodes(page);
    if (after != before) {
        std.debug.print("{s}: {d} node(s) alive before the frame, {d} after its realm ended\n", .{ what, before, after });
        return error.NodesLeftAlive;
    }
}

// ============================================================================
// A cycle across two realms
// ============================================================================

fn crossRealmCycle() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<p id=\"x\"></p>'; 0;");
    const before = try baseline(page);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const fdoc = frame.contentDocument;
        \\  fdoc.body.innerHTML = '<p id="fx"></p><div id="fhost"></div>';
        \\  const froot = fdoc.getElementById('fhost').attachShadow({ mode: 'open' });
        \\  froot.innerHTML = '<span id="ft"></span>';
        \\  // This realm's event: its touch target list names the frame's
        \\  // host (the touch's target is in the host's shadow tree, and the
        \\  // path never enters it) - a native, counted hold of THIS realm on
        \\  // a node of the frame's.
        \\  const touch = new Touch({ identifier: 1, target: froot.firstChild });
        \\  const event = new TouchEvent('ping', { touches: [touch], bubbles: true });
        \\  fdoc.getElementById('fx').dispatchEvent(event);
        \\  // The cycle: the frame's body keeps this realm's event, whose list
        \\  // keeps the frame's tree.
        \\  fdoc.body.keptEvent = event;
        \\  frame.remove();
        \\})();
        \\0;
    );
    // Nothing reaches the cycle: the collector takes the frame's realm and
    // this realm's event together, the realm's end lets go of its document,
    // the event's end of the host - and the counts free the frame's tree.
    try expectAllFreed(page, before, "a cycle through a frame's node and another realm's event");
}

test "a cycle through a removed frame's node and another realm's event's touch target list is collected, and the frame's tree freed, once its realm ended" {
    try onFreshThread(crossRealmCycle);
}

// ============================================================================
// What a held node's tree keeps, and lets go
// ============================================================================

fn heldHostThenReleased() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<p id=\"x\"></p>'; 0;");
    const before = try baseline(page);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const fdoc = frame.contentDocument;
        \\  fdoc.body.innerHTML = '<p id="fx"></p><div id="fhost"></div>';
        \\  const froot = fdoc.getElementById('fhost').attachShadow({ mode: 'open' });
        \\  // The touch's target is made by THIS document, so its wrapper is
        \\  // this realm's; after the dispatch it comes back here, and only
        \\  // the event's touch target list - a native, counted hold - names
        \\  // the frame's host: nothing script reaches keeps the frame's realm.
        \\  globalThis.ft = document.createElement('span');
        \\  froot.appendChild(ft);
        \\  const touch = new Touch({ identifier: 1, target: ft });
        \\  globalThis.keptEvent = new TouchEvent('ping', { touches: [touch], bubbles: true });
        \\  fdoc.getElementById('fx').dispatchEvent(keptEvent);
        \\  document.body.appendChild(ft);
        \\  frame.remove();
        \\})();
        \\0;
    );
    try settle(page);
    // The frame's realm ended (collected); the event's list still names the
    // host, and the host is alive in its whole tree.
    try page.run(
        \\(() => {
        \\  let seen = null;
        \\  const x = document.getElementById('x');
        \\  const listener = (e) => { seen = e.touches[0].target; };
        \\  x.addEventListener('ping', listener);
        \\  x.dispatchEvent(keptEvent);
        \\  x.removeEventListener('ping', listener);
        \\  if (!seen || seen.id !== 'fhost') throw new Error('the list names: ' + (seen && seen.id));
        \\  if (!seen.isConnected) throw new Error('the host is in its document');
        \\  if (seen.ownerDocument.getElementById('fx').localName !== 'p') throw new Error('the frame tree is not whole');
        \\  if (seen.ownerDocument.defaultView !== null) throw new Error('a destroyed document has no window');
        \\})();
        \\0;
    );
    // The event goes, and the span: the last holds on the frame's tree.
    try page.run("keptEvent = null; ft.remove(); ft = null; 0;");
    try expectAllFreed(page, before, "a frame's tree a dropped event held");
}

test "a removed frame's tree another realm's event holds outlives the frame's realm whole, and is freed when the event goes" {
    try onFreshThread(heldHostThenReleased);
}

// ============================================================================
// The realm's own references go at its end
// ============================================================================

fn ownWorkLetGo() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<p id=\"x\"></p>'; 0;");
    const before = try baseline(page);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const fdoc = frame.contentDocument;
        \\  // What the frame's own realm keeps of its nodes: an img's update of
        \\  // the image data (a task), a modal dialog's close watcher (its
        \\  // Window's), a details element's toggle task.
        \\  fdoc.body.innerHTML = '<img src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw=="><dialog id="d">x</dialog><details id="t"><summary>s</summary>y</details>';
        \\  fdoc.getElementById('d').showModal();
        \\  fdoc.getElementById('t').open = true;
        \\  frame.remove();
        \\})();
        \\0;
    );
    try expectAllFreed(page, before, "a frame whose own work held its nodes");
}

test "a removed frame's own work - an img's update, a dialog's close watcher, a toggle task - lets its nodes go at its realm's end" {
    try onFreshThread(ownWorkLetGo);
}

// ============================================================================
// Every way a page's document ends aborts its fetches
// ============================================================================

/// An img whose update of the image data waits on a fetch that never
/// answers before the page goes: the update counts its element (refcount
/// step 5d) until HTML "destroy a document" step 2, "abort a document",
/// discards it (dom.document_fetches). Since refcount step 7b nothing else
/// frees the element: a page end that forgot the abort would keep its whole
/// document to the Browser's end.
const pending_image = "<img src=\"http://example.test/rc7b-never-answers.png\">";

fn pageEndedByNavigation() !void {
    const page = try h.Page.open();
    defer page.close();
    const before = try baseline(page);
    try page.run("document.body.innerHTML = '" ++ pending_image ++ "'; 0;");
    // The Browser opens a fresh top-level traversable: the page before it
    // closes (HTML "destroy a top-level traversable": its documents
    // destroyed, their fetches aborted), and the new page is the old one's
    // twin.
    try page.browser.navigate("about:blank", .window);
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try expectAllFreed(page, before, "a page with a pending img update, navigated away from");
}

test "a page navigated away from with an img update in flight lets the update go: its document is freed before the Browser ends" {
    try onFreshThread(pageEndedByNavigation);
}

fn popupClosedByItsBrowser() !void {
    const page = try h.Page.open();
    defer page.close();
    const before = try baseline(page);
    try page.run(
        \\(() => {
        \\  const w = window.open('about:blank', 'rc7b-popup');
        \\  w.document.body.innerHTML = '
    ++ pending_image ++
        \\';
        \\})();
        \\0;
    );
    var ids: [4]u64 = undefined;
    const open = page.browser.traversableIds(&ids);
    if (open != 2) {
        std.debug.print("open traversables: {d}, expected the page and its popup\n", .{open});
        return error.NoPopup;
    }
    // HTML "close a top-level traversable", as a host closes a tab: its
    // documents destroyed - their fetches aborted - and its browsing
    // context closed.
    try page.browser.closeTraversable(ids[1]);
    try expectAllFreed(page, before, "a popup with a pending img update, closed by its Browser");
}

test "a popup its Browser closes with an img update in flight lets the update go: its document is freed before the Browser ends" {
    try onFreshThread(popupClosedByItsBrowser);
}

// ============================================================================
// An ended realm's event handlers keep nothing
// ============================================================================

/// The platform object `source` evaluates to in the current page's realm,
/// with its slab generation - no wrapper of it kept by the test.
fn instanceAt(page: h.Page, source: []const u8) !struct { instance: *h.runtime.Instance, generation: u64 } {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const instance = h.engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    return .{ .instance = instance, .generation = h.runtime.SlabAllocator.generationOf(instance) };
}

fn handlerClosingOverItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    const before = try baseline(page);
    // An element whose onclick handler closes over the element itself: the
    // handler's function reaches the page's global, the global the element.
    try page.run(
        \\(() => {
        \\  const b = document.body.appendChild(document.createElement('button'));
        \\  b.onclick = () => { b.textContent = 'clicked'; };
        \\  document.body.appendChild(document.createElement('p')).onmouseover = function () { return this; };
        \\})();
        \\0;
    );
    // The page ends; its realm's handlers become weak with it (as at a
    // detach), so its global and its whole DOM are garbage.
    try page.browser.navigate("about:blank", .window);
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try expectAllFreed(page, before, "a page whose element's handler closes over the element, navigated away from");
}

test "a page whose element's event handler closes over the element is freed once navigated away from: its handlers keep nothing" {
    try onFreshThread(handlerClosingOverItsElement);
}

fn handlerClosingOverAnotherPagesElement() !void {
    const page = try h.Page.open();
    defer page.close();
    // A popup - its own top-level traversable, which outlives the page that
    // opened it - with an element the page's handler closes over.
    try page.run(
        \\globalThis.w = window.open('about:blank', 'rc7b-other');
        \\w.document.body.innerHTML = '<p id="other">other</p>';
        \\(() => {
        \\  const other = w.document.getElementById('other');
        \\  document.body.appendChild(document.createElement('button')).onclick = () => other.textContent;
        \\})();
        \\0;
    );
    const other = try instanceAt(page, "w.document.getElementById('other')");
    try page.browser.navigate("about:blank", .window);
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    try settle(page);
    // The ended page's handler let go of everything; the popup's element is
    // its document's, alive and connected.
    if (h.runtime.SlabAllocator.generationOf(other.instance) != other.generation) return error.OtherPagesElementFreed;
    const base = h.dom.instance_bridge.getNodeBase(@ptrCast(other.instance)) orelse return error.OtherPagesElementFreed;
    if (!base.is_connected) return error.OtherPagesElementDisconnected;
}

test "an ended page's handler that closes over another live page's element frees nothing of that page" {
    try onFreshThread(handlerClosingOverAnotherPagesElement);
}
