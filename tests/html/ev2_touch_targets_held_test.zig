//! A TouchEvent's touch targets stay alive, and stay themselves, while the
//! event's dispatch and the event itself need them (lane ev2, the queue's
//! "From lane lk1" item 1).
//!
//! DOM 2.9 "dispatch" retargets the event's touch target list against every
//! item it appends to the path, and "invoke" step 5 sets the event's list to
//! the item's before its listeners run; Touch's target getter reads that
//! list while the event is dispatched (Touch Events, "Retargeting"). A
//! touch whose target is in a shadow tree the path does not enter is
//! retargeted to the shadow HOST - a node that is on no item of the path,
//! and that the touch itself does not hold once its target has left that
//! shadow tree. WebKit's EventContext keeps the retargeted touches counted
//! (`RefPtr<TouchList> m_touches`, Source/WebCore/dom/EventContext.h) and
//! the TouchEvent keeps its lists counted after dispatch; Gecko's chain item
//! keeps `mRetargetedTouchTargets`, an array of `RefPtr<EventTarget>`
//! (dom/events/EventDispatcher.cpp; reference only, MPL).
//!
//! Each test's host leaves the document, script drops it, the collector
//! runs, and 500 new divs with the id NEWCOMER are made: a freed host's slab
//! slot and State block go to one of them, so a touch target read after the
//! host was freed reads "NEWCOMER" - or, where the read finds the block
//! still free, panics in this Debug build with "a liveness test read a
//! FREED node block" (lane uaf1's instrument).
//!
//! WHAT THE FIRST TEST WAS SHOWN TO CATCH: under the dispatch, nothing is
//! freed while a callback is on the stack (runtime.gc.DeferredTeardown's
//! algorithm depth), so the test passes whether or not the path holds its
//! touch targets. With the queue made to run what it owes at every binding
//! exit (lane lk1's M-depth mutation, made in a pool mirror only) and the
//! path's references on its touch targets taken out (`DispatchPath.hold`),
//! the target's listener reads the freed inner host; with the path's touch
//! targets counted it passes under that mutation too. The event's own list
//! is no help there: while the window's capturing listener runs it names
//! the outer host. The listener drops the host in a function of its own
//! (`dropInner`): the temporary that names the host stays in a register of
//! the frame that made it, and a collection under that frame keeps it.
//!
//! THE SECOND TEST fails on main as it is (server1 and chat2.local,
//! 2026-11-16: the second dispatch read "NEWCOMER"): between two dispatches
//! nothing kept the host the event's own touch target list named.
//!
//! THE THIRD TEST is a realm's end by counts (refcount step 7b): the frame's
//! realm ends - its iframe removed, the collector takes the realm - while
//! only the event's list (a holder of THIS realm) names the frame's host.
//! Under step 7a the realm's end freed its document's tree whatever counted
//! it, so the list's reference alone left the host freed (server1, with the
//! list counted and no net: the third dispatch read "NEWCOMER"), and the
//! list emptied itself through a generation net. Since 7b the realm's end
//! drops only the realm's own references and the counts decide: the list's
//! reference keeps the host, and with it its whole tree (decisions D1 and
//! D6 - Blink traces a node's parent, Gecko's mParent is owning; HTML
//! "destroy a document" removes no child), so the host is still in the
//! frame's Document and reads connected: 'x:fhost:true'. The three browsers
//! agree (probe, 2026-11-17, Chrome 157, Firefox 159, Safari 27 - TouchEvent
//! is not exposed on desktop, so the holders were a script reference, a
//! StaticRange and a Range): a shadow host of a removed iframe's document,
//! read after the frame's removal and a collection, is connected, its
//! parent the frame's body, its document's defaultView null.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

