//! Lane refcount5 (refcount step 5c): what a MutationObserver holds of the
//! nodes it reports.
//!
//! - Its PENDING TARGETS - WebKit's MutationObserver::m_pendingTargets, a
//!   HashSet<GCReachableRef<Node>> (Source/WebCore/dom/MutationObserver.cpp):
//!   "queue a mutation record" step 4.2 adds the record's target, once
//!   however many records name it, and the observer lets go when the records
//!   leave its queue - after its callback returns (WebKit's deliver keeps the
//!   swapped-out set until it returns), after takeRecords() made the
//!   sequence (TakenRecords), at disconnect() (`m_pendingTargets.clear()`).
//!   Each is a node_holds.ReachableHold: one counted reference and one keep
//!   of the target's wrapper.
//! - Its NODE LIST and its TRANSIENT NODE SET hold none: DOM gives both as
//!   lists of weak references (dom.md, "Each MutationObserver object has
//!   these associated concepts"); a node's teardown takes itself off them.
//!
//! The mutations are made from native code through the interfaces, so no
//! script ends and no checkpoint delivers the record before the count is
//! read. Counts through dom.refcount.count: born (1) + the wrapper's (1, a
//! global keeps the node) + the holders'.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn instanceOf(base: *dom.NodeBase) *runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(base).?));
}

const setup =
    \\globalThis.host = document.createElement('div');
    \\globalThis.child = document.createElement('span');
    \\globalThis.delivered = [];
    \\globalThis.mo = new MutationObserver(records => delivered.push(...records));
    \\mo.observe(host, { childList: true });
    \\0;
;

fn pendingTargetUntilDelivery() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(setup);
    const host = try page.node("host");
    const child = try page.node("child");
    try expectCount(2, host, "the target, before any record");
    _ = try interfaces.Node.call_appendChild(instanceOf(host), instanceOf(child));
    try expectCount(4, host, "the target: its record's reference and the observer's pending target");
    _ = try interfaces.Node.call_removeChild(instanceOf(host), instanceOf(child));
    try expectCount(5, host, "two records, ONE pending target (a set)");
    // A script's end is a microtask checkpoint: the callback runs, and the
    // observer lets its pending target go once it has returned.
    try page.run("0;");
    try page.run("if (delivered.length !== 2) throw new Error('delivered ' + delivered.length); 0;");
    try expectCount(4, host, "delivered and kept by script: the two records' references only");
    try page.run("delivered = null; 0;");
    try page.collect();
    try expectCount(2, host, "the target, after its records went");
}

test "a queued record's target is a pending target: counted once, released after delivery" {
    try onFreshThread(pendingTargetUntilDelivery);
}

fn pendingTargetTakenRecords() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(setup);
    const host = try page.node("host");
    const child = try page.node("child");
    _ = try interfaces.Node.call_appendChild(instanceOf(host), instanceOf(child));
    try expectCount(4, host, "queued");
    try page.run("globalThis.taken = mo.takeRecords(); 0;");
    try expectCount(3, host, "taken: the record's reference only");
    try page.run("if (taken.length !== 1 || delivered.length !== 0) throw new Error('taken ' + taken.length); taken = null; 0;");
    try page.collect();
    try expectCount(2, host, "after the taken record went");
}

test "takeRecords() lets the pending targets go" {
    try onFreshThread(pendingTargetTakenRecords);
}

fn pendingTargetDisconnect() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(setup);
    const host = try page.node("host");
    const child = try page.node("child");
    _ = try interfaces.Node.call_appendChild(instanceOf(host), instanceOf(child));
    try expectCount(4, host, "queued");
    // disconnect() empties the record queue - the record goes unwrapped -
    // and the pending targets with it, at once.
    try page.run("mo.disconnect(); 0;");
    try expectCount(2, host, "disconnected");
    try page.run("if (delivered.length !== 0) throw new Error('delivered ' + delivered.length); 0;");
}

test "disconnect() lets the pending targets go at once" {
    try onFreshThread(pendingTargetDisconnect);
}

fn pendingTargetObserverTeardown() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(setup);
    const host = try page.node("host");
    const child = try page.node("child");
    _ = try interfaces.Node.call_appendChild(instanceOf(host), instanceOf(child));
    try expectCount(4, host, "queued");
    // The page's end tears the observer down with a record still queued:
    // its pending target is released or forgotten, never released twice
    // (an underflow is an error log, which fails the test).
}

test "an observer torn down with records queued lets its pending targets go once" {
    try onFreshThread(pendingTargetObserverTeardown);
}

fn listsHoldNothing() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.createElement('div');
        \\globalThis.child = host.appendChild(document.createElement('span'));
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(host, { attributes: true, subtree: true });
        \\mo.observe(child, { attributes: true });
        \\0;
    );
    const host = try page.node("host");
    const child = try page.node("child");
    try expectCount(2, host, "observed: the node list holds no reference");
    try expectCount(2, child, "observed: the node list holds no reference");
    // The removal gives the child a transient registered observer: the
    // observer's transient node set holds no reference either (no childList,
    // so no record names it).
    _ = try interfaces.Node.call_removeChild(instanceOf(host), instanceOf(child));
    try expectCount(2, child, "a transient registered observer's node");
    try page.run("mo.disconnect(); 0;");
    try expectCount(2, host, "disconnected");
    try expectCount(2, child, "disconnected");
}

test "a MutationObserver's node list and transient node set hold no reference" {
    try onFreshThread(listsHoldNothing);
}
