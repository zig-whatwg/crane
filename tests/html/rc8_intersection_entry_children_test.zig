//! Lane refcount8, item 0: an IntersectionObserverEntry keeps what its
//! getters hand out. rootBounds, boundingClientRect and intersectionRect are
//! DOMRectReadOnly objects the entry (or its observer) MADE, and target is
//! the observed Element; all four were raw `*runtime.Instance` fields with no
//! edge and no hold. Script reads a rect, drops it, a collection frees it
//! (its wrapper was the only thing keeping it), and the next read wrapped a
//! freed slot - the intermittent SIGSEGV under
//! V8Interface(IntersectionObserverEntry).PropertyGetterCallback ->
//! instanceToV8 -> getTemplateForIsolate seen in single-process runs of
//! intersection-observer/ (lane rendering1's diagnosis). Blink traces all
//! four from the entry (IntersectionObserverEntry::Trace visits
//! geometry_'s rects' owners and target_).
//!
//! Each case lets script drop what it read, collects, lets objects of the
//! same type take the freed slots, and reads again: the entry must answer
//! with its own objects - the same identity, expandos intact.
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

/// Collect, reissue freed DOMRectReadOnly, DOMRect and element slots, and
/// collect again.
const churn =
    \\TestUtils.gc();
    \\globalThis.churned = [];
    \\for (let i = 0; i < 400; i++) churned.push(new DOMRectReadOnly(1000 + i, 0, 1, 1), new DOMRect(2000 + i, 0, 1, 1), document.createElement('div'), document.createElement('span'));
    \\TestUtils.gc();
;

fn expectAnswer(page: Page, source: []const u8, expected: []const u8) !void {
    const answer = try page.evaluate(source);
    defer std.testing.allocator.free(answer);
    if (!std.mem.eql(u8, answer, expected)) std.debug.print("{s}\n  expected {s}, got {s}\n", .{ source, expected, answer });
    try std.testing.expectEqualStrings(expected, answer);
}

fn constructedEntryKeepsItsRects() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.entry = new IntersectionObserverEntry({
        \\  time: 1,
        \\  rootBounds: { x: 1, y: 1, width: 10, height: 10 },
        \\  boundingClientRect: { x: 2, y: 2, width: 20, height: 20 },
        \\  intersectionRect: { x: 3, y: 3, width: 30, height: 30 },
        \\  isIntersecting: true,
        \\  isVisible: false,
        \\  intersectionRatio: 1,
        \\  target: document.body,
        \\});
        \\entry.rootBounds.mark = 'r';
        \\entry.boundingClientRect.mark = 'b';
        \\entry.intersectionRect.mark = 'i';
    );
    for (0..2) |_| {
        try page.turn();
        try page.run(churn);
    }
    try expectAnswer(page,
        \\[entry.rootBounds.mark, entry.rootBounds.x, entry.boundingClientRect.mark, entry.boundingClientRect.x,
        \\ entry.intersectionRect.mark, entry.intersectionRect.x, entry.boundingClientRect === entry.boundingClientRect].join()
    , "r,1,b,2,i,3,true");
}

test "a constructed IntersectionObserverEntry keeps the rects it handed out after script drops them" {
    try onFreshThread(constructedEntryKeepsItsRects);
}

fn constructedEntryKeepsItsTarget() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.entry = (() => {
        \\  const target = document.createElement('section');
        \\  target.mark = 't';
        \\  return new IntersectionObserverEntry({
        \\    time: 1, rootBounds: {}, boundingClientRect: {}, intersectionRect: {},
        \\    isIntersecting: false, isVisible: false, intersectionRatio: 0, target,
        \\  });
        \\})();
    );
    for (0..2) |_| {
        try page.turn();
        try page.run(churn);
    }
    try expectAnswer(page, "[entry.target.localName, entry.target.mark].join()", "section,t");
}

test "a constructed IntersectionObserverEntry keeps a detached target script dropped" {
    try onFreshThread(constructedEntryKeepsItsTarget);
}

fn observedEntryKeepsItsRectsAndTarget() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.observer = new IntersectionObserver(entries => { globalThis.got = entries[entries.length - 1]; });
        \\observer.observe(document.body.appendChild(document.createElement('article')));
    );
    var delivered = false;
    for (0..50) |_| {
        try page.turn();
        const answer = try page.evaluate("String(typeof globalThis.got)");
        defer std.testing.allocator.free(answer);
        if (std.mem.eql(u8, answer, "object")) {
            delivered = true;
            break;
        }
    }
    try std.testing.expect(delivered);
    try page.run(
        \\observer.disconnect();
        \\got.boundingClientRect.mark = 'b';
        \\got.intersectionRect.mark = 'i';
        \\if (got.rootBounds) got.rootBounds.mark = 'r';
        \\got.target.mark = 't';
        \\got.target.remove();
    );
    for (0..2) |_| {
        try page.turn();
        try page.run(churn);
    }
    try expectAnswer(page,
        \\[got.boundingClientRect.mark, got.intersectionRect.mark, got.rootBounds ? got.rootBounds.mark : 'r',
        \\ got.target.localName, got.target.mark].join()
    , "b,i,r,article,t");
}

test "an IntersectionObserverEntry an observer delivered keeps its rects and its removed target" {
    try onFreshThread(observedEntryKeepsItsRectsAndTarget);
}

/// The audit's second unkept holder: DOMQuad.toJSON() handed out p1..p4 raw,
/// with no edge, before any p1 read had drawn the [SameObject] getter's.
fn quadToJsonKeepsItsPoints() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.quad = new DOMQuad({ x: 1, y: 1 }, { x: 2, y: 2 }, { x: 3, y: 3 }, { x: 4, y: 4 });
        \\void quad.toJSON();
    );
    for (0..2) |_| {
        try page.turn();
        try page.run(
            \\TestUtils.gc();
            \\globalThis.churned = [];
            \\for (let i = 0; i < 400; i++) churned.push(new DOMPoint(1000 + i, 0), new DOMPointReadOnly(2000 + i, 0));
            \\TestUtils.gc();
        );
    }
    try expectAnswer(page,
        \\[quad.p1.x, quad.p2.x, quad.p3.x, quad.p4.x, quad.getBounds().width, structuredClone(quad).p4.x, quad.p1 === quad.toJSON().p1].join()
    , "1,2,3,4,3,4,true");
}

test "a DOMQuad whose toJSON() ran first still answers with its own points after a collection" {
    try onFreshThread(quadToJsonKeepsItsPoints);
}
