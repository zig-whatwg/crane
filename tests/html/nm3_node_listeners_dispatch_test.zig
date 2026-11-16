//! Script's side of a node's event listener list living in its rare block
//! (lane nm3 batch 3, item c; the storage is pinned in
//! tests/dom/nm3_node_listeners_rare_test.zig).
//!
//! The list's address is a slot of the node's sparse rare block, which
//! MOVES when it grows - and a listener is script, which can make the block
//! grow under the dispatch that is calling it (the first read of
//! `el.classList`, `el.style`, `el.dataset`, `el.attributes`, `el.children`
//! or `el.childNodes` each adds a field), make the list's own block grow
//! (more listeners), or both. DOM 2.9 "inner invoke" walks a clone of the
//! list taken before the first callback, so:
//!
//! - a listener added by a callback is not called by this dispatch, and is
//!   by the next;
//! - a listener removed by a callback before its turn is not called;
//! - a once listener is called once;
//! - an event handler keeps its place among the listeners.
//!
//! Every test runs a page on a thread of its own under std.testing.allocator:
//! a list, a listener's callback or a rare block left behind at the page's
//! end fails it as a leak, and a read through a block that moved faults
//! under the allocator's poison.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

/// Script helpers: `grow(el)` makes every script-reachable rare field of an
/// element (its block grows 16 -> 32 -> 64 -> 128 bytes and moves each
/// time), `expect` compares a log.
const prelude =
    \\globalThis.grow = (el) => {
    \\  el.classList.add('a'); el.style.color = 'red'; el.dataset.x = '1';
    \\  void el.attributes; void el.children; void el.childNodes; void el.part;
    \\  el.setAttribute('nonce', 'n');
    \\};
    \\globalThis.expect = (got, want, what) => {
    \\  if (JSON.stringify(got) !== JSON.stringify(want)) throw new Error(what + ': ' + JSON.stringify(got) + ', expected ' + JSON.stringify(want));
    \\};
    \\0;
;

fn listenersSurviveGrowthUnderDispatch() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\globalThis.log = [];
        \\globalThis.el = document.body.appendChild(document.createElement('div'));
        \\const late = () => log.push('late');
        \\el.addEventListener('ping', () => {
        \\  log.push(1);
        \\  // The rare block moves four times under this dispatch, and the
        \\  // list's own block grows from 4 listeners to 8.
        \\  grow(el);
        \\  el.addEventListener('ping', late);
        \\  for (let i = 0; i < 4; i++) el.addEventListener('other' + i, () => {});
        \\});
        \\el.addEventListener('ping', () => log.push(2), { once: true });
        \\el.onclick = () => log.push('handler');
        \\el.addEventListener('ping', () => log.push(3));
        \\el.dispatchEvent(new Event('ping'));
        \\expect(log, [1, 2, 3], 'first dispatch');
        \\log.length = 0;
        \\el.dispatchEvent(new Event('ping'));
        \\// The once listener is gone; the one added under the first dispatch runs.
        \\expect(log, [1, 3, 'late'], 'second dispatch');
        \\log.length = 0;
        \\el.dispatchEvent(new Event('click'));
        \\expect(log, ['handler'], 'the event handler');
        \\if (el.className !== 'a' || el.style.color !== 'red' || el.dataset.x !== '1') throw new Error('the rare fields');
        \\0;
    );
}

test "a node's listeners are called in order while its rare block and its list grow under the dispatch" {
    try onFreshThread(listenersSurviveGrowthUnderDispatch);
}

fn removalsUnderDispatch() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\globalThis.log = [];
        \\globalThis.el = document.body.appendChild(document.createElement('p'));
        \\const second = () => log.push(2);
        \\const controller = new AbortController();
        \\el.addEventListener('ping', () => {
        \\  log.push(1);
        \\  grow(el);
        \\  el.removeEventListener('ping', second);
        \\  controller.abort();
        \\});
        \\el.addEventListener('ping', second);
        \\el.addEventListener('ping', () => log.push(3), { signal: controller.signal });
        \\el.addEventListener('ping', () => log.push(4), true);
        \\el.dispatchEvent(new Event('ping'));
        \\// At the target the capturing listener runs first; 2 was removed and
        \\// 3's signal aborted before their turn.
        \\expect(log, [4, 1], 'first dispatch');
        \\log.length = 0;
        \\el.dispatchEvent(new Event('ping'));
        \\expect(log, [4, 1], 'second dispatch');
        \\0;
    );
}

