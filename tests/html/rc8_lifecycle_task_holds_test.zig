//! Lane refcount8 (one of two): the holders the zombie audit's full worklist sweep
//! found missed (70 resurrections at 3 sites, each an event dispatch taking
//! its target on a tree the counts had called garbage):
//! - the agent's signal slots (DOM "signal a slot change"): a slot waits for
//!   its slotchange counted - WebKit keeps the signal slot list as
//!   GCReachableRefs (shadow-dom/declarative/declarative-shadow-dom-attachment.html);
//! - a document's lifecycle task (readystatechange, DOMContentLoaded, load):
//!   it keeps its document counted from its queueing to its run or drop
//!   (shadow-dom/declarative/declarative-shadow-dom-opt-in.html: a windowless
//!   document script dropped before its tasks ran).
//! Counts through dom.refcount.count: the wrapper's (1, a global keeps the
//! node) + the holder's.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;
const expectCount = h.expectCount;

fn lifecycleTaskCountsItsDocument() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\globalThis.states = [];
        \\doc.onreadystatechange = () => states.push(doc.readyState);
        \\doc.open(); doc.write('<p>x</p>'); doc.close();
        \\0;
    );
    const doc = try page.node("doc");
    // "The end" queued the document's lifecycle tasks: each holds it.
    const queued = dom.refcount.count(doc);
    if (queued < 2) std.debug.print("queued lifecycle tasks: count {d}, expected 2 or more\n", .{queued});
    try testing.expect(queued >= 2);
    var turns: usize = 0;
    while (turns < 100 and dom.refcount.count(doc) != 1) : (turns += 1) _ = try page.browser.runEventLoopBlocking(10);
    try expectCount(1, doc, "its lifecycle tasks ran: each let go");
}

test "a document's queued lifecycle tasks hold it counted until they ran" {
    try h.onFreshThread(lifecycleTaskCountsItsDocument);
}

/// Lane nav2 batch 11: once its queued lifecycle tasks have run, a document
/// with no listener on it holds nothing but its wrapper's reference, and
/// dropped, it frees with the rest (the Browser's std.testing.allocator
/// checks every allocation at close).
fn ranLoadLeavesNoHold() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\doc.open(); doc.write('<p>x</p>'); doc.close();
        \\0;
    );
    const doc = try page.node("doc");
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        const held = try page.browser.evaluateScript("doc.readyState === 'complete'");
        defer held.release();
        const realm = page.browser.getRealm() orelse return error.NoRealm;
        if (h.engine.toBoolean(realm, held.borrow())) break;
        _ = try page.browser.runEventLoopBlocking(10);
    }
    try page.run("if (doc.readyState !== 'complete') throw new Error('readyState: ' + doc.readyState); 0;");
    try expectCount(1, doc, "its lifecycle tasks ran: only the wrapper's reference");
    const scope = &page.browser.scope.slab;
    const before = scope.stats().currently_allocated;
    try page.run("globalThis.doc = null; 0;");
    try page.collect();
    _ = try page.browser.runEventLoopBlocking(20);
    try page.collect();
    const after = scope.stats().currently_allocated;
    // The document, its html, head, body, p and text went with it.
    if (after + 6 > before) std.debug.print("dropped document: {d} instances before, {d} after\n", .{ before, after });
    try testing.expect(after + 6 <= before);
}

test "a document whose lifecycle tasks ran holds nothing and frees" {
    try h.onFreshThread(ranLoadLeavesNoHold);
}

/// The document's counts with JS listeners on it, through one load: after
/// open() and the listeners (`listened`), right after close() (`closed`),
/// once the three events - readystatechange "interactive", DOMContentLoaded,
/// readystatechange "complete" - have all been dispatched (`dispatched`), and
/// once collections have run (`collected`). `delayed`: the load is delayed
/// over close() and queued when the delay ends, instead of being queued by
/// the parser's end itself.
const ListenedCounts = struct { listened: u32, closed: u32, dispatched: u32, collected: u32 };

