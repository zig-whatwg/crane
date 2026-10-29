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

fn signaledSlotIsCounted() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run("globalThis.slot = document.createElement('slot'); globalThis.fired = 0; slot.onslotchange = () => { fired += 1; }; 0;");
    const slot = try page.node("slot");
    try expectCount(1, slot, "a slot nothing signaled");
    // Natively: no script, so no microtask checkpoint runs the slotchange yet.
    dom.mutation_observer_algorithms.signalSlotChange(@ptrCast(@alignCast(slot.owner_instance.?)));
    try expectCount(2, slot, "in the agent's signal slots: the set's counted reference");
    // A script's end runs the checkpoint: notify fires the slotchange. Its
    // event, which the listener saw, holds its target until the event is
    // collected (refcount step 5g), so collect before counting.
    try page.run("0;");
    try page.run("if (fired !== 1) throw new Error('slotchange not fired: ' + fired); 0;");
    try page.collect();
    try expectCount(1, slot, "its slotchange fired: the set let go");
}

test "a slot in the agent's signal slots is held counted until its slotchange fired" {
    try h.onFreshThread(signaledSlotIsCounted);
}
