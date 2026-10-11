//! Refcount step 5b (lane rc5): a MutationRecord takes one counted reference
//! on its target, its siblings and every node it adds or removes (WebKit's
//! ChildListRecord: `Ref<ContainerNode> m_target`, `RefPtr<Node>` siblings),
//! through dom.node_holds, and releases them when it lets go.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn recordCountsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.body.appendChild(document.createElement('div'));
        \\globalThis.before = host.appendChild(document.createElement('i'));
        \\globalThis.after = host.appendChild(document.createElement('b'));
        \\globalThis.added = document.createElement('u');
        \\globalThis.records = [];
        \\globalThis.mo = new MutationObserver(delivered => records.push(...delivered));
        \\mo.observe(host, { childList: true });
        \\host.insertBefore(added, after);
    );
    const host = try page.node("host");
    const before = try page.node("before");
    const after = try page.node("after");
    const added = try page.node("added");
    // The record, delivered and kept by script, holds its target, its
    // siblings and its added node.
    try expectCount(3, host, "the target, held by a record");
    try expectCount(3, before, "the previous sibling");
    try expectCount(3, after, "the next sibling");
    try expectCount(3, added, "the added node");
    try page.run("if (records.length !== 1) throw new Error('records: ' + records.length); records[0].addedNodes;");
    // The added-nodes list script read holds its node too.
    try expectCount(4, added, "the added node, held by the record and its list");
    try page.run("records = null; mo.disconnect();");
    try page.collect();
    try expectCount(2, host, "the target, after the record went");
    try expectCount(2, before, "the previous sibling, after");
    try expectCount(2, after, "the next sibling, after");
    try expectCount(2, added, "the added node, after the record and its list went");
}

test "a MutationRecord takes one counted reference on each node it names, and releases it" {
    try onFreshThread(recordCountsItsNodes);
}

fn removedRecordNodeCounts() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.host = document.createElement('div');
        \\globalThis.child = host.appendChild(document.createElement('span'));
        \\globalThis.mo = new MutationObserver(() => {});
        \\mo.observe(host, { childList: true });
    );
    const child = try page.node("child");
    try expectCount(2, child, "the child, before any record");
    // Queued and dropped unwrapped in one task: disconnect() empties the
    // queue, which frees the record and its references at once.
    try page.run("child.remove(); host.appendChild(child); child.remove(); mo.disconnect();");
    try expectCount(2, child, "the removed node, after its records were dropped unwrapped");
}

test "a record dropped unwrapped releases its references at once" {
    try onFreshThread(removedRecordNodeCounts);
}
