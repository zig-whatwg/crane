//! The event path's nodes stay alive, and stay themselves, for the whole
//! dispatch (lane lk1, item 2; the safety follow-up lane uaf1 queued on
//! 2026-11-16).
//!
//! DOM 2.9 "dispatch" builds the event's path before the first listener runs
//! and walks it to the end whatever the listeners do to the tree. The walk
//! (EventTarget's impl: `dispatchOnPath`, `invoke`, `innerInvoke`) keeps each
//! item's invocation target as an address, and a node's listener list is
//! found through its NodeBase's address after every callback
//! (`Listeners.place.node`, then `NodeBase.stands`). Two things keep those
//! addresses good, each enough alone:
//!
//! - Nothing is freed under a callback: the agent's teardown queue frees no
//!   tree and runs no collected wrapper's finalizer while a callback
//!   invocation is on its stack (runtime.gc.DeferredTeardown's algorithm
//!   depth). The microtask checkpoint after a listener returns runs inside
//!   that invocation, so a microtask frees nothing either.
//! - The path holds its nodes: `DispatchPath.hold` (dom.event_dispatch, lane
//!   ev1) takes one counted reference on every invocation target that is a
//!   node, and on every relatedTarget, and lets them go at dispatch step 9 -
//!   WebKit's EventContext holds `RefPtr<Node> m_node` and
//!   `RefPtr<EventTarget> m_currentTarget` (Source/WebCore/dom/
//!   EventContext.h), Blink's NodeEventContext a `Member<Node> node_` and
//!   its WindowEventContext a `Member<LocalDOMWindow> window_`
//!   (third_party/blink/renderer/core/dom/events/node_event_context.h,
//!   window_event_context.h), Gecko's EventTargetChainItem an
//!   `nsCOMPtr<EventTarget> mTarget` (dom/events/EventDispatcher.cpp). A
//!   tree with a counted node is never garbage (dom.refcount, decision D1).
//!
//! (The frees made whatever the counts say - a realm's end - run from a task
//! of their own: a removed iframe's realm is detached, not ended, and ends
//! once the collector has taken it.)
//!
//! Each test's listener, or a microtask it queues, takes the path's nodes
//! out of the document, drops every script reference, collects twice, and
//! makes thousands of objects of the same kinds, each with listeners of the
//! dispatched type that log NEWCOMER: a freed node's slab slot and State
//! block are reissued to one of them at once, so a walk that came back to a
//! freed path node would call a newcomer's listener - or, where it still
//! held the NodeBase's address, read a freed block, which in this Debug
//! build is poisoned and quarantined and panics with "a liveness test read a
//! FREED node block" (lane uaf1's instrument, NodeBase.freedBlockReadPanics).
//!
//! WHAT THE TESTS WERE SHOWN TO CATCH (chat2.local, 2026-11-16, mutations
//! made in a pool mirror only): as the code is, 10 of 10; with the path's
//! counted references removed (`path.hold()` out of dom.event_path.build),
//! 10 of 10; with the queue made to run what it owes at every binding exit
//! (DeferredTeardown.leaveOwing), 10 of 10; with BOTH, "a native dispatch
//! walks the rest of its path after a microtask ..." fails - its log reads
//! c:body, micro, NEWCOMER, NEWCOMER, t:details: the walk called the
//! listeners of the two nodes that had taken the freed section's and
//! article's places. Either protection alone is enough; the tests fail when
//! neither is there. The same pages run on the production and bug-finding
//! WPT runners as tests/wpt/crane/lk1-dispatch-path-held.html.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