/// `collect()` is two full collections; `churn()` makes 500 divs (the
/// host's kind) with the id NEWCOMER; `read(event)` is the first touch's
/// target's id and whether it is connected; `expect` compares a log.
const prelude =
    \\globalThis.log = [];
    \\globalThis.kept = [];
    \\globalThis.collect = () => { TestUtils.gc(); TestUtils.gc(); };
    \\globalThis.churn = () => {
    \\  for (let i = 0; i < 500; i++) {
    \\    const n = document.createElement('div');
    \\    n.id = 'NEWCOMER';
    \\    kept.push(n);
    \\  }
    \\};
    \\globalThis.read = (event) => {
    \\  const target = event.touches[0].target;
    \\  return target.id + ':' + target.isConnected;
    \\};
    \\globalThis.expect = (got, want, what) => {
    \\  if (JSON.stringify(got) !== JSON.stringify(want)) throw new Error(what + ': ' + JSON.stringify(got) + ', expected ' + JSON.stringify(want));
    \\};
    \\// The touch's own target leaves the host's shadow tree, so the touch no
    \\// longer keeps the host; the host leaves the document, and script keeps
    \\// nothing of it - not a register of this frame, which ends here.
    \\globalThis.dropHost = () => {
    \\  document.body.appendChild(touchNode);
    \\  document.getElementById('host').remove();
    \\};
    \\// A host in the document with a span in its open shadow tree, and a
    \\// target outside that tree: the span is retargeted to the host on every
    \\// item of the target's path. Script keeps the span, never the host.
    \\document.body.innerHTML = '<p id="x"></p><div id="host"></div>';
    \\(() => {
    \\  const root = document.getElementById('host').attachShadow({ mode: 'open' });
    \\  root.innerHTML = '<span id="t"></span>';
    \\  globalThis.touchNode = root.firstChild;
    \\})();
    \\0;
;

/// A task turn, twice: what a collection left owed (the teardown queue)
/// runs.
fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
    _ = try page.browser.runEventLoopBlocking(20);
}

// ============================================================================
// The path's touch targets, under the dispatch
// ============================================================================

fn pathKeepsItsTouchTargets() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  // An outer host in the document; in its shadow tree the target and
        \\  // an inner host; in the inner host's shadow tree the touch's own
        \\  // target. For the items in the outer shadow tree the touch is
        \\  // retargeted to the INNER host - on no item of the path; for the
        \\  // items in the document, to the outer host.
        \\  const outer = document.body.appendChild(document.createElement('div'));
        \\  outer.id = 'outer';
        \\  const outerRoot = outer.attachShadow({ mode: 'open' });
        \\  outerRoot.innerHTML = '<p id="inner-target"></p><div id="inner"></div>';
        \\  const innerRoot = outerRoot.getElementById('inner').attachShadow({ mode: 'open' });
        \\  innerRoot.innerHTML = '<span id="deep"></span>';
        \\  // Script keeps the touch's target and nothing else: this frame,
        \\  // whose registers name the inner host and its shadow root, ends
        \\  // before the dispatch.
        \\  globalThis.deepTouchNode = innerRoot.firstChild;
        \\})();
        \\// The touch's own target leaves the inner shadow tree, so the touch
        \\// no longer keeps the inner host; the inner host leaves the outer
        \\// shadow tree, and script keeps nothing of it - not a register of
        \\// this frame, which ends here.
        \\globalThis.dropInner = () => {
        \\  document.body.appendChild(deepTouchNode);
        \\  document.getElementById('outer').shadowRoot.getElementById('inner').remove();
        \\};
        \\(() => {
        \\  // The capturing listener at the window runs first, with the last
        \\  // item's touch target list - the outer host - as the event's own:
        \\  // from here to the target's listener only the path's touch target
        \\  // lists name the inner host.
        \\  window.addEventListener('ping', function (event) {
        \\    log.push('window:' + read(event));
        \\    dropInner();
        \\    collect();
        \\    // One more binding's return after the collections.
        \\    void document.title;
        \\    churn();
        \\    collect();
        \\    void document.title;
        \\  }, true);
        \\  const target = document.getElementById('outer').shadowRoot.getElementById('inner-target');
        \\  target.addEventListener('ping', (event) => log.push('target:' + read(event)));
        \\  document.body.addEventListener('ping', (event) => log.push('body:' + read(event)));
        \\  const touch = new Touch({ identifier: 1, target: deepTouchNode });
        \\  target.dispatchEvent(new TouchEvent('ping', { touches: [touch], bubbles: true, composed: true }));
        \\})();
        \\// The path was built before the first listener: the target's item
        \\// names the inner host, whatever happened to it since.
        \\expect(log, ['window:outer:true', 'target:inner:false', 'body:outer:true'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(document.getElementById('outer').shadowRoot.getElementById('inner'), null, 'the inner host is out of its tree');
        \\0;
    );
}

