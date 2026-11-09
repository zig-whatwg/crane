//! The wrapper redesign's P4: a requested collection is precise for the C++
//! heap (v8_Isolate_RequestGarbageCollection under cppgc's
//! OverrideEmbedderStackStateScope, kNoHeapPointers; the design's dated P4
//! note). Chromium runs its precise testing collection from a task on an
//! empty stack; Crane's TestUtils.gc() can run mid-script, with binding frames
//! of a node operation below it. The invariant that makes it safe: those
//! frames hold the node (an Instance, a NodeBase - counted while anything
//! needs it), never a bare NodeAnchor*, and the receiver's wrapper - held by
//! V8's own handles in the frames below - keeps its anchor alive. A Debug
//! assertion in v8_wrapper.cpp checks that no NodeAnchor* is live in a frame
//! across a requested collection (IsolateData::anchors_in_frames).
//!
//! Each case runs a nested callback that drops every script reference to the
//! node and asks for collections while a Crane frame below it is in the middle
//! of a node operation, under the tests' allocators (a freed block reads 0xdd)
//! and the released NodeBases' poison, then checks the frames below finished
//! their steps on a live node:
//!
//! - an event listener invoked by dispatchEvent on a detached node;
//! - a MutationObserver callback whose records hold the nodes;
//! - custom element reactions (connectedCallback inside appendChild's
//!   [CEReactions] scope, attributeChangedCallback inside setAttribute's).
//!
//! And the serializer's host-object answer (the same note): HTML
//! StructuredSerializeInternal throws a "DataCloneError" for a platform object
//! that is not [Serializable] - a node - and serializes one that is (a Blob, a
//! DOMPoint, a DOMException).
//!
//! Each test runs on a thread of its own with a Browser of its own.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const engine = h.engine;
const onFreshThread = h.onFreshThread;

fn check(ok: bool, what: []const u8) !void {
    if (ok) return;
    std.debug.print("wr1_precise_gc_test: did not hold: {s}\n", .{what});
    return error.TestUnexpectedResult;
}

/// Whether `source` evaluates to true in the page's realm.
fn holds(page: h.Page, source: []const u8) !bool {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn listenerCollectsMidDispatch() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\globalThis.n = document.createElement('div');
        \\n.appendChild(document.createElement('span')).appendChild(document.createTextNode('t'));
        \\n.addEventListener('x', function (e) {
        \\  // Every script reference goes, then the collections, while
        \\  // dispatchEvent's frames below hold the node.
        \\  globalThis.n = null;
        \\  TestUtils.gc(); TestUtils.gc();
        \\  log.push(this.localName, e.target.firstChild.localName, e.currentTarget === this);
        \\});
        \\n.addEventListener('x', function (e) {
        \\  TestUtils.gc();
        \\  log.push('second', this.firstChild.firstChild.data, e.eventPhase);
        \\});
        \\globalThis.n.dispatchEvent(new Event('x'));
        \\// The dispatch's own steps after the listeners: the path, the flags.
        \\globalThis.after = 'done';
        \\0;
    );
    try page.collect();
    try check(try holds(page, "log.join() === 'div,span,true,second,t,2' && after === 'done'"), "the dispatch ran both listeners on a live node");
}

test "a requested collection inside an event listener that dropped the node frees nothing under dispatchEvent's frames" {
    try onFreshThread(listenerCollectsMidDispatch);
}

fn observerCollectsInItsCallback() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.seen = [];
        \\globalThis.p = document.createElement('p');
        \\globalThis.mo = new MutationObserver((records) => {
        \\  globalThis.p = null;
        \\  TestUtils.gc(); TestUtils.gc();
        \\  for (const r of records) seen.push(r.type, r.target.localName, r.addedNodes.length ? r.addedNodes[0].localName : '-', r.removedNodes.length ? r.removedNodes[0].localName : '-');
        \\});
        \\mo.observe(p, { childList: true, attributes: true });
        \\p.appendChild(document.createElement('b'));
        \\p.setAttribute('a', '1');
        \\p.removeChild(p.firstChild);
        \\0;
    );
    _ = try page.browser.runEventLoopBlocking(20);
    try page.collect();
    try check(try holds(page, "seen.join() === 'childList,p,b,-,attributes,p,-,-,childList,p,-,b'"), "the observer's records reached live nodes after the collections");
}

