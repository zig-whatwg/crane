//! Refcount step 5b (lane rc5): a static NodeList - querySelectorAll's, a
//! record's lists, a labels snapshot - takes one counted reference on each
//! node it holds (WebKit's StaticNodeList: `Vector<Ref<Node>>`), through
//! dom.node_holds, and releases it when it lets go.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn staticListCountsItsNodes() !void {
    const page = try Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<p id=a></p><div><p id=b></p></div>';
        \\globalThis.a = document.getElementById('a');
        \\globalThis.b = document.getElementById('b');
    );
    const a = try page.node("a");
    const b = try page.node("b");
    try expectCount(2, a, "a, before any list");
    try page.run("globalThis.list1 = document.querySelectorAll('p'); globalThis.list2 = document.body.querySelectorAll('#b');");
    try expectCount(3, a, "a, held by one list");
    try expectCount(4, b, "b, held by two lists");
    try page.run("list1 = null;");
    try page.collect();
    try expectCount(2, a, "a, after its list was collected");
    try expectCount(3, b, "b, held by the other list");
    try page.run("list2 = null;");
    try page.collect();
    try expectCount(2, b, "b, after both lists");
}

test "a static NodeList takes one counted reference on each node it holds, and releases it" {
    try onFreshThread(staticListCountsItsNodes);
}
