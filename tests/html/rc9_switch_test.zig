//! Lane refcount9: refcount step 7, the switch (tmp/plans/refcount-design.md
//! section 1.4 and section 7 step 7; tmp/plans/refcount9-design.md).
//!
//! Counts decide: a tree whose total reaches zero is flagged garbage where
//! the counts say so - a removal, a holder's or a wrapper's release - and
//! queued on its agent's deferred teardown queue, never freed there (decision
//! D8); the queue's next slice, between tasks, re-checks it and frees it. A
//! tree held again before its slice is a resurrection: the re-check keeps it.
//! Each test watches a node's slab generation: it changes when the node's
//! slot goes back.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const dom = h.dom;
const runtime = h.runtime;
const interfaces = @import("interfaces");

fn instanceOf(node: *dom.NodeBase) !*runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(node) orelse return error.NotANode));
}

/// A node's slot, as it is now: `freed` once the slot went back.
const Watch = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(node: *dom.NodeBase) !Watch {
        const instance = try instanceOf(node);
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    fn freed(self: Watch) bool {
        return runtime.SlabAllocator.generationOf(self.instance) != self.generation;
    }
};

/// One event loop turn: the deferred teardown's slice runs between tasks.
fn turn(page: h.Page) !void {
    _ = try page.browser.runEventLoopBlocking(20);
}

fn aRemovedTreeNothingHoldsIsQueuedThenFreed() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const b = p.first_child orelse return error.NoChild;
    const p_slot = try Watch.of(p);
    const b_slot = try Watch.of(b);
    // Never wrapped: the removal leaves a tree no count holds.
    try page.run("host.innerHTML = '';");
    // Garbage at once, and queued: nothing is freed inside the script (D8).
    try testing.expect(!p_slot.freed());
    try testing.expect(p.rc_flags.garbage);
    // A weak link reads it as gone from here (design 1.4).
    try testing.expect(!dom.refcount.weakLinkLive(b_slot.instance, b_slot.generation));
    try turn(page);
    try testing.expect(p_slot.freed());
    try testing.expect(b_slot.freed());
}

test "a removed tree nothing holds is garbage at once, queued, and freed by the next slice" {
    try h.onFreshThread(aRemovedTreeNothingHoldsIsQueuedThenFreed);
}

fn aCountedHolderKeepsItsTreeUntilItLetsGo() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const b = p.first_child orelse return error.NoChild;
    const p_slot = try Watch.of(p);
    // A holder of the descendant keeps the whole tree (decision D1).
    dom.refcount.holderRef(b);
    try page.run("host.innerHTML = '';");
    try testing.expect(!p.rc_flags.garbage);
    try turn(page);
    try page.collect();
    try testing.expect(!p_slot.freed());
    try testing.expect(b.parent_node == p);
    // Its release leaves the tree garbage; the next slice frees it.
    dom.refcount.holderDeref(b);
    try testing.expect(p.rc_flags.garbage);
    try testing.expect(!p_slot.freed());
    try turn(page);
    try testing.expect(p_slot.freed());
}

test "a counted holder keeps its tree until it lets go, and the next slice frees it then" {
    try h.onFreshThread(aCountedHolderKeepsItsTreeUntilItLetsGo);
}

fn aTreeLinkedAgainBeforeItsSliceIsKept() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>';");
    const host = try page.node("host");
    const p = host.first_child orelse return error.NoChild;
    const p_slot = try Watch.of(p);
    try page.run("host.innerHTML = '';");
    try testing.expect(p.rc_flags.garbage);
    // A native insertion in the same task: the re-check finds it in a tree.
    _ = try interfaces.Node.call_appendChild(try instanceOf(host), p_slot.instance);
    try testing.expect(!p.rc_flags.garbage);
    try turn(page);
    try testing.expect(!p_slot.freed());
    try testing.expect(p.parent_node == host);
    const books = dom.refcount_teardown.booksOf(host) orelse return error.NoAgent;
    try testing.expect(books.resurrections >= 1);
}

test "a garbage tree linked again before its slice is a resurrection: the re-check keeps it" {
    try h.onFreshThread(aTreeLinkedAgainBeforeItsSliceIsKept);
}

fn aWrappedDetachedTreeGoesWithItsLastWrapper() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.d = document.createElement('div'); d.appendChild(document.createElement('span'));");
    const d = try page.node("d");
    const span = d.first_child orelse return error.NoChild;
    const d_slot = try Watch.of(d);
    const span_slot = try Watch.of(span);
    try page.run("globalThis.d = null;");
    // The wrapper's second pass derefs; the tree is queued and freed.
    try page.collect();
    try turn(page);
    try testing.expect(d_slot.freed());
    try testing.expect(span_slot.freed());
}

test "a wrapped detached tree is freed once its last wrapper's reference ends" {
    try h.onFreshThread(aWrappedDetachedTreeGoesWithItsLastWrapper);
}

fn aRealmEndDrainsItsGarbageFirst() !void {
    const page = try h.Page.open();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<p><b>x</b></p>'; host.innerHTML = '';");
    // Queued and not yet sliced: the page's end frees it, before its realm's
    // coordinated teardown (no assertion beyond a clean end under the
    // testing allocator, and an empty queue at the Browser's end).
    page.close();
}

test "a realm's end frees the garbage its trees left before its own teardown" {
    try h.onFreshThread(aRealmEndDrainsItsGarbageFirst);
}