test "a requested collection inside a MutationObserver callback that dropped the nodes frees nothing its records hold" {
    try onFreshThread(observerCollectsInItsCallback);
}

fn reactionsCollectInTheirCallbacks() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.reacted = [];
        \\class XGc extends HTMLElement {
        \\  static get observedAttributes() { return ['a']; }
        \\  connectedCallback() {
        \\    globalThis.el = null;
        \\    TestUtils.gc(); TestUtils.gc();
        \\    reacted.push('connected', this.localName, this.isConnected, this.parentNode === document.body);
        \\  }
        \\  attributeChangedCallback(name, old, value) {
        \\    const self = this;
        \\    globalThis.el = null;
        \\    TestUtils.gc(); TestUtils.gc();
        \\    reacted.push('attr', name, value, self.getAttribute('a'));
        \\  }
        \\}
        \\customElements.define('x-gc', XGc);
        \\globalThis.el = document.createElement('x-gc');
        \\el.appendChild(document.createElement('i')).expando = 'kept';
        \\// The reaction runs inside appendChild's [CEReactions] scope: its
        \\// frames below hold the element and the parent.
        \\document.body.appendChild(globalThis.el);
        \\document.body.lastChild.setAttribute('a', 'v');
        \\0;
    );
    try page.collect();
    try check(try holds(page, "reacted.join() === 'connected,x-gc,true,true,attr,a,v,v' && document.body.lastChild.firstChild.expando === 'kept'"), "the reactions ran on a live element and its tree survived");
    try page.run("document.body.lastChild.remove(); 0;");
    try page.collect();
}

test "a requested collection inside custom element reactions that dropped the element frees nothing under appendChild's or setAttribute's frames" {
    try onFreshThread(reactionsCollectInTheirCallbacks);
}

fn structuredCloneOfPlatformObjects() !void {
    const page = try h.Page.open();
    defer page.close();
    // A node is a platform object that is not [Serializable]: DataCloneError,
    // never an ordinary object's copy (its expando would have been one).
    try check(try holds(page,
        \\(() => {
        \\  const kinds = [document.createElement('div'), document.createTextNode('t'), document.createDocumentFragment(), document, document.createComment('c')];
        \\  for (const n of kinds) {
        \\    n.expando = 1;
        \\    try { structuredClone(n); return false; } catch (e) { if (e.name !== 'DataCloneError' || !(e instanceof DOMException)) return false; }
        \\  }
        \\  try { structuredClone({ inner: [document.body] }); return false; } catch (e) { if (e.name !== 'DataCloneError') return false; }
        \\  return true;
        \\})()
    ), "every node throws DataCloneError");
    // [Serializable] platform objects still clone.
    try check(try holds(page,
        \\(() => {
        \\  const p = structuredClone(new DOMPoint(1, 2, 3, 4));
        \\  const x = structuredClone(new DOMException('m', 'NotFoundError'));
        \\  const b = structuredClone(new Blob(['abc'], { type: 'text/plain' }));
        \\  return p instanceof DOMPoint && p.x === 1 && p.w === 4 &&
        \\         x instanceof DOMException && x.name === 'NotFoundError' && x.message === 'm' &&
        \\         b instanceof Blob && b.size === 3 && b.type === 'text/plain';
        \\})()
    ), "a DOMPoint, a DOMException and a Blob clone");
}

test "structuredClone: a node throws DataCloneError; a Blob, a DOMPoint and a DOMException still clone" {
    try onFreshThread(structuredCloneOfPlatformObjects);
}