test "a TouchEvent's path keeps the shadow host a touch was retargeted to for its later items, after the touch's target left that host's tree and script dropped it" {
    try onFreshThread(pathKeepsItsTouchTargets);
}

// ============================================================================
// The event's touch target list, between two dispatches
// ============================================================================

fn eventKeepsItsTouchTargetList() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const x = document.getElementById('x');
        \\  x.addEventListener('ping', (event) => log.push('x:' + read(event)));
        \\  const touch = new Touch({ identifier: 1, target: touchNode });
        \\  globalThis.keptEvent = new TouchEvent('ping', { touches: [touch], bubbles: true });
        \\  x.dispatchEvent(keptEvent);
        \\})();
        \\expect(log, ['x:host:true'], 'the first dispatch');
        \\// DOM dispatch step 11 clears the event's touch target list only when
        \\// clearTargets is true, and the host is in no shadow tree: the list
        \\// keeps the last item's run - the host. The touch's own target now
        \\// leaves the host's shadow tree, the host leaves the document, and
        \\// script keeps nothing of it: only the event's list names it.
        \\dropHost();
        \\collect();
        \\0;
    );
    // The collected tree's teardown runs between tasks.
    try turn(page);
    try page.run(
        \\collect();
        \\churn();
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\// A second dispatch starts from the list the first left (dispatch
        \\// step 6.1's touchTargets): the host, retargeted against the target.
        \\document.getElementById('x').dispatchEvent(keptEvent);
        \\expect(log, ['x:host:true', 'x:host:false'], 'the second dispatch');
        \\0;
    );
    try turn(page);
}

test "a TouchEvent keeps the touch target list its dispatch left it, for a second dispatch, after script dropped the host it names" {
    try onFreshThread(eventKeepsItsTouchTargetList);
}

// ============================================================================
// The event's list, after the realm of a node it names has gone
// ============================================================================