/// `collect()` is two full collections; `churn(doc)` makes 500 elements of
/// each kind the tests' paths hold, every one with a capturing and a
/// bubbling listener of both dispatched types that logs NEWCOMER; `expect`
/// compares a log.
const prelude =
    \\globalThis.log = [];
    \\globalThis.kept = [];
    \\globalThis.collect = () => { TestUtils.gc(); TestUtils.gc(); };
    \\globalThis.churn = (doc) => {
    \\  for (const name of ['section', 'article', 'details', 'summary', 'p', 'span', 'div', 'html', 'body', 'iframe']) {
    \\    for (let i = 0; i < 500; i++) {
    \\      const n = doc.createElement(name);
    \\      for (const type of ['ping', 'toggle']) {
    \\        n.addEventListener(type, () => log.push('NEWCOMER'));
    \\        n.addEventListener(type, () => log.push('NEWCOMER'), true);
    \\      }
    \\      kept.push(n);
    \\    }
    \\  }
    \\  for (let i = 0; i < 500; i++) {
    \\    const target = new EventTarget();
    \\    for (const type of ['ping', 'toggle']) target.addEventListener(type, () => log.push('NEWCOMER'));
    \\    kept.push(target);
    \\  }
    \\};
    \\globalThis.inMicrotask = (steps) => {
    \\  Promise.resolve().then(() => {
    \\    log.push('micro');
    \\    steps();
    \\    collect();
    \\    // One more binding's return after the collections.
    \\    void document.title;
    \\    churn(document);
    \\    collect();
    \\    void document.title;
    \\  });
    \\};
    \\globalThis.expect = (got, want, what) => {
    \\  if (JSON.stringify(got) !== JSON.stringify(want)) throw new Error(what + ': ' + JSON.stringify(got) + ', expected ' + JSON.stringify(want));
    \\};
    \\0;
;

/// A task turn, twice: a queued element task runs, and what it left owed
/// (the collections' releases, the teardown queue) runs after it.
fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
    _ = try page.browser.runEventLoopBlocking(20);
}

// ============================================================================
// A script dispatch: the target's listener removes and drops the path
// ============================================================================

fn scriptDispatchPathRemoved() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\document.body.innerHTML = '<section><article><p><span id="t"></span></p></article></section>';
        \\(() => {
        \\  for (const name of ['p', 'article', 'section']) {
        \\    const n = document.querySelector(name);
        \\    n.addEventListener('ping', function () { log.push('c:' + this.localName + ':' + this.isConnected); }, true);
        \\    n.addEventListener('ping', function () { log.push(this.localName + ':' + this.isConnected); collect(); });
        \\  }
        \\  const t = document.getElementById('t');
        \\  t.addEventListener('ping', function () {
        \\    log.push('t1');
        \\    // The whole path below the body leaves the document, and script
        \\    // keeps none of it but `this`.
        \\    document.querySelector('section').remove();
        \\    collect();
        \\    churn(document);
        \\    collect();
        \\  });
        \\  t.addEventListener('ping', function () { log.push('t2:' + this.id); });
        \\  t.dispatchEvent(new Event('ping', { bubbles: true }));
        \\})();
        \\// The path was built before the first listener: every listener on
        \\// it runs, in order, on the node it was added to.
        \\expect(log, ['c:section:true', 'c:article:true', 'c:p:true', 't1', 't2:t', 'p:false', 'article:false', 'section:false'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of a node made under the dispatch ran');
        \\expect(document.querySelector('section'), null, 'the subtree is gone');
        \\0;
    );
}

test "a script dispatch walks its whole path after the target's listener removed it, collected and made nodes" {
    try onFreshThread(scriptDispatchPathRemoved);
}

// ============================================================================
// A native dispatch: no script frame holds a node of the path
// ============================================================================

