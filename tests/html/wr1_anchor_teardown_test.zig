//! The wrapper redesign's P4 teardown order (tmp/redesign/wrapper-redesign-
//! design.md 4.9, lane wr2's dated note there): from P4 a node wrapper's
//! counted reference is its anchor's, on the agent's C++ heap, so "no node is
//! freed while an anchor points at it" holds only if the agent's node
//! wrappers end BEFORE the Browser's last drain, refcount_teardown.agentEnded
//! and the sweeps (src/browser/Browser.zig deinit: engine.releaseNodeWrappers
//! first). Each test ends a Browser while anchored wrappers are alive - held
//! by script, in a document and detached, kept by pending activity, with
//! expandos, in a frame - under the tests' allocators, which poison a freed
//! block (0xdd), and the released NodeBases poisoned too
//! (runtime.BrowserScope.poisonsReleasedNodes in Debug):
//!
//! - an anchor that still held a slot when the sweeps freed its node would
//!   read poison at the agent's end (v8_NodeWrappers_EndAll, the registry's
//!   end, a collection's Trace or weak processing) - a crash, never a quiet
//!   pass;
//! - a wrapper's reference still held at refcount_teardown.agentEnded is a
//!   node alive at the agent's end: an error log, which fails the test;
//! - the testing allocator's leak check sees every tree freed.
//!
//! Each test runs on a thread of its own with a Browser of its own.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const engine = h.engine;
const dom = h.dom;
const onFreshThread = h.onFreshThread;

fn check(ok: bool, what: []const u8) !void {
    if (ok) return;
    std.debug.print("wr1_anchor_teardown_test: did not hold: {s}\n", .{what});
    return error.TestUnexpectedResult;
}

/// Whether `source` evaluates to true in the page's realm.
fn holds(page: h.Page, source: []const u8) !bool {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn browserEndsWithAnchoredWrappers() !void {
    const page = try h.Page.open();
    {
        defer page.close();
        try page.run(
            \\globalThis.kept = [];
            \\for (let i = 0; i < 200; i++) {
            \\  const div = document.createElement('div');
            \\  div.expando = i;
            \\  div.appendChild(document.createElement('span')).textContent = 'x' + i;
            \\  if (i % 2) document.body.appendChild(div);
            \\  kept.push(div, div.firstChild);
            \\}
            \\globalThis.fragment = document.createDocumentFragment();
            \\fragment.appendChild(document.createTextNode('detached'));
            \\globalThis.other = document.implementation.createHTMLDocument('other');
            \\other.body.appendChild(other.createElement('p')).expando = 'other';
            \\globalThis.shadowHost = document.createElement('div');
            \\shadowHost.attachShadow({ mode: 'open' }).appendChild(document.createElement('i'));
            \\kept.push(shadowHost.shadowRoot.firstChild);
            \\// Constructors' nodes: the receiver V8 made is bound (no internal
            \\// field: its anchor), a custom element's super() and its upgrade too.
            \\class XAnchor extends HTMLElement { constructor() { super(); this.mark = 'x'; } }
            \\customElements.define('x-anchor', XAnchor);
            \\globalThis.made = [new Text('t'), new DocumentFragment(), new Comment('c'), new XAnchor(), document.createElement('x-anchor')];
            \\document.body.appendChild(made[3]);
            \\made.forEach((n, i) => { n.expando = 'm' + i; });
            \\0;
        );
        // A node kept by pending activity too: its anchor is a traced root.
        const kept = try page.node("kept[0]");
        const kept_instance = dom.instance_bridge.getInstance(kept) orelse return error.NotANode;
        engine.keepPlatformObjectAlive(@ptrCast(@alignCast(kept_instance)));
        try page.collect();
        try check(try holds(page, "kept[0].expando === 0 && kept[3].textContent === 'x1' && other.body.firstChild.expando === 'other' && kept[400].parentNode === shadowHost.shadowRoot"), "identity held before the end");
        try check(try holds(page, "made.every((n, i) => n.expando === 'm' + i) && made[3].mark === 'x' && made[4].mark === 'x' && made[0].data === 't' && document.body.lastChild === made[3] && made[3] instanceof XAnchor"), "constructors' nodes held before the end");
        // The Browser ends now, every wrapper still anchored and the keep
        // still taken (its release never comes: the agent's end ends it).
    }
}

test "a Browser ends while anchored node wrappers are alive: their references go before the sweeps, and nothing reads a freed node" {
    try onFreshThread(browserEndsWithAnchoredWrappers);
}

fn browserEndsAfterACollectionFoundAnchorsDead() !void {
    const page = try h.Page.open();
    defer page.close();
    // Wrappers dropped and collected, then more made and dropped with no
    // collection after them: the agent's end releases whatever is left,
    // collected or not, before the sweeps.
    try page.run(
        \\for (let i = 0; i < 500; i++) document.createElement('div').appendChild(document.createTextNode('t'));
        \\globalThis.survivor = document.createElement('b');
        \\0;
    );
    try page.run("TestUtils.gc(); for (let i = 0; i < 500; i++) document.createElement('p'); 0;");
    try check(try holds(page, "survivor.localName === 'b'"), "the survivor's wrapper");
}

test "a Browser ends with collected node wrappers' releases still waiting: the agent's end releases them before the sweeps" {
    try onFreshThread(browserEndsAfterACollectionFoundAnchorsDead);
}
