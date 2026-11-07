//! Lane perf2 batch 4 (R6 part 1): what a node's registered observer list
//! does, pinned through script before its storage changes - from an
//! `infra.List` in every NodeBase to an intrusive list in a node's rare data
//! (tmp/plans/perf2b4-design.md). Characterization: each test passes on the
//! list it replaces and must pass on the new one.
//!
//! DOM 4.3 (https://dom.spec.whatwg.org/#mutation-observers):
//! - a node's registered observer list is a list: observe() step 7 updates a
//!   registration in place (its options replaced, no second one added), step
//!   8 appends one;
//! - "remove" step 15 appends a transient registered observer to the removed
//!   node for each subtree registration of its inclusive ancestors, and
//!   "notify mutation observers" step 6.3 removes them again;
//! - "queue a mutation record" gives each interested observer ONE record,
//!   however many of its registrations along the target's inclusive
//!   ancestors want it, with the old value if any of them asks for it;
//! - disconnect() empties the observer's record queue, so an observer
//!   disconnected by an earlier callback of the same notify is not called.
//! And Crane's lifetime half: a node going away takes itself off its
//! observers' node lists (dom.observer_registrations.releaseList), and an
//! observer going away takes its registrations off the nodes that list them.
//!
//! Every test runs a page on a thread of its own under std.testing.allocator,
//! so a registration, a transient copy or rare data left behind at the page's
//! end fails it as a leak.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

/// Live slab slots of `browser` whose interface is `name` - read from the
/// slab, so an object whose teardown never ran still counts.
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

/// Collect, and let the tasks a collection queues (deferred teardowns) run,
/// a few times over.
fn collect(page: h.Page) !void {
    for (0..4) |_| try page.collect();
}

fn oneRecordPerObserver() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.logs = { a: [], b: [], c: [] };
        \\const fmt = rs => rs.map(r => r.type + '/' + r.attributeName + '/' + r.oldValue).join(',');
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\globalThis.mid = host.appendChild(document.createElement('p'));
        \\for (const name of ['a', 'b', 'c']) globalThis[name] = new MutationObserver(rs => logs[name].push(fmt(rs)));
        \\// Registered c, a, b - and a twice, on mid and on its parent's subtree.
        \\c.observe(mid, { attributes: true });
        \\a.observe(host, { attributes: true, subtree: true });
        \\b.observe(mid, { attributes: true, attributeOldValue: true });
        \\a.observe(mid, { attributes: true, attributeOldValue: true });
        \\mid.setAttribute('x', '1');
        \\mid.setAttribute('x', '2');
        \\0;
    );
    try page.run(
        \\{
        \\  const want = { a: ['attributes/x/null,attributes/x/1'], b: ['attributes/x/null,attributes/x/1'], c: ['attributes/x/null,attributes/x/null'] };
        \\  if (JSON.stringify(logs) !== JSON.stringify(want)) throw new Error('delivered ' + JSON.stringify(logs));
        \\}
        \\logs = { a: [], b: [], c: [] };
        \\// observe() again replaces the registration's options: c no longer
        \\// observes attributes on mid.
        \\c.observe(mid, { childList: true });
        \\mid.setAttribute('y', '1');
        \\mid.appendChild(document.createTextNode('t'));
        \\0;
    );
    try page.run(
        \\{
        \\  const want = { a: ['attributes/y/null'], b: ['attributes/y/null'], c: ['childList/null/null'] };
        \\  if (JSON.stringify(logs) !== JSON.stringify(want)) throw new Error('after re-observe ' + JSON.stringify(logs));
        \\}
        \\0;
    );
}

test "one record per observer however many of its registrations want it; observe() replaces a registration's options" {
    try onFreshThread(oneRecordPerObserver);
}

fn transientObservers() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\globalThis.root = document.body.appendChild(document.createElement('div'));
        \\globalThis.child = root.appendChild(document.createElement('span'));
        \\globalThis.grand = child.appendChild(document.createElement('b'));
        \\globalThis.mo = new MutationObserver(rs => log.push(rs.map(r => r.type + '@' + r.target.nodeName).join(',')));
        \\mo.observe(root, { subtree: true, childList: true, attributes: true });
        \\root.removeChild(child);
        \\// Until this observer's next notify, the removed subtree is still observed.
        \\child.setAttribute('t', '1');
        \\grand.setAttribute('u', '1');
        \\0;
    );
    try page.run(
        \\if (JSON.stringify(log) !== JSON.stringify(['childList@DIV,attributes@SPAN,attributes@B'])) throw new Error('transient ' + JSON.stringify(log));
        \\// The notify took the transient registered observers off again.
        \\child.setAttribute('t', '2');
        \\grand.setAttribute('u', '2');
        \\0;
    );
    try page.run(
        \\if (log.length !== 1) throw new Error('after notify ' + JSON.stringify(log));
        \\// observe() step 7.1: re-observing the source registration's node takes
        \\// its transient copies off at once.
        \\globalThis.other = root.appendChild(document.createElement('i'));
        \\root.removeChild(other);
        \\mo.observe(root, { subtree: true, attributes: true });
        \\other.setAttribute('z', '1');
        \\0;
    );
    try page.run(
        \\// The append and the removal of `other` were recorded; its attribute,
        \\// set after the re-observe, was not.
        \\if (JSON.stringify(log) !== JSON.stringify(['childList@DIV,attributes@SPAN,attributes@B', 'childList@DIV,childList@DIV'])) throw new Error('after re-observe ' + JSON.stringify(log));
        \\0;
    );
}

