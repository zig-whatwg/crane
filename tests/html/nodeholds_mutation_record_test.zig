//! A MutationRecord keeps every node it names - its target, its added and
//! removed nodes and both siblings - while it is queued, after delivery and
//! for as long as script holds it or one of its NodeLists; and keeps nothing
//! once script cannot reach it.
//!
//! Blink's MutationRecord holds Member<Node> target_, previous_sibling_ and
//! next_sibling_ and Member<StaticNodeList> added_nodes_ / removed_nodes_
//! (core/dom/mutation_record.cc), all native: no wrapper is made until script
//! reads one. Crane holds them natively too (src/dom/node_holds.zig): a hold
//! per node, and one rescued wrapper for the root of a tree that leaves the
//! document while a record holds a node in it (lane nodeholds'
//! design, tmp/plans/lane-nodeholds-handoff.md).
//!
//! Each test runs a real Browser on a thread of its own (tests/html is one
//! executable).
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;
const Page = helpers.Page;

fn queuedRecordKeepsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const parent = document.body.appendChild(document.createElement('div'));
        \\const mo = new MutationObserver(() => {});
        \\mo.observe(parent, { childList: true, subtree: true, attributes: true });
        \\(() => {
        \\  const before = document.createElement('b');
        \\  const text = document.createTextNode('removed');
        \\  const after = document.createElement('u');
        \\  const target = document.createElement('p');
        \\  parent.append(before, text, after, target);
        \\  mo.takeRecords();
        \\  target.setAttribute('x', '1');
        \\  target.remove();
        \\  text.remove();
        \\  before.remove();
        \\  after.remove();
        \\})();
        \\collectNow();
        \\const records = mo.takeRecords();
        \\if (records.length !== 5) throw new Error('records: ' + records.length);
        \\const [attr, removedTarget, removed, before, after] = records;
        \\if (attr.target.localName !== 'p' || attr.target.getAttribute('x') !== '1') throw new Error('attribute target');
        \\if (attr.addedNodes.length !== 0 || attr.addedNodes !== attr.addedNodes) throw new Error('empty addedNodes');
        \\if (attr.removedNodes.length !== 0 || attr.removedNodes !== attr.removedNodes) throw new Error('empty removedNodes');
        \\if (removedTarget.removedNodes[0] !== attr.target) throw new Error('removed target');
        \\if (removed.removedNodes[0].data !== 'removed') throw new Error('removed node');
        \\if (removed.previousSibling.localName !== 'b') throw new Error('previousSibling');
        \\if (removed.nextSibling.localName !== 'u') throw new Error('nextSibling');
        \\if (before.removedNodes[0] !== removed.previousSibling) throw new Error('same previousSibling');
        \\if (after.removedNodes[0] !== removed.nextSibling) throw new Error('same nextSibling');
        \\parent.remove();
    );
}

test "a queued MutationRecord keeps its target, nodes and siblings through a collection" {
    try onFreshThread(queuedRecordKeepsItsNodes);
}

fn queuedRecordKeepsATreeRemovedAfterIt() !void {
    const page = try Page.open();
    defer page.close();
    // The records are queued while their nodes are in the document - so they
    // hold them without a wrapper - and then the whole subtree leaves it.
    try page.run(
        \\const mo = new MutationObserver(() => {});
        \\mo.observe(document.body, { childList: true, subtree: true });
        \\(() => {
        \\  const section = document.body.appendChild(document.createElement('section'));
        \\  mo.takeRecords();
        \\  const inner = section.appendChild(document.createElement('div'));
        \\  inner.appendChild(document.createElement('em')).append('kept');
        \\  section.remove();
        \\})();
        \\collectNow();
        \\const records = mo.takeRecords();
        \\if (records.length !== 4) throw new Error('records: ' + records.length);
        \\const [divAdded, emAdded, textAdded, sectionRemoved] = records;
        \\if (divAdded.target.localName !== 'section') throw new Error('target ' + divAdded.target.localName);
        \\if (divAdded.addedNodes[0].localName !== 'div') throw new Error('added div');
        \\if (emAdded.addedNodes[0].textContent !== 'kept') throw new Error('added em');
        \\if (textAdded.addedNodes[0].data !== 'kept') throw new Error('added text');
        \\if (sectionRemoved.removedNodes[0] !== divAdded.target) throw new Error('removed section');
        \\if (divAdded.addedNodes[0].parentNode !== divAdded.target) throw new Error('tree');
    );
}

test "a record queued while its nodes were in the document keeps them after their tree leaves it" {
    try onFreshThread(queuedRecordKeepsATreeRemovedAfterIt);
}

