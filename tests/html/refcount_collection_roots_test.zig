//! Refcount step 5h (lane rc5): a live HTMLCollection holds its root - one
//! counted reference for its life (WebKit's collections keep
//! `Ref<ContainerNode> m_ownerNode`), through dom.node_holds.MemberHold - and
//! releases it when it is freed. children is [SameObject]: one per owner.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn htmlCollectionsCountTheirRoots() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\globalThis.root = document.createElement('div');
        \\root.innerHTML = '<p class=x></p>';
    );
    const root = try page.node("root");
    try expectCount(2, root, "the root, before any collection");
    try page.run("globalThis.classes = root.getElementsByClassName('x'); globalThis.again = root.getElementsByClassName('y');");
    try expectCount(4, root, "the root of two getElementsByClassName collections");
    try page.run("classes = null; again = null;");
    try page.collect();
    try expectCount(2, root, "the root, after its collections were collected");
    try page.run("root.children; root.children;");
    try expectCount(3, root, "the owner of its children, read twice ([SameObject])");
}

test "a live HTMLCollection takes one counted reference on its root, and releases it" {
    try onFreshThread(htmlCollectionsCountTheirRoots);
}