fn eventListAfterItsHostsRealmWent() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  // A host in a frame's document, and in its shadow tree a span this
        \\  // realm's document made: the touch, its target and the event are
        \\  // this realm's, the host the frame's.
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const fdoc = frame.contentDocument;
        \\  fdoc.body.innerHTML = '<p id="fx"></p><div id="fhost"></div>';
        \\  const froot = fdoc.getElementById('fhost').attachShadow({ mode: 'open' });
        \\  globalThis.frameTouchNode = document.createElement('span');
        \\  frameTouchNode.id = 'ft';
        \\  froot.appendChild(frameTouchNode);
        \\  const fx = fdoc.getElementById('fx');
        \\  fx.addEventListener('ping', (event) => log.push('fx:' + read(event)));
        \\  document.getElementById('x').addEventListener('ping', (event) => log.push('x:' + read(event)));
        \\  const touch = new Touch({ identifier: 1, target: frameTouchNode });
        \\  globalThis.keptEvent = new TouchEvent('ping', { touches: [touch], bubbles: true });
        \\  fx.dispatchEvent(keptEvent);
        \\})();
        \\// A second dispatch, at this document's node: the event's target is
        \\// no longer the frame's, and its list still names the frame's host.
        \\document.getElementById('x').dispatchEvent(keptEvent);
        \\expect(log, ['fx:fhost:true', 'x:fhost:true'], 'the first two dispatches');
        \\// The span comes back to this document, the frame goes, and script
        \\// keeps nothing of the frame's realm: only the event's list names
        \\// the frame's host.
        \\globalThis.dropFrame = () => {
        \\  document.body.appendChild(frameTouchNode);
        \\  document.querySelector('iframe').remove();
        \\};
        \\dropFrame();
        \\collect();
        \\0;
    );
    // The frame's realm ends once the collector has taken it, from a task.
    for (0..3) |_| {
        try turn(page);
        try page.run(
            \\collect();
            \\0;
        );
    }
    try page.run(
        \\churn();
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\// The frame's realm has ended. Its end let go of what the realm
        \\// itself held, and the counts decided the rest: the event's list
        \\// still counts the host, which is alive in its whole tree - still
        \\// in the frame's Document, so connected.
        \\document.getElementById('x').dispatchEvent(keptEvent);
        \\expect(log, ['fx:fhost:true', 'x:fhost:true', 'x:fhost:true'], 'the third dispatch');
        \\expect(frameTouchNode.isConnected, true, 'the span is this document\'s');
        \\0;
    );
    try turn(page);
    // The frame's realm ended: its Window's teardown ran. The host it left
    // to the list's count, and its document, are still the nodes they were.
    try page.run(
        \\(() => {
        \\  // Outside a dispatch a Touch's target is its own (the span); the
        \\  // host is read through the list, in a listener.
        \\  let host = null;
        \\  const x = document.getElementById('x');
        \\  const take = (event) => { host = event.touches[0].target; };
        \\  x.addEventListener('ping', take);
        \\  x.dispatchEvent(keptEvent);
        \\  x.removeEventListener('ping', take);
        \\  log.length = 3;
        \\  expect(host.id, 'fhost', 'the host itself');
        \\  const fdoc = host.ownerDocument;
        \\  expect(fdoc.nodeType, 9, 'its document');
        \\  expect(fdoc.getElementById('fx').localName, 'p', 'its tree, whole');
        \\  expect(fdoc.defaultView, null, 'a destroyed document has no window');
        \\})();
        \\0;
    );
    // The event goes: the list's reference with it, and the frame's tree is
    // the counts' to free - the agent's end finds no node alive (the page's
    // close runs dom.refcount_teardown.agentEnded).
    try page.run(
        \\keptEvent = null;
        \\collect();
        \\0;
    );
    try turn(page);
}

test "a TouchEvent's touch target list keeps the shadow host of a removed frame alive, in its whole tree, after that frame's realm ended" {
    try onFreshThread(eventListAfterItsHostsRealmWent);
}

// ============================================================================
// The counts: what the path and the event's list take, and give back
// ============================================================================

