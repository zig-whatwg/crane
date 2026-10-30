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
