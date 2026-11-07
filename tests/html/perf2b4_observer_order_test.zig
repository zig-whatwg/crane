//! DOM "notify mutation observers" step 2 (whatwg/dom#1507, merged
//! 2026-10-09; specs/whatwg/dom.md): "Let notifyList be the result of sorting
//! the surrounding agent's pending mutation observers in ascending order, with
//! a being less than b if a's creation index is less than b's creation
//! index." The constructor gives each MutationObserver its relevant agent's
//! mutation observer counter, then increases it (steps 2-3). So callbacks
//! run in the order the observers were CREATED - not the order they got
//! records, which follows the registered observer lists.
//!
//! The browsers already did: Blink's DeliverMutations sorts by
//! `MutationObserver::ObserverLessThan` (priority_ from a counter at
//! construction), WebKit's notifyMutationObservers sorts by `m_priority`; wpt
//! dom/nodes/MutationObserver-callback-order.window.html (wpt#63390) passes
//! 3/3 in Chrome 157, Firefox 159 and Safari 27.2. Its first two cases are
//! here (that file is newer than Crane's pinned WPT tree), plus registrations
//! made in another order than creation on one node.
const std = @import("std");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

fn recordsInOtherOrderThanCreation() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.order = [];
        \\const firstTarget = document.createElement('div');
        \\const secondTarget = document.createElement('div');
        \\const first = new MutationObserver(() => order.push('first'));
        \\const second = new MutationObserver(() => order.push('second'));
        \\first.observe(firstTarget, { attributes: true });
        \\second.observe(secondTarget, { attributes: true });
        \\secondTarget.setAttribute('data-test', '');
        \\firstTarget.setAttribute('data-test', '');
        \\0;
    );
    try page.run("if (JSON.stringify(order) !== JSON.stringify(['first', 'second'])) throw new Error('order ' + JSON.stringify(order)); 0;");
}

test "observers are notified in the order they were created, not the order they got records" {
    try onFreshThread(recordsInOtherOrderThanCreation);
}

fn removedSubtree() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.order = [];
        \\const parent = document.createElement('div');
        \\const child = parent.appendChild(document.createElement('div'));
        \\const first = new MutationObserver(() => order.push('first'));
        \\const second = new MutationObserver(() => order.push('second'));
        \\first.observe(parent, { childList: true });
        \\second.observe(parent, { attributes: true, subtree: true });
        \\child.remove();
        \\child.setAttribute('data-test', '');
        \\0;
    );
    try page.run("if (JSON.stringify(order) !== JSON.stringify(['first', 'second'])) throw new Error('order ' + JSON.stringify(order)); 0;");
}

test "creation order holds when one observer sees a removed subtree through a transient registered observer" {
    try onFreshThread(removedSubtree);
}

fn registrationOrderOnOneNode() !void {
    const page = try h.Page.open();
    defer page.close();
    try page.run(
        \\globalThis.order = [];
        \\const target = document.body.appendChild(document.createElement('div'));
        \\const a = new MutationObserver(() => order.push('a'));
        \\const b = new MutationObserver(() => order.push('b'));
        \\const c = new MutationObserver(() => order.push('c'));
        \\// target's registered observer list is c, b, a: interestedObservers
        \\// meets them in that order, and the callbacks still run a, b, c.
        \\c.observe(target, { attributes: true });
        \\b.observe(target, { attributes: true });
        \\a.observe(target, { attributes: true });
        \\target.setAttribute('x', '1');
        \\0;
    );
    try page.run("if (JSON.stringify(order) !== JSON.stringify(['a', 'b', 'c'])) throw new Error('order ' + JSON.stringify(order)); 0;");
}

test "observers registered on one node in another order than created are notified in creation order" {
    try onFreshThread(registrationOrderOnOneNode);
}
