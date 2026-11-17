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