fn nativeDispatchPathRemoved(comptime connected: bool) !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    // A details element's toggle event is fired from a queued element task
    // (HTML "queue a details toggle event task"): no script is on the stack
    // when its dispatch begins, and script kept no node of its path. It does
    // not bubble, so the capturing listeners of its ancestors run first.
    try page.run(
        \\(() => {
        \\  const holder = document.createElement('div');
        \\  holder.innerHTML = '<section><article><details id="d"><summary>s</summary>x</details></article></section>';
        \\  const section = holder.firstChild;
        \\  section.addEventListener('toggle', function () {
        \\    log.push('c:' + this.localName);
        \\    // The path's tree: out of its parent, and nothing of it kept.
        \\    this.remove();
        \\    collect();
        \\    churn(document);
        \\    collect();
        \\  }, true);
        \\  section.firstChild.addEventListener('toggle', function () { log.push('c:' + this.localName + ':' + (this.parentNode !== null)); collect(); churn(document); collect(); }, true);
        \\  const d = section.firstChild.firstChild;
        \\  d.addEventListener('toggle', function (event) { log.push('t:' + this.id + ':' + (event.target === this)); collect(); });
        \\  d.addEventListener('toggle', function () { log.push('t2:' + this.localName); });
    ++ (if (connected) "\n  document.body.appendChild(holder);\n" else "") ++
        \\  d.open = true;
        \\})();
        \\collect();
        \\expect(log, [], 'the toggle event is fired from a task');
        \\0;
    );
    try turn(page);
    try page.run(
        \\expect(log, ['c:section', 'c:article:true', 't:d:true', 't2:details'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of a node made under the dispatch ran');
        \\0;
    );
}

fn nativeDispatchConnected() !void {
    try nativeDispatchPathRemoved(true);
}

fn nativeDispatchDetached() !void {
    try nativeDispatchPathRemoved(false);
}

test "a native dispatch walks its whole path after an ancestor's listener removed the path from the document" {
    try onFreshThread(nativeDispatchConnected);
}

test "a native dispatch in a tree no document holds walks its whole path while its listeners collect" {
    try onFreshThread(nativeDispatchDetached);
}

// ============================================================================
// The path's frame is removed under the dispatch
// ============================================================================

fn frameRemovedUnderScriptDispatch() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const doc = frame.contentDocument;
        \\  const win = frame.contentWindow;
        \\  doc.body.innerHTML = '<section><p><span id="t"></span></p></section>';
        \\  const t = doc.getElementById('t');
        \\  win.addEventListener('ping', () => log.push('c:window'), true);
        \\  win.addEventListener('ping', () => log.push('window'));
        \\  doc.addEventListener('ping', () => log.push('document'));
        \\  doc.querySelector('section').addEventListener('ping', () => log.push('section'));
        \\  doc.querySelector('p').addEventListener('ping', () => log.push('p'));
        \\  t.addEventListener('ping', () => {
        \\    log.push('t1');
        \\    // The navigable of every node on the path, and of the Window at
        \\    // its end, is destroyed under the dispatch.
        \\    frame.remove();
        \\    collect();
        \\    churn(document);
        \\    collect();
        \\  });
        \\  t.addEventListener('ping', () => log.push('t2'));
        \\  t.dispatchEvent(new Event('ping', { bubbles: true }));
        \\})();
        \\// DOM "inner invoke" steps 2.6-2.8: a listener is not called once
        \\// its target's global is a Window whose document is not fully
        \\// active - every listener after the removal. The walk still visits
        \\// each item, the frame's Window last.
        \\expect(log, ['c:window', 't1'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of an object made under the dispatch ran');
        \\0;
    );
    try turn(page);
}

test "a script dispatch in a frame its listener removes ends cleanly, the frame's Window last on its path" {
    try onFreshThread(frameRemovedUnderScriptDispatch);
}