test "a listener removed or aborted by a callback is not called, whatever moved meanwhile" {
    try onFreshThread(removalsUnderDispatch);
}

fn everyNodeTypeTakesListeners() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\globalThis.log = [];
        \\const host = document.body.appendChild(document.createElement('section'));
        \\const text = host.appendChild(document.createTextNode('t'));
        \\const comment = host.appendChild(document.createComment('c'));
        \\const fragment = document.createDocumentFragment();
        \\const attr = document.createAttribute('data-n');
        \\const shadow = host.attachShadow({ mode: 'open' });
        \\const inner = shadow.appendChild(document.createElement('span'));
        \\const nodes = { text, comment, fragment, attr, shadow, inner, host, document };
        \\for (const [name, node] of Object.entries(nodes)) {
        \\  if (!(node instanceof EventTarget)) throw new Error(name + ' is no EventTarget');
        \\  node.addEventListener('ping', (e) => log.push(name + '@' + e.eventPhase));
        \\}
        \\// EventTarget's operations take a node as their receiver by brand.
        \\EventTarget.prototype.addEventListener.call(text, 'ping', () => log.push('text again'));
        \\text.dispatchEvent(new Event('ping', { bubbles: true }));
        \\expect(log, ['text@2', 'text again', 'host@3', 'document@3'], 'from the text node');
        \\log.length = 0;
        \\inner.dispatchEvent(new Event('ping', { bubbles: true, composed: true }));
        \\expect(log, ['inner@2', 'shadow@3', 'host@2', 'document@3'], 'out of the shadow tree');
        \\log.length = 0;
        \\for (const node of [comment, fragment, attr]) node.dispatchEvent(new Event('ping'));
        \\expect(log, ['comment@2', 'fragment@2', 'attr@2'], 'the parentless ones');
        \\// A target that is no node is as it was.
        \\const plain = new EventTarget();
        \\let plainCalls = 0;
        \\plain.addEventListener('ping', () => plainCalls++);
        \\plain.dispatchEvent(new Event('ping'));
        \\const xhr = new XMLHttpRequest();
        \\xhr.onload = () => {};
        \\if (plainCalls !== 1 || typeof xhr.onload !== 'function') throw new Error('a non-node target');
        \\// An argument typed EventTarget takes a node (the brand, not the State).
        \\const related = new MouseEvent('over', { relatedTarget: text });
        \\if (related.relatedTarget !== text) throw new Error('relatedTarget');
        \\0;
    );
}

test "every node type is an EventTarget and keeps its own listeners; other targets are as they were" {
    try onFreshThread(everyNodeTypeTakesListeners);
}

fn collectedNodesFreeTheirListeners() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(prelude);
    try page.run(
        \\{
        \\  // Trees dropped with listeners on every node: collected below, each
        \\  // list and each callback freed with its node.
        \\  for (let t = 0; t < 20; t++) {
        \\    const root = document.createElement('div');
        \\    let at = root;
        \\    for (let d = 0; d < 6; d++) {
        \\      at = at.appendChild(document.createElement('span'));
        \\      at.addEventListener('click', () => at);
        \\      at.addEventListener('my-own-event', function named() {}, { capture: true });
        \\      at.onkeydown = () => {};
        \\      if (d % 2) grow(at);
        \\      at.appendChild(document.createTextNode('t')).addEventListener('x', () => {});
        \\    }
        \\  }
        \\  // And nodes in the document, removed with their listeners.
        \\  const kept = document.body.appendChild(document.createElement('ul'));
        \\  for (let i = 0; i < 20; i++) kept.appendChild(document.createElement('li')).addEventListener('click', () => {});
        \\  kept.remove();
        \\}
        \\0;
    );
    for (0..3) |_| try page.collect();
    try page.run(
        \\// Listeners still in the document at the page's end go with its
        \\// teardown (a content attribute's raw handler among them).
        \\document.body.innerHTML = '<p onclick="1" id="raw">x</p><b>y</b>';
        \\document.body.lastChild.addEventListener('click', () => {});
        \\document.addEventListener('ping', () => {});
        \\if (typeof document.getElementById('raw').onclick !== 'function') throw new Error('the raw handler compiles on first read');
        \\0;
    );
}

test "collected, removed and left-in-the-document nodes all free their listeners" {
    try onFreshThread(collectedNodesFreeTheirListeners);
}
