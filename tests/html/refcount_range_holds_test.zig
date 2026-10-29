//! Refcount step 5f (lane refcount4): a range takes one counted reference on
//! each boundary point's container - WebKit's RangeBoundaryPoint holds
//! `Ref<Node> m_container` (Source/WebCore/dom/RangeBoundaryPoint.h) and its
//! StaticRange `Ref<Node>` start and end containers (dom/StaticRange.h) - and
//! a Selection one on its document, through dom.node_holds.RefHold. SHADOW
//! MODE: the counts decide nothing yet; each test reads them through
//! dom.refcount.count - the wrapper's (1, the node is kept by a global; it
//! adopted the node's born reference, lane refcount7) + the holders'.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn liveRangeCountsItsContainers() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.p = document.createElement('p');
        \\globalThis.q = p.appendChild(document.createElement('q'));
    );
    const p = try page.node("p");
    const q = try page.node("q");
    try expectCount(1, p, "p, before any range");
    // new Range() is collapsed at (document, 0); setStart into another tree
    // collapses its end there too: both boundary points name p.
    try page.run("globalThis.r = new Range(); r.setStart(p, 0);");
    try expectCount(3, p, "p, the start and end container");
    try page.run("r.setEnd(q, 0);");
    try expectCount(2, p, "p, the start container only");
    try expectCount(2, q, "q, the end container");
    try page.run("r.collapse(true);");
    try expectCount(3, p, "p, after collapsing to the start");
    try expectCount(1, q, "q, after the end left it");
    try page.run("r = null;");
    try page.collect();
    try expectCount(1, p, "p, after its range was collected");
    try expectCount(1, q, "q, after its range was collected");
}

test "a live Range takes one counted reference on each boundary point's container, and releases it" {
    try onFreshThread(liveRangeCountsItsContainers);
}

fn removalMovesTheCount() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\globalThis.a = host.appendChild(document.createElement('span'));
        \\globalThis.r = new Range(); r.setStart(a, 0); r.setEnd(a, 0);
    );
    const host = try page.node("host");
    const a = try page.node("a");
    try expectCount(3, a, "a, both boundary points");
    try expectCount(1, host, "host, before the removal");
    // DOM remove steps 4-7: a boundary point inside the removed node moves to
    // (parent, index) - the mutation algorithm's live-range steps, which
    // redraw the range's holds as its own methods do.
    try page.run("a.remove();");
    try expectCount(1, a, "a, after the removal moved both points off it");
    try expectCount(3, host, "host, both boundary points now");
    try page.run("r = null;");
    try page.collect();
    try expectCount(1, host, "host, after the range was collected");
}

test "a removal that moves a live range's boundary points moves their counted references" {
    try onFreshThread(removalMovesTheCount);
}

fn staticRangeCountsItsContainers() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.a = document.createElement('i');
        \\globalThis.b = document.createElement('b');
    );
    const a = try page.node("a");
    const b = try page.node("b");
    try page.run("globalThis.sr = new StaticRange({ startContainer: a, startOffset: 0, endContainer: b, endOffset: 0 });");
    try expectCount(2, a, "a, the start container");
    try expectCount(2, b, "b, the end container");
    try page.run("globalThis.collapsed = new StaticRange({ startContainer: a, startOffset: 0, endContainer: a, endOffset: 0 });");
    try expectCount(4, a, "a, also both points of a collapsed range");
    try page.run("sr = null; collapsed = null;");
    try page.collect();
    try expectCount(1, a, "a, after both ranges were collected");
    try expectCount(1, b, "b, after its range was collected");
}

test "a StaticRange takes one counted reference on each container, and releases it" {
    try onFreshThread(staticRangeCountsItsContainers);
}

fn selectionCountsItsDocument() !void {
    const page = try Page.open();
    defer page.close();
    try page.run("globalThis.d = document;");
    const document = try page.node("d");
    // Settled first: the page's own lifecycle tasks (DOMContentLoaded, load)
    // each hold their document until they run (refcount8).
    try page.collect();
    const before = dom.refcount.count(document);
    // The document's Selection, made on first use, keeps its document (a
    // traced edge, and now a counted reference beside it); the document
    // keeps its selection for its life.
    try page.run("globalThis.s = getSelection(); if (s.rangeCount !== 0) throw new Error('not empty');");
    try expectCount(before + 1, document, "the document, held by its selection");
    try page.run("s = null; getSelection();");
    try page.collect();
    try expectCount(before + 1, document, "the document, still held by the selection it keeps");
}

test "a Selection takes one counted reference on its document" {
    try onFreshThread(selectionCountsItsDocument);
}
