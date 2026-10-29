//! Refcount step 5f (lane refcount4): a NodeIterator takes one counted
//! reference on its root, its reference and its candidate, and a TreeWalker
//! on its root and its current node - WebKit's NodeIteratorBase `const
//! Ref<Node> m_root` (Source/WebCore/dom/Traversal.h), NodeIterator's
//! NodePointer `RefPtr<Node> node` (dom/NodeIterator.h), TreeWalker
//! `Ref<Node> m_current` (dom/TreeWalker.h) - and each holds the node it
//! hands its filter across the call (design 1.2: a stack frame across a step
//! that runs script). SHADOW MODE: counts read through dom.refcount.count -
//! the wrapper's (1; it adopted the node's born reference, lane refcount7) +
//! the holders'.
const h = @import("refcount_holders_helpers.zig");
const std = h.std;
const testing = h.testing;
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const Page = h.Page;
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn openTree() !Page {
    const page = try Page.open();
    errdefer page.close();
    try page.run(
        \\globalThis.root = document.createElement('div');
        \\globalThis.a = root.appendChild(document.createElement('i'));
        \\globalThis.b = root.appendChild(document.createElement('b'));
        \\globalThis.other = document.createElement('u');
    );
    return page;
}

fn iteratorCountsItsNodes() !void {
    const page = try openTree();
    defer page.close();
    const root = try page.node("root");
    const a = try page.node("a");
    try expectCount(1, root, "root, before any iterator");
    // createNodeIterator steps 2-3: root and reference are the root.
    try page.run("globalThis.it = document.createNodeIterator(root);");
    try expectCount(3, root, "root, the iterator's root and reference");
    // The first nextNode() returns the root itself; the second moves the
    // reference to a. The candidate is let go when each traversal returns.
    try page.run("if (it.nextNode() !== root || it.nextNode() !== a) throw new Error('order');");
    try expectCount(2, root, "root, the root only");
    try expectCount(2, a, "a, the reference");
    try page.run("it = null;");
    try page.collect();
    try expectCount(1, root, "root, after the iterator was collected");
    try expectCount(1, a, "a, after the iterator was collected");
}

test "a NodeIterator takes one counted reference on its root and its reference, and releases them" {
    try onFreshThread(iteratorCountsItsNodes);
}

fn walkerCountsItsNodes() !void {
    const page = try openTree();
    defer page.close();
    const root = try page.node("root");
    const a = try page.node("a");
    const other = try page.node("other");
    try page.run("globalThis.tw = document.createTreeWalker(root);");
    try expectCount(3, root, "root, the walker's root and current node");
    try page.run("if (tw.firstChild() !== a) throw new Error('firstChild');");
    try expectCount(2, root, "root, the root only");
    try expectCount(2, a, "a, the current node");
    // The currentNode setter takes any node, in any tree.
    try page.run("tw.currentNode = other;");
    try expectCount(1, a, "a, after the current node left it");
    try expectCount(2, other, "other, the current node");
    try page.run("tw = null;");
    try page.collect();
    try expectCount(1, root, "root, after the walker was collected");
    try expectCount(1, other, "other, after the walker was collected");
}

test "a TreeWalker takes one counted reference on its root and its current node, and releases them" {
    try onFreshThread(walkerCountsItsNodes);
}

/// Reads one node's count each time the page calls `probe()`.
const CountProbe = struct {
    node: *dom.NodeBase,
    seen: [4]u32 = .{ 0, 0, 0, 0 },
    calls: usize = 0,

    fn steps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
        const self: *CountProbe = @ptrCast(@alignCast(data.?));
        if (self.calls < self.seen.len) self.seen[self.calls] = dom.refcount.count(self.node);
        self.calls += 1;
        return .undefined;
    }
};

fn filterHoldsItsNode() !void {
    const page = try openTree();
    defer page.close();
    const a = try page.node("a");
    var probe: CountProbe = .{ .node = a };
    const callback: engine.BuiltinFunction = .{ .steps = CountProbe.steps, .data = &probe };
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    try engine.defineBuiltinFunction(realm, "probe", 0, &callback);
    try expectCount(1, a, "a, before any traversal");
    // A NodeIterator filtering a: a is its candidate, and the traversal holds
    // the node it hands the filter across the call.
    try page.run(
        \\globalThis.it = document.createNodeIterator(root, NodeFilter.SHOW_ALL, n => { if (n === a) probe(); return NodeFilter.FILTER_SKIP; });
        \\it.nextNode();
    );
    // A TreeWalker filtering a: only the filter's hold (a is not current).
    try page.run(
        \\globalThis.tw = document.createTreeWalker(root, NodeFilter.SHOW_ALL, n => { if (n === a) probe(); return NodeFilter.FILTER_SKIP; });
        \\tw.firstChild();
    );
    try testing.expectEqual(@as(usize, 2), probe.calls);
    if (probe.seen[0] != 3 or probe.seen[1] != 2) {
        std.debug.print("a while filtered: iterator {d} (expected 3), walker {d} (expected 2)\n", .{ probe.seen[0], probe.seen[1] });
        return error.WrongCount;
    }
    try expectCount(1, a, "a, after both traversals returned");
    try page.run("it = null; tw = null;");
}

test "a traversal holds the node it hands its filter across the call" {
    try onFreshThread(filterHoldsItsNode);
}
