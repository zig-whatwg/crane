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
//! algorithm depth), so the test passes on main as it is. With the queue made
//! to run what it owes at every binding exit (lane lk1's M-depth mutation,
//! made in a pool mirror only), main's path - which held no touch target -
//! reads the freed host; with the path's touch targets counted it passes.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

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
        \\  const x = document.getElementById('x');
        \\  x.addEventListener('ping', function (event) {
        \\    log.push('x:' + read(event));
        \\    // The touch's own target leaves the host's shadow tree, so the
        \\    // touch no longer keeps the host; the host leaves the document,
        \\    // and script keeps nothing of it. Only the path's touch target
        \\    // lists name it now.
        \\    document.body.appendChild(touchNode);
        \\    document.getElementById('host').remove();
        \\    collect();
        \\    churn();
        \\    collect();
        \\  });
        \\  document.body.addEventListener('ping', (event) => log.push('body:' + read(event)));
        \\  window.addEventListener('ping', (event) => log.push('window:' + read(event)));
        \\  const touch = new Touch({ identifier: 1, target: touchNode });
        \\  x.dispatchEvent(new TouchEvent('ping', { touches: [touch], bubbles: true }));
        \\})();
        \\// The path was built before the first listener: every item's touch
        \\// target is the host, whatever happened to it since.
        \\expect(log, ['x:host:true', 'body:host:false', 'window:host:false'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(document.getElementById('host'), null, 'the host is out of the document');
        \\0;
    );
}

test "a TouchEvent's path keeps the shadow host its touch was retargeted to, after the touch's target left that host's tree and script dropped it" {
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
        \\document.body.appendChild(touchNode);
        \\document.getElementById('host').remove();
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
