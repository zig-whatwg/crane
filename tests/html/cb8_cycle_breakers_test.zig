//! Refcount step 8, the cycle breakers (lane rc8; docs/refcount-design.md
//! section 3 and step 8, decision D7): what must STILL hold once listeners,
//! event handlers and observer callbacks are values traced from their
//! target's (observer's) wrapper instead of strong roots.
//!
//! WebKit holds a listener's function weakly and marks it from its target's
//! wrapper (JSEventListener's `JSC::Weak` m_jsFunction, visited by
//! EventTarget::visitJSEventListeners); Blink traces it from the target
//! (EventTarget::Trace -> EventListenerMap -> TraceWrapperV8Reference). So a
//! listener lives exactly as long as its target is reachable - and a target
//! is reachable while script holds it, while it is in a document (the
//! document's wrapper keeps its tree's), or while the platform keeps it. The
//! red side - a closure over its own target no longer pins it - is
//! tests/html/refcount_retention_test.zig's D7 cases; these are the green side:
//! nothing reachable loses a listener, a handler or an observer.
const std = @import("std");
const testing = std.testing;
const probe = @import("refcount_probe.zig");
const Page = probe.Page;

/// Script made `setup`'s objects and dropped every reference it could, and
/// the page settled (collections, task turns): `check` must still evaluate to
/// `expected`.
fn survives(comptime setup: []const u8, comptime check: []const u8, comptime expected: []const u8) !void {
    const page = try Page.open("");
    defer page.close();
    try page.run("globalThis.fired = 0;\n(() => {\n" ++ setup ++ "\n})();\n");
    try page.settle();
    try page.run(check);
    // A MutationObserver delivers in a microtask, an IntersectionObserver
    // later: a task turn before the read.
    _ = try page.browser.runEventLoopBlocking(20);
    try page.expect("String(globalThis.fired)", expected);
}

fn connectedNodeListener() !void {
    try survives(
        \\const d = document.body.appendChild(document.createElement('div'));
        \\d.id = 'cb';
        \\d.addEventListener('ping', () => { globalThis.fired++; });
    , "document.getElementById('cb').dispatchEvent(new Event('ping'));", "1");
}
test "a listener on a connected node fires after collections, with no script reference to the node" {
    try probe.onFreshThread(connectedNodeListener);
}

fn connectedNodeSelfCapture() !void {
    try survives(
        \\const d = document.body.appendChild(document.createElement('div'));
        \\d.id = 'cb';
        \\d.addEventListener('ping', () => { if (d.id === 'cb') globalThis.fired++; });
    , "document.getElementById('cb').dispatchEvent(new Event('ping'));", "1");
}
test "a listener closing over its connected target still fires after collections" {
    try probe.onFreshThread(connectedNodeSelfCapture);
}

fn connectedNodeHandler() !void {
    try survives(
        \\const d = document.body.appendChild(document.createElement('div'));
        \\d.id = 'cb';
        \\d.onclick = () => { globalThis.fired++; };
    ,
        \\const d = document.getElementById('cb');
        \\if (typeof d.onclick === 'function') d.click();
    , "1");
}
test "an on* handler of a connected node reads back and fires after collections" {
    try probe.onFreshThread(connectedNodeHandler);
}

fn contentAttributeHandler() !void {
    try survives(
        \\document.body.innerHTML = '<div id="cb" onclick="globalThis.fired++"></div>';
        \\void document.getElementById('cb').onclick; // compiled now
    , "document.getElementById('cb').click();", "1");
}
test "a compiled content-attribute handler survives collections" {
    try probe.onFreshThread(contentAttributeHandler);
}

fn scavengedWrapperKeepsListener() !void {
    try survives(
        \\const d = document.body.appendChild(document.createElement('div'));
        \\d.id = 'cb';
        \\d.addEventListener('ping', () => { globalThis.fired++; });
        \\// Young garbage enough for several scavenges while the node's wrapper
        \\// is young and nothing in script names it.
        \\let keep = null;
        \\for (let i = 0; i < 300000; i++) keep = { i, next: keep && i % 64 ? keep : null };
    , "document.getElementById('cb').dispatchEvent(new Event('ping'));", "1");
}
test "scavenges do not take a connected node's listener" {
    try probe.onFreshThread(scavengedWrapperKeepsListener);
}

fn heldTargetListeners() !void {
    try survives(
        \\globalThis.t = new EventTarget();
        \\const f = () => { globalThis.fired += 1; };
        \\const g = () => { globalThis.fired += 10; };
        \\t.addEventListener('ping', f);
        \\t.addEventListener('ping', g);
        \\t.addEventListener('pong', f);
        \\// One membership of f goes; the other must keep f alive.
        \\t.removeEventListener('ping', f);
    , "t.dispatchEvent(new Event('ping')); t.dispatchEvent(new Event('pong'));", "11");
}
test "removing one of two listeners with the same callback keeps the other alive" {
    try probe.onFreshThread(heldTargetListeners);
}

fn replacedHandler() !void {
    try survives(
        \\globalThis.held = document.createElement('div');
        \\held.onclick = () => { globalThis.fired += 100; };
        \\held.onclick = () => { globalThis.fired += 1; };
        \\held.addEventListener('click', () => { globalThis.fired += 10; });
    , "held.click();", "11");
}
test "a replaced handler's new function and a listener beside it survive collections" {
    try probe.onFreshThread(replacedHandler);
}

fn windowListener() !void {
    try survives(
        \\const w = window;
        \\window.addEventListener('ping', () => { if (w === window) globalThis.fired++; });
    , "window.dispatchEvent(new Event('ping'));", "1");
}
test "a Window listener closing over the window fires after collections" {
    try probe.onFreshThread(windowListener);
}

fn observerOfConnectedNode() !void {
    try survives(
        \\new MutationObserver(() => { globalThis.fired++; }).observe(document.body, { attributes: true });
    , "document.body.setAttribute('data-x', '1');", "1");
}
test "a MutationObserver observing a connected node delivers after collections, with no script reference to it" {
    try probe.onFreshThread(observerOfConnectedNode);
}

fn observerOfHeldDetachedNode() !void {
    try survives(
        \\globalThis.held = document.createElement('div');
        \\held.appendChild(document.createElement('span'));
        \\new MutationObserver(() => { globalThis.fired++; }).observe(held, { attributes: true, subtree: true });
    , "held.firstChild.setAttribute('data-x', '1');", "1");
}
test "a MutationObserver observing a detached tree script holds delivers after collections" {
    try probe.onFreshThread(observerOfHeldDetachedNode);
}

fn observerWithPendingRecords() !void {
    const page = try Page.open("");
    defer page.close();
    // The record is queued, then everything is dropped and collected before
    // the microtask that delivers it: the pending record keeps the observer
    // (Blink's MutationObserver::HasPendingActivity, `!records_.empty()`).
    try page.run(
        \\globalThis.fired = 0;
        \\(() => {
        \\  const d = document.createElement('div');
        \\  new MutationObserver(() => { globalThis.fired++; }).observe(d, { attributes: true });
        \\  d.setAttribute('data-x', '1');
        \\})();
        \\TestUtils.gc(); TestUtils.gc();
    );
    _ = try page.browser.runEventLoopBlocking(20);
    try page.expect("String(globalThis.fired)", "1");
}
test "a MutationObserver with a pending record delivers it though a collection ran first" {
    try probe.onFreshThread(observerWithPendingRecords);
}