test "a removed node keeps a transient registered observer until the observer's next notify" {
    try onFreshThread(transientObservers);
}

fn observeAndDisconnectDuringDelivery() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\globalThis.n1 = document.body.appendChild(document.createElement('div'));
        \\globalThis.n2 = document.body.appendChild(document.createElement('div'));
        \\globalThis.first = new MutationObserver(rs => {
        \\  log.push('first:' + rs.map(r => r.target === n1 ? 'n1' : 'n2').join(','));
        \\  second.disconnect();
        \\  first.observe(n2, { attributes: true });
        \\});
        \\globalThis.second = new MutationObserver(rs => log.push('second:' + rs.length));
        \\first.observe(n1, { attributes: true });
        \\second.observe(n1, { attributes: true });
        \\n1.setAttribute('a', '1');
        \\0;
    );
    try page.run(
        \\// second was disconnected by first's callback before its turn: its
        \\// record queue was emptied, so it is not called.
        \\if (JSON.stringify(log) !== JSON.stringify(['first:n1'])) throw new Error('first delivery ' + JSON.stringify(log));
        \\n2.setAttribute('b', '1');
        \\n1.setAttribute('a', '2');
        \\0;
    );
    try page.run(
        \\if (JSON.stringify(log) !== JSON.stringify(['first:n1', 'first:n2,n1'])) throw new Error('second delivery ' + JSON.stringify(log));
        \\// Disconnecting itself during its own delivery: later mutations reach nobody.
        \\first.disconnect();
        \\globalThis.third = new MutationObserver(rs => { log.push('third:' + rs.length); third.disconnect(); });
        \\third.observe(n1, { attributes: true });
        \\n1.setAttribute('a', '3');
        \\0;
    );
    try page.run(
        \\n1.setAttribute('a', '4');
        \\n2.setAttribute('b', '2');
        \\0;
    );
    try page.run(
        \\if (JSON.stringify(log) !== JSON.stringify(['first:n1', 'first:n2,n1', 'third:1'])) throw new Error('after disconnects ' + JSON.stringify(log));
        \\0;
    );
}

test "observe() and disconnect() inside a delivery take effect for the next mutation" {
    try onFreshThread(observeAndDisconnectDuringDelivery);
}

fn nodeTornDownWhileObserved() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.log = [];
        \\globalThis.mo = new MutationObserver(rs => log.push(rs.length));
        \\// A detached node observed directly, and a connected one removed from
        \\// under a subtree registration (a transient registered observer).
        \\globalThis.holder = document.body.appendChild(document.createElement('div'));
        \\(() => {
        \\  const lone = document.createElement('data');
        \\  mo.observe(lone, { attributes: true });
        \\  lone.setAttribute('x', '1');
        \\  const kid = holder.appendChild(document.createElement('data'));
        \\  mo.observe(holder, { childList: true, attributes: true, subtree: true });
        \\  holder.removeChild(kid);
        \\  kid.setAttribute('y', '1');
        \\})();
        \\0;
    );
    try page.run("if (JSON.stringify(log) !== JSON.stringify([3])) throw new Error('delivered ' + JSON.stringify(log)); log.length = 0; 0;");
    try collect(page);
    // Nothing names the two <data> elements any more: collected and torn
    // down while the observer still lists them.
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "HTMLDataElement"));
    try page.run(
        \\// The observer forgot them: disconnect() and a new observe() reach only
        \\// live nodes, and it still delivers.
        \\mo.disconnect();
        \\mo.observe(holder, { childList: true });
        \\holder.appendChild(document.createElement('span'));
        \\0;
    );
    try page.run("if (JSON.stringify(log) !== JSON.stringify([1])) throw new Error('after teardown ' + JSON.stringify(log)); 0;");
}

test "a node torn down while observed leaves its observer working" {
    try onFreshThread(nodeTornDownWhileObserved);
}

fn observerGoneFirst() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.target = document.body.appendChild(document.createElement('div'));
        \\(() => {
        \\  const mo = new MutationObserver(() => {});
        \\  mo.observe(target, { attributes: true, subtree: true });
        \\  mo.disconnect();
        \\})();
        \\0;
    );
    try collect(page);
    // A disconnected observer nothing names is collected; the node it was
    // registered on lives on and mutates without it.
    try testing.expectEqual(@as(usize, 0), liveOf(page.browser, "MutationObserver"));
    try page.run(
        \\target.setAttribute('a', '1');
        \\target.appendChild(document.createElement('p')).remove();
        \\0;
    );
    // And one still registered when the page ends: the Browser's end frees
    // nodes and observers in no particular order (std.testing.allocator
    // sees what is left).
    try page.run(
        \\globalThis.kept = new MutationObserver(() => {});
        \\kept.observe(target, { attributes: true, childList: true, subtree: true });
        \\target.appendChild(document.createElement('p'));
        \\target.firstChild.remove();
        \\0;
    );
}

test "an observer that goes first leaves its nodes working, and one left at the page's end is freed" {
    try onFreshThread(observerGoneFirst);
}