/// The platform object `source` evaluates to (kept in a global).
fn instanceOf(page: h.Page, source: []const u8) !*runtime.Instance {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

const Nodes = struct {
    a: *runtime.Instance,
    b: *runtime.Instance,
    window: *runtime.Instance,
    a_node: *dom.NodeBase,
    b_node: *dom.NodeBase,

    fn of(page: h.Page) !Nodes {
        try page.run("globalThis.a = document.createElement('div'); globalThis.b = document.createElement('p'); 0;");
        return .{
            .a = try instanceOf(page, "a"),
            .b = try instanceOf(page, "b"),
            .window = try instanceOf(page, "window"),
            .a_node = try page.node("a"),
            .b_node = try page.node("b"),
        };
    }

    /// Each node's wrapper holds one reference, and nothing else does.
    fn expectBack(self: Nodes, what: []const u8) !void {
        try expectCount(1, self.a_node, what);
        try expectCount(1, self.b_node, what);
    }
};

fn pathCountsItsTouchTargets() !void {
    const page = try h.Page.open();
    defer page.close();
    const n = try Nodes.of(page);

    var path: dom.event_dispatch.DispatchPath = undefined;
    path.init(testing.allocator);
    defer path.deinit();
    // An event with two touch targets, and three runs of the path's touch
    // targets (three trees): [a, b], [a, a] and [window, b]. A touch target
    // that is not a node is carried, not counted.
    path.touch_count = 2;
    for ([_]*runtime.Instance{ n.a, n.b, n.a, n.a, n.window, n.b }) |target| {
        try path.touch_targets.append(testing.allocator, .{ .target = target });
    }
    try n.expectBack("before the path holds");
    path.hold();
    try expectCount(1 + 3, n.a_node, "a, in three places of the path's runs");
    try expectCount(1 + 2, n.b_node, "b, in two");
    // Dispatch step 9, and again (an event that goes while it is
    // dispatched, then the dispatch's own end).
    path.releaseHolds();
    try n.expectBack("after the path let go");
    path.releaseHolds();
    try n.expectBack("after the path let go twice");
}

test "a path counts every touch target of every run while it holds, and lets each go once" {
    try onFreshThread(pathCountsItsTouchTargets);
}

/// The list's life with `allocator` serving it: appended to by the
/// TouchEvent's constructor, replaced item by item by "invoke" step 5,
/// emptied by dispatch step 11, freed with the event.
fn listRoundTrip(allocator: std.mem.Allocator, n: Nodes) !void {
    var list: dom.event_dispatch.TouchTargetList = .{};
    defer list.deinit(allocator);
    try list.append(allocator, n.a);
    try list.append(allocator, n.b);
    try list.append(allocator, n.window);
    try testing.expectEqualSlices(*runtime.Instance, &.{ n.a, n.b, n.window }, list.toSlice());
    try expectCount(2, n.a_node, "a, listed");
    try expectCount(2, n.b_node, "b, listed");

    // Replaced by a longer list that names both again: a's two places are
    // two references, and neither node was without one meanwhile.
    try list.assign(allocator, &.{ n.b, n.a, n.a, n.window });
    try testing.expectEqualSlices(*runtime.Instance, &.{ n.b, n.a, n.a, n.window }, list.toSlice());
    try expectCount(3, n.a_node, "a, listed twice");
    try expectCount(2, n.b_node, "b, listed once");
    // The same targets again - the next item of the same tree: nothing moves.
    try list.assign(allocator, &.{ n.b, n.a, n.a, n.window });
    try expectCount(3, n.a_node, "a, the same list assigned");
    try expectCount(2, n.b_node, "b, the same list assigned");
    // A shorter list: what left it is let go.
    try list.assign(allocator, &.{n.a});
    try testing.expectEqualSlices(*runtime.Instance, &.{n.a}, list.toSlice());
    try expectCount(2, n.a_node, "a, the one target left");
    try expectCount(1, n.b_node, "b, off the list");

    // Dispatch step 11 empties it; it can be filled again.
    list.clear();
    try testing.expectEqual(@as(usize, 0), list.toSlice().len);
    try n.expectBack("after the list was emptied");
    try list.append(allocator, n.b);
    try testing.expectEqualSlices(*runtime.Instance, &.{n.b}, list.toSlice());
    try expectCount(2, n.b_node, "b, appended to the emptied list");
    try list.assign(allocator, &.{});
    try testing.expectEqual(@as(usize, 0), list.toSlice().len);
    try n.expectBack("after the empty list was assigned");
    // Freed while it names a node: the reference goes with it (the defer).
    try list.append(allocator, n.a);
    try expectCount(2, n.a_node, "a, listed when the list is freed");
}

fn listCountsItsTargets() !void {
    const page = try h.Page.open();
    defer page.close();
    const n = try Nodes.of(page);
    try listRoundTrip(testing.allocator, n);
    try n.expectBack("after the list was freed");
    // And wherever an allocation fails: an assignment that cannot grow the
    // list leaves it empty, and no count is left behind.
    try testing.checkAllAllocationFailures(testing.allocator, listRoundTrip, .{n});
    try n.expectBack("after every allocation failure");
}

test "an event's touch target list counts every node it names, through append, assign, clear and its end, and leaves no count behind when an allocation fails" {
    try onFreshThread(listCountsItsTargets);
}