fn deliveredRecordKeepsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.parent = document.body.appendChild(document.createElement('div'));
        \\globalThis.mo = new MutationObserver(records => { globalThis.delivered = records; });
        \\mo.observe(parent, { childList: true });
        \\(() => { const span = document.createElement('span'); span.ed = 'kept'; parent.append(span); span.remove(); })();
    );
    try page.turn();
    try page.run(
        \\if (!globalThis.delivered) throw new Error('not delivered');
        \\globalThis.list = delivered[1].removedNodes;
        \\collectNow();
        \\if (delivered[1].removedNodes[0].ed !== 'kept') throw new Error('delivered record lost its node');
        \\if (delivered[0].addedNodes[0] !== delivered[1].removedNodes[0]) throw new Error('same node');
        \\delete globalThis.delivered;
        \\collectNow();
        \\if (list[0].localName !== 'span' || list[0].ed !== 'kept') throw new Error('kept list lost its node');
        \\mo.disconnect();
        \\parent.remove();
    );
}

test "a delivered MutationRecord, and a NodeList kept without it, keep their nodes" {
    try onFreshThread(deliveredRecordKeepsItsNodes);
}

fn everyObserversRecordKeepsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\const parent = document.body.appendChild(document.createElement('div'));
        \\const first = new MutationObserver(() => {});
        \\const second = new MutationObserver(() => {});
        \\first.observe(parent, { childList: true });
        \\second.observe(parent, { childList: true });
        \\(() => { const text = document.createTextNode('both'); parent.append(text); text.remove(); })();
        \\collectNow();
        \\const a = first.takeRecords();
        \\collectNow();
        \\const b = second.takeRecords();
        \\if (a.length !== 2 || b.length !== 2) throw new Error('records: ' + a.length + ',' + b.length);
        \\if (a[1].removedNodes[0].data !== 'both') throw new Error('first observer');
        \\if (b[1].removedNodes[0] !== a[1].removedNodes[0]) throw new Error('second observer');
        \\if (b[0].addedNodes[0] !== a[0].addedNodes[0]) throw new Error('added');
        \\parent.remove();
    );
}

test "the records of two observers of one mutation each keep its nodes" {
    try onFreshThread(everyObserversRecordKeepsItsNodes);
}

fn droppedRecordsReleaseTheirNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.parent = document.body.appendChild(document.createElement('div'));
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(parent, { childList: true, attributes: true, subtree: true });
        \\globalThis.weak = [];
        \\(() => {
        \\  const text = document.createTextNode('dropped');
        \\  const target = document.createElement('i');
        \\  weak.push(new WeakRef(text), new WeakRef(target));
        \\  parent.append(text, target);
        \\  target.setAttribute('y', '2');
        \\  text.remove();
        \\  target.remove();
        \\})();
        \\mo.disconnect();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('a record disconnect() dropped still keeps its nodes');
    );
    // Delivered, then let go: the records, their lists and their nodes go.
    try page.run(
        \\globalThis.weak = [];
        \\globalThis.mo2 = new MutationObserver(records => { void records[1].removedNodes[0]; });
        \\mo2.observe(parent, { childList: true });
        \\(() => {
        \\  const text = document.createTextNode('delivered');
        \\  weak.push(new WeakRef(text));
        \\  parent.append(text);
        \\  text.remove();
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('delivered records script let go still keep their nodes');
        \\mo2.disconnect();
    );
}

test "records dropped unwrapped, or delivered and let go, release their nodes" {
    try onFreshThread(droppedRecordsReleaseTheirNodes);
}

fn aRecordAndTheTreeItKeepsCollectTogether() !void {
    const page = try Page.open();
    defer page.close();
    // The removed node names the record that keeps it: an edge each way, no
    // root, so once script holds neither both go.
    try page.run(
        \\globalThis.parent = document.body.appendChild(document.createElement('div'));
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(parent, { childList: true });
        \\globalThis.weak = [];
        \\(() => {
        \\  const span = document.createElement('span');
        \\  parent.append(span);
        \\  span.remove();
        \\  const records = mo.takeRecords();
        \\  span.records = records;
        \\  weak.push(new WeakRef(span), new WeakRef(records[1]));
        \\})();
    );
    try page.turn();
    try page.run(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (weak.some(ref => ref.deref() !== undefined)) throw new Error('a record and the node naming it were not collected');
        \\mo.disconnect();
        \\parent.remove();
    );
}

test "a record and a removed node that names it are collected together" {
    try onFreshThread(aRecordAndTheTreeItKeepsCollectTogether);
}