fn frameRemovedUnderNativeDispatch() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  const doc = frame.contentDocument;
        \\  doc.body.innerHTML = '<section><details id="d"><summary>s</summary>x</details></section>';
        \\  frame.contentWindow.addEventListener('toggle', () => log.push('c:window'), true);
        \\  // The first node of the path: its listener, a function of the
        \\  // parent's realm, destroys the frame's navigable and keeps nothing
        \\  // of the frame.
        \\  doc.addEventListener('toggle', () => {
        \\    log.push('c:document');
        \\    document.querySelector('iframe').remove();
        \\    collect();
        \\    churn(document);
        \\    collect();
        \\  }, true);
        \\  doc.querySelector('section').addEventListener('toggle', () => log.push('c:section'), true);
        \\  doc.getElementById('d').addEventListener('toggle', () => log.push('t'));
        \\  doc.getElementById('d').open = true;
        \\})();
        \\collect();
        \\expect(log, [], 'the toggle event is fired from a task');
        \\0;
    );
    try turn(page);
    try page.run(
        \\expect(log, ['c:window', 'c:document'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of an object made under the dispatch ran');
        \\0;
    );
    try turn(page);
}

test "a native dispatch in a frame its first listener removes ends cleanly with no script holding the path" {
    try onFreshThread(frameRemovedUnderNativeDispatch);
}

// ============================================================================
// A microtask between two listeners of a native dispatch
// ============================================================================
//
// When the user agent fires the event the script stack is empty each time a
// listener returns, so a microtask checkpoint runs there (HTML "clean up
// after running script") with no script frame holding any node of the path -
// the place where a path's node is furthest from everything else that could
// keep it. The engine performs the checkpoint inside the listener's callback
// invocation, so its collections free nothing; were they to free (the
// M-depth mutation in this file's header), the path's counted references
// are what would keep the path's nodes.

fn microtaskFreesUnderNativeDispatch(comptime connected: bool) !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const holder = document.createElement('div');
        \\  holder.innerHTML = '<section id="s"><article><details><summary>s</summary>x</details></article></section>';
        \\  const section = holder.firstChild;
        \\  section.addEventListener('toggle', function (event) {
        \\    log.push('c:' + this.localName);
        \\    // Script keeps the event, and nothing else of the dispatch.
        \\    globalThis.lastEvent = event;
        \\    // In the microtask nothing of the path is on any stack. Its tree
        \\    // leaves the document there (or was never in one), and the
        \\    // target leaves the tree: the task that fires the event holds
        \\    // the target, which kept the target's whole tree - now only the
        \\    // path keeps the ancestors the walk still has to visit. Script
        \\    // keeps no node of either.
        \\    let section = this;
        \\    inMicrotask(() => {
        \\      section.firstChild.firstChild.remove();
        \\      section.remove();
        \\      section = null;
        \\    });
        \\  }, true);
        \\  section.firstChild.addEventListener('toggle', function () { log.push('c:' + this.localName + ':' + this.parentNode.localName + ':' + this.childNodes.length); }, true);
        \\  const d = section.firstChild.firstChild;
        \\  d.addEventListener('toggle', function (event) { log.push('t:' + this.localName + ':' + (event.target === this) + ':' + event.type + ':' + (this.parentNode === null)); });
    ++ (if (connected) "\n  document.body.appendChild(holder);\n" else "\n  section.remove();\n") ++
        \\  d.open = true;
        \\})();
        \\collect();
        \\expect(log, [], 'the toggle event is fired from a task');
        \\0;
    );
    try turn(page);
    try page.run(
        \\expect(log, ['c:section', 'micro', 'c:article:section:0', 't:details:true:toggle:true'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of a node made under the dispatch ran');
        \\0;
    );
}

fn microtaskConnected() !void {
    try microtaskFreesUnderNativeDispatch(true);
}

fn microtaskDetached() !void {
    try microtaskFreesUnderNativeDispatch(false);
}

test "a native dispatch walks its whole path after a microtask between two listeners removed its tree, collected and freed" {
    try onFreshThread(microtaskConnected);
}

test "a native dispatch in a tree no document holds walks its whole path after a microtask between two listeners collected and freed" {
    try onFreshThread(microtaskDetached);
}

// The sharpest form, and the one test the two mutations together turn red.
// Above, the listener that queued the microtask ran ON a node of the tree
// the microtask takes apart, and with both protections removed those tests
// still passed: the tree was not freed there (the node the listener was
// just called on still has its wrapper - a guess at why, not measured).
// Here the listener is the body's, which stays in the document, and the
// microtask takes the REST of the path out from under the walk: the
// section's tree has no wrapper, no script reference and no task's hold (the
// target is taken out of it) - nothing but the path's own counted
// references.
fn microtaskFreesTheRestOfThePath() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const holder = document.createElement('div');
        \\  holder.innerHTML = '<section><article><details><summary>s</summary>x</details></article></section>';
        \\  const section = holder.firstChild;
        \\  section.addEventListener('toggle', function () { log.push('c:' + this.localName + ':' + (this.parentNode === null)); }, true);
        \\  section.firstChild.addEventListener('toggle', function () { log.push('c:' + this.localName + ':' + this.parentNode.localName + ':' + this.childNodes.length); }, true);
        \\  const d = section.firstChild.firstChild;
        \\  d.addEventListener('toggle', function (event) { log.push('t:' + this.localName + ':' + (event.target === this) + ':' + event.type + ':' + (this.parentNode === null)); });
        \\  document.body.appendChild(section);
        \\  d.open = true;
        \\})();
        \\document.body.addEventListener('toggle', function first(event) {
        \\  log.push('c:body');
        \\  globalThis.lastEvent = event;
        \\  document.body.removeEventListener('toggle', first, true);
        \\  inMicrotask(() => {
        \\    const section = document.body.lastChild;
        \\    section.firstChild.firstChild.remove();
        \\    section.remove();
        \\  });
        \\}, true);
        \\collect();
        \\expect(log, [], 'the toggle event is fired from a task');
        \\0;
    );
    try turn(page);
    try page.run(
        \\expect(log, ['c:body', 'micro', 'c:section:true', 'c:article:section:0', 't:details:true:toggle:true'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of a node made under the dispatch ran');
        \\0;
    );
}

test "a native dispatch walks the rest of its path after a microtask of an ancestor's listener took that rest out of the document, collected and made nodes" {
    try onFreshThread(microtaskFreesTheRestOfThePath);
}

fn microtaskRemovesFrameUnderNativeDispatch(comptime connected: bool) !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\(() => {
        \\  const frame = document.body.appendChild(document.createElement('iframe'));
        \\  frame.id = 'f';
        \\  const doc = frame.contentDocument;
        \\  const holder = doc.createElement('div');
        \\  holder.innerHTML = '<section><article><details><summary>s</summary>x</details></article></section>';
        \\  const section = holder.firstChild;
        \\  // Functions of the parent's realm on the frame's nodes. The first
        \\  // queues a microtask that destroys the frame's navigable, keeps
        \\  // nothing of the frame and collects: the frame's realm can be
        \\  // collected there, under the dispatch of its own nodes.
    ++ (if (connected) "\n  const first = frame.contentWindow;\n" else "\n  const first = section;\n") ++
        \\  first.addEventListener('toggle', () => {
        \\    log.push('c:first');
        \\    inMicrotask(() => document.getElementById('f').remove());
        \\  }, true);
        \\  section.firstChild.addEventListener('toggle', () => log.push('c:article'), true);
        \\  section.firstChild.firstChild.addEventListener('toggle', () => log.push('t'));
    ++ (if (connected) "\n  doc.body.appendChild(holder);\n" else "\n  section.remove();\n") ++
        \\  section.firstChild.firstChild.open = true;
        \\})();
        \\collect();
        \\expect(log, [], 'the toggle event is fired from a task');
        \\0;
    );
    try turn(page);
    try page.run(
        \\// After the microtask the frame's Window's document is not fully
        \\// active: DOM "inner invoke" steps 2.6-2.8 call no further listener.
        \\expect(log, ['c:first', 'micro'], 'the walk');
        \\collect();
        \\0;
    );
    try turn(page);
    try page.run(
        \\collect();
        \\expect(log.includes('NEWCOMER'), false, 'no listener of an object made under the dispatch ran');
        \\0;
    );
    try turn(page);
}

fn microtaskFrameConnected() !void {
    try microtaskRemovesFrameUnderNativeDispatch(true);
}

fn microtaskFrameDetached() !void {
    try microtaskRemovesFrameUnderNativeDispatch(false);
}

test "a native dispatch in a frame's document ends cleanly after a microtask between two listeners removed the frame and collected" {
    try onFreshThread(microtaskFrameConnected);
}

test "a native dispatch in a detached tree of a frame's realm ends cleanly after a microtask between two listeners removed the frame and collected" {
    try onFreshThread(microtaskFrameDetached);
}
