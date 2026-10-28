//! Lane refcount5 (refcount step 5e): what custom element reactions hold of
//! the elements they will hand to script.
//!
//! - A REACTION QUEUE RECORD (html/custom_elements/agent.zig) holds its
//!   element with a GCReachableRef in shadow mode: the strong root on the
//!   element's wrapper it always had (engine.retainValue: WebKit keeps a
//!   disconnected node's wrapper while isInCustomElementReactionQueue,
//!   JSNodeOwner::isReachableFromOpaqueRoots, bindings/js/JSNodeCustom.cpp)
//!   plus one counted reference (WebKit's CustomElementQueue
//!   `Vector<Ref<Element>, 4> m_elements`), from its first reaction until
//!   the agent is quiescent again, its element is cancelled or its realm
//!   ends.
//! - THE UPGRADE that pushes an element on its definition's construction
//!   stack holds it the same way across the construction (WebKit's
//!   JSCustomElementInterface `Vector<RefPtr<Element>, 1>
//!   m_constructionStack`); the walks of define() and upgrade() hold their
//!   root counted. Their counts must come back.
//!
//! Counts through dom.refcount.count: born (1) + the wrapper's (1, a global
//! keeps the node) + the holders'. A reaction is enqueued from native code,
//! outside any [CEReactions] scope, so it waits in the backup element queue
//! for the next microtask checkpoint, which a script's end is.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const dom = @import("dom");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn instanceOf(base: *dom.NodeBase) *runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(base).?));
}

const define_held =
    \\globalThis.calls = 0;
    \\customElements.define('rc-held', class extends HTMLElement { connectedCallback() { calls += 1; } });
    \\globalThis.e = document.createElement('rc-held');
    \\0;
;

fn queuedReactionCountsItsElement() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(define_held);
    const e = try page.node("e");
    try expectCount(2, e, "a custom element, before any reaction");
    dom.custom_elements.enqueueCallback(instanceOf(e), .connected, .none);
    try expectCount(3, e, "queued: its reaction record's counted reference");
    // A second reaction for the same element joins the same record.
    dom.custom_elements.enqueueCallback(instanceOf(e), .connected, .none);
    try expectCount(3, e, "two reactions, one record");
    try page.run("0;");
    try page.run("if (calls !== 2) throw new Error('calls ' + calls); 0;");
    try expectCount(2, e, "the reactions ran and the agent is quiescent: the record let go");
}

test "a queued custom element reaction's record holds its element with one counted reference until it goes" {
    try onFreshThread(queuedReactionCountsItsElement);
}

fn queuedReactionAtTheRealmsEnd() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(define_held);
    const e = try page.node("e");
    dom.custom_elements.enqueueCallback(instanceOf(e), .connected, .none);
    try expectCount(3, e, "queued");
    // The page ends with the reaction still queued: the realm's end
    // releases the record once (an underflow or a double release is an
    // error log, which fails the test).
}

test "a reaction record still queued at its realm's end lets go of its element once" {
    try onFreshThread(queuedReactionAtTheRealmsEnd);
}

fn upgradeLeavesTheCount() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<rc-up></rc-up><rc-bad></rc-bad>';
        \\globalThis.up = document.body.firstChild;
        \\globalThis.bad = document.body.lastChild;
        \\globalThis.reported = 0;
        \\window.onerror = () => { reported += 1; return true; };
        \\0;
    );
    const up = try page.node("up");
    const bad = try page.node("bad");
    try expectCount(2, up, "an undefined element");
    try expectCount(2, bad, "an undefined element");
    try page.run(
        \\customElements.define('rc-up', class extends HTMLElement { constructor() { super(); this.done = true; } });
        \\customElements.define('rc-bad', class extends HTMLElement { constructor() { super(); throw new Error('no'); } });
        \\if (up.done !== true) throw new Error('not upgraded');
        \\if (reported !== 1) throw new Error('reported ' + reported);
        \\0;
    );
    try expectCount(2, up, "upgraded");
    try expectCount(2, bad, "a failed upgrade");
}

test "an upgrade - successful or failed - leaves its element's count as it found it" {
    try onFreshThread(upgradeLeavesTheCount);
}

fn walksLeaveTheirRootsCount() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.registry = new CustomElementRegistry();
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\globalThis.x = doc.body.appendChild(doc.createElement('rc-scoped', { customElementRegistry: registry }));
        \\globalThis.tree = document.createElement('div');
        \\tree.appendChild(document.createElement('rc-later'));
        \\0;
    );
    const doc = try page.node("doc");
    const tree = try page.node("tree");
    try expectCount(2, doc, "a scoped registry's document");
    try page.run(
        \\registry.define('rc-scoped', class extends HTMLElement {});
        \\if (!(x.constructor !== HTMLElement)) throw new Error('not upgraded');
        \\customElements.define('rc-later', class extends HTMLElement {});
        \\customElements.upgrade(tree);
        \\if (tree.firstChild.constructor === HTMLElement) throw new Error('not upgraded by upgrade()');
        \\0;
    );
    try expectCount(2, doc, "after define() walked it");
    try expectCount(2, tree, "after upgrade() walked it");
}

test "define() and upgrade() leave the counts of the trees they walk as they found them" {
    try onFreshThread(walksLeaveTheirRootsCount);
}