fn listenedLoadCounts(page: h.Page, delayed: bool) !ListenedCounts {
    try page.run(
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\globalThis.states = [];
        \\doc.open();
        \\// After open(): document.open() erases every listener and handler.
        \\doc.onreadystatechange = () => states.push(doc.readyState);
        \\doc.addEventListener('DOMContentLoaded', () => states.push('DOMContentLoaded'));
        \\doc.write('<p>x</p>');
        \\0;
    );
    const doc = try page.node("doc");
    const doc_instance: *runtime.Instance = @ptrCast(@alignCast(dom.instance_bridge.getInstance(doc) orelse return error.NoInstance));
    var counts: ListenedCounts = .{ .listened = dom.refcount.count(doc), .closed = 0, .dispatched = 0, .collected = 0 };
    if (delayed) dom.document_lifecycle.delayLoadEvent(doc_instance);
    try page.run("doc.close(); 0;");
    if (delayed) dom.document_lifecycle.undelayLoadEvent(doc_instance);
    counts.closed = dom.refcount.count(doc);
    // The queued lifecycle tasks run in turns of their own.
    var turns: usize = 0;
    while (turns < 50) : (turns += 1) {
        const held = try page.browser.evaluateScript("states.join() === 'interactive,DOMContentLoaded,complete'");
        defer held.release();
        const realm = page.browser.getRealm() orelse return error.NoRealm;
        if (h.engine.toBoolean(realm, held.borrow())) break;
        _ = try page.browser.runEventLoopBlocking(10);
    }
    try page.run("if (states.join() !== 'interactive,DOMContentLoaded,complete') throw new Error('states: ' + states.join()); 0;");
    counts.dispatched = dom.refcount.count(doc);
    // Nothing keeps the dispatched events: collections let them, and what
    // they held, go.
    turns = 0;
    while (turns < 20 and dom.refcount.count(doc) != 1) : (turns += 1) {
        try page.collect();
        _ = try page.browser.runEventLoopBlocking(10);
    }
    counts.collected = dom.refcount.count(doc);
    return counts;
}

/// Lane nav2 batch 11: reads `listenedLoadCounts` on both paths and checks
/// that the counts the listened events add are the same whether the load is
/// queued by the parser's end or after a delay, that they all go once the
/// events are collected, and that the dropped document then frees (the
/// Browser's std.testing.allocator checks every allocation at close).
fn listenedLoadHoldsGoWithTheirEvents() !void {
    var results: [2]ListenedCounts = undefined;
    for (&results, [_]bool{ false, true }) |*result, delayed| {
        const page = try h.Page.open();
        defer page.close();
        result.* = try listenedLoadCounts(page, delayed);
        const scope = &page.browser.scope.slab;
        const before = scope.stats().currently_allocated;
        try page.run("globalThis.doc = null; globalThis.states = null; 0;");
        try page.collect();
        _ = try page.browser.runEventLoopBlocking(20);
        try page.collect();
        const after = scope.stats().currently_allocated;
        if (after + 6 > before) std.debug.print("dropped document ({s}): {d} instances before, {d} after\n", .{ if (delayed) "delayed load" else "undelayed load", before, after });
        try testing.expect(after + 6 <= before);
    }
    const plain = results[0];
    const delayed = results[1];
    // The reading under test: the listeners themselves hold nothing (1, the
    // wrapper's), each of the three dispatched events holds its target until
    // it is collected (1 + 3), on both paths alike, and all of it goes.
    const same = plain.listened == delayed.listened and plain.dispatched == delayed.dispatched;
    const as_read = plain.listened == 1 and plain.dispatched == 4 and delayed.dispatched == 4;
    if (!same or !as_read or plain.collected != 1 or delayed.collected != 1) {
        std.debug.print("undelayed load: listened {d}, closed {d}, dispatched {d}, collected {d}; delayed load: listened {d}, closed {d}, dispatched {d}, collected {d}\n", .{
            plain.listened,   plain.closed,   plain.dispatched,   plain.collected,
            delayed.listened, delayed.closed, delayed.dispatched, delayed.collected,
        });
    }
    try testing.expect(same);
    try testing.expect(as_read);
    try testing.expectEqual(@as(u32, 1), plain.collected);
    try testing.expectEqual(@as(u32, 1), delayed.collected);
}

test "the counts a listened load's events add are the same delayed or not and go with the events" {
    try h.onFreshThread(listenedLoadHoldsGoWithTheirEvents);
}
