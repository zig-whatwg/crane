//! Refcount step 5h (lane rc5): a live NodeList holds its root - one counted
//! reference for its life (WebKit's LiveNodeList keeps
//! `Ref<ContainerNode> m_ownerNode`, ChildNodeList `Ref<ContainerNode>
//! m_parent`) - and releases it when it is freed; a node's childNodes caches
//! are raw and let a freed list go.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn nodeListsCountTheirRoots() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.doc = document.implementation.createHTMLDocument('');
        \\doc.body.innerHTML = '<p name=n></p>';
        \\globalThis.owner = document.body.appendChild(document.createElement('section'));
    );
    const doc = try page.node("doc");
    const owner = try page.node("owner");
    try expectCount(2, doc, "the document, before any list");
    try page.run("globalThis.named = doc.getElementsByName('n');");
    try expectCount(3, doc, "the root of a getElementsByName list");
    try page.run("named = null;");
    try page.collect();
    try expectCount(2, doc, "the document, after its list was collected");
    try page.run("owner.childNodes; owner.childNodes;");
    try expectCount(3, owner, "the owner of its childNodes, read twice ([SameObject])");
}

test "a live NodeList takes one counted reference on its root, and releases it" {
    try onFreshThread(nodeListsCountTheirRoots);
}

fn childNodesCacheLetsAFreedListGo() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.parent = document.body.appendChild(document.createElement('div'));
        \\parent.append(document.createElement('i'), 'text');
    );
    const held = try page.browser.evaluateScript("parent");
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const parent = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    const base = dom.instance_bridge.getNodeBase(@ptrCast(parent)) orelse return error.NotANode;

    // A list native code read and never handed to script: no wrapper owns it.
    const interfaces = @import("interfaces");
    const list = try interfaces.Node.get_childNodes(parent);
    try testing.expectEqual(list, try interfaces.Node.get_childNodes(parent));
    try expectCount(3, base, "the owner of a childNodes list");
    const generation = runtime.SlabAllocator.generationOf(list);
    list.releaseIfUnwrapped(generation);
    try testing.expect(runtime.SlabAllocator.generationOf(list) != generation);
    try expectCount(2, base, "the owner, after its list was freed");

    // The owner's caches let the freed list go: a new one answers.
    const again = try interfaces.Node.get_childNodes(parent);
    try testing.expect(runtime.SlabAllocator.generationOf(again) != runtime.SlabAllocator.dead_generation);
    try testing.expectEqual(@as(u32, 2), try interfaces.NodeList.get_length(again));
    try expectCount(3, base, "the owner of the new list");
}

test "a node's childNodes caches let a freed list go" {
    try onFreshThread(childNodesCacheLetsAFreedListGo);
}
