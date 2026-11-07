//! A node's NodeBase and InternalStates live in its State block (lane perf2,
//! batch 5: Z7), so their addresses end when the block goes back to the arena
//! (runtime.gc.releaseStorage) - and the arena's exact classes hand a freed
//! block to the next node of the same size at once. Nothing that keeps a node
//! for script may read it past that point (tmp/plans/perf2b5-design.md 3.3).
//!
//! The holders: a live range's boundary points, a NodeIterator's reference
//! node and a TreeWalker's current node (each a hold, dom.node_holds), and a
//! pending MutationRecord's removed nodes (a hold too). While one holds a
//! subtree, the subtree stays whole across heavy block reuse; once they let
//! go it is freed. And when the subtree's own realm ends under holders in
//! another realm (a removed frame), every read through them is the node or
//! nothing - never a block another node took.
//!
//! Run under std.testing.allocator (the Crane test runner poisons what it
//! frees) and, for the NodeBase, Node's release poison (Debug).
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

/// Live slab slots of `browser` whose interface is `name`.
fn liveOf(browser: *browser_mod.Browser, name: []const u8) usize {
    var count: usize = 0;
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (std.mem.eql(u8, instance.vtable.name, name)) count += 1;
        }
    }
    return count;
}

/// Make and drop thousands of nodes of the held ones' sizes, so any block a
/// held node gave back would be taken.
const churn =
    \\for (let k = 0; k < 3000; k++) {
    \\  const p = document.createElement('p');
    \\  p.id = 'churn';
    \\  p.innerHTML = '<b id=churn>q</b><i id=churn>w</i>';
    \\}
    \\TestUtils.gc(); TestUtils.gc();
;

fn heldSubtreeStaysWhole() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id=host><p id=p1><b id=b1>x</b><i id=i1>y</i></p><span id=s1>z</span></div>';
        \\(() => {
        \\  const host = document.getElementById('host');
        \\  const p = document.getElementById('p1');
        \\  globalThis.mo = new MutationObserver(() => {});
        \\  mo.observe(host, { childList: true, subtree: true });
        \\  p.remove();
        \\  const b = p.firstChild, i = p.lastChild;
        \\  globalThis.range = new Range();
        \\  range.setStart(b.firstChild, 0);
        \\  range.setEnd(i.firstChild, 1);
        \\  globalThis.it = document.createNodeIterator(p);
        \\  it.nextNode(); it.nextNode();
        \\  globalThis.tw = document.createTreeWalker(p);
        \\  tw.firstChild();
        \\})();
        \\0;
    );
    for (0..2) |_| try page.collect();
    try page.run(churn);
    for (0..2) |_| try page.collect();
    try page.run(
        \\if (range.startContainer.parentNode.id !== 'b1') throw new Error('range start: ' + range.startContainer.parentNode.id);
        \\if (range.endContainer.data !== 'y') throw new Error('range end: ' + range.endContainer.data);
        \\if (it.referenceNode.id !== 'b1') throw new Error('iterator: ' + it.referenceNode.id);
        \\if (it.nextNode().data !== 'x') throw new Error('iterator next');
        \\if (tw.currentNode.id !== 'b1' || tw.nextSibling().id !== 'i1') throw new Error('walker');
        \\const records = mo.takeRecords();
        \\if (records.length !== 1) throw new Error('records: ' + records.length);
        \\const removed = records[0].removedNodes[0];
        \\if (removed.id !== 'p1' || removed.firstChild.id !== 'b1' || removed.lastChild.id !== 'i1') throw new Error('record');
        \\globalThis.kept = removed;
        \\0;
    );
    // The record is taken; its node is in `kept` now. Every holder lets go.
    try page.run("delete globalThis.range; delete globalThis.it; delete globalThis.tw; mo.disconnect(); delete globalThis.mo; delete globalThis.kept; 0;");
    for (0..4) |_| try page.collect();
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "HTMLParagraphElement"));
}

test "a removed subtree a range, a NodeIterator, a TreeWalker and a pending mutation record hold stays whole across block reuse, and goes when they let go" {
    try onFreshThread(heldSubtreeStaysWhole);
}

fn holdersOutliveAFramesSubtree() !void {
    const page = try h.Page.open();
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body><iframe id=f></iframe></body>", .{ .base_url = "http://example.test/held" });
    _ = try page.browser.runEventLoopBlocking(20);
    // Every holder lives in the parent's realm and holds nodes of the frame's
    // document, which goes with the frame's realm.
    try page.run(
        \\(() => {
        \\  const doc = document.getElementById('f').contentDocument;
        \\  doc.body.innerHTML = '<div id=fhost><p id=fp><b id=fb>x</b><i id=fi>y</i></p></div>';
        \\  const host = doc.getElementById('fhost');
        \\  const p = doc.getElementById('fp');
        \\  globalThis.mo = new MutationObserver(() => {});
        \\  mo.observe(host, { childList: true, subtree: true });
        \\  p.remove();
        \\  globalThis.range = doc.createRange();
        \\  range.setStart(p.firstChild.firstChild, 0);
        \\  range.setEnd(p.lastChild.firstChild, 1);
        \\  globalThis.it = doc.createNodeIterator(p);
        \\  it.nextNode(); it.nextNode();
        \\  globalThis.tw = doc.createTreeWalker(p);
        \\  tw.firstChild();
        \\})();
        \\document.getElementById('f').remove();
        \\0;
    );
    _ = try page.browser.runEventLoopBlocking(20);
    for (0..3) |_| try page.collect();
    try page.run(churn);
    for (0..2) |_| try page.collect();
    // Each read is the node it was, or nothing: never a node that took its block.
    try page.run(
        \\const seen = [];
        \\const read = (f) => { try { const v = f(); if (v != null) seen.push(String(v)); } catch (e) {} };
        \\read(() => range.startContainer.parentNode.id);
        \\read(() => range.endContainer.data);
        \\read(() => it.referenceNode.id);
        \\read(() => it.nextNode()?.data);
        \\read(() => tw.currentNode.id);
        \\read(() => tw.nextSibling()?.id);
        \\read(() => { const r = mo.takeRecords(); return r.length ? r[0].removedNodes[0].firstChild.id : null; });
        \\for (const v of seen) {
        \\  if (v === 'churn' || v === 'q' || v === 'w') throw new Error('a holder read a block another node took: ' + seen.join(','));
        \\  if (!['fb', 'y', 'x', 'fi'].includes(v)) throw new Error('unexpected read: ' + seen.join(','));
        \\}
        \\delete globalThis.range; delete globalThis.it; delete globalThis.tw; mo.disconnect(); delete globalThis.mo;
        \\0;
    );
    for (0..3) |_| try page.collect();
}

test "holders in a parent realm outlive a removed frame's subtree: every read is the node or nothing, never a reused block" {
    try onFreshThread(holdersOutliveAFramesSubtree);
}
