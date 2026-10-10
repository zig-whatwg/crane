//! The DOM tree version (Blink `Document::dom_tree_version_`), kept beside the
//! reference counts (src/dom/refcount.zig, `treeVersion`): a live collection
//! caches its walk under it, so it must move on every change a collection can
//! see - insert, remove, replace, move, adoption (both documents), any
//! attribute set or removal, and a free that bypasses the mutation
//! algorithms (a tree's teardown) - and be null for anything that is not a
//! live Document.
const std = @import("std");
const dom = @import("dom");
const runtime = @import("runtime");
const interfaces = @import("interfaces");

const allocator = std.testing.allocator;
const refcount = dom.refcount;

fn version(document: *runtime.Instance) u64 {
    return refcount.treeVersion(document).?;
}

/// Checks that `document`'s version moved from `before`, and returns it.
fn expectMoves(document: *runtime.Instance, before: u64) !u64 {
    const after = version(document);
    try std.testing.expect(after != before);
    return after;
}

const Fixture = struct {
    ctx: runtime.ContextData,
    document: *runtime.Instance,
    other: *runtime.Instance,
    body: *runtime.Instance,
    /// A shadow root, freed after the documents (its host's teardown leaves
    /// it to its owner, as tests/dom/shadow_host_flag_test.zig does).
    shadow: ?*runtime.Instance = null,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(allocator);
        self.* = .{ .ctx = try runtime.ContextData.init(allocator, .{}), .document = undefined, .other = undefined, .body = undefined };
        self.document = try newDocument(&self.ctx);
        self.other = try newDocument(&self.ctx);
        const html = try element(self.document, "html");
        _ = try interfaces.Node.call_appendChild(self.document, html);
        self.body = try element(self.document, "body");
        _ = try interfaces.Node.call_appendChild(html, self.body);
    }

    fn newDocument(ctx: *runtime.ContextData) !*runtime.Instance {
        const document = try interfaces.Document.init(allocator, ctx);
        try dom.document_internals.setContentType(document, "text/html");
        try dom.document_internals.setDocumentType(document, .html);
        return document;
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        interfaces.Document.deinit(self.other);
        if (self.shadow) |shadow| interfaces.ShadowRoot.deinit(shadow);
        self.ctx.deinit();
        runtime.deinitializeRuntime();
    }

    fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
        return interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
    }

    /// A detached `div` with two `span` children, made in `document`.
    fn smallTree(document: *runtime.Instance) !*runtime.Instance {
        const div = try element(document, "div");
        _ = try interfaces.Node.call_appendChild(div, try element(document, "span"));
        _ = try interfaces.Node.call_appendChild(div, try element(document, "span"));
        return div;
    }
};

test "treeVersion is null for an instance that is not a Document" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try std.testing.expect(refcount.treeVersion(f.body) == null);
    try std.testing.expect(refcount.treeVersion(f.document) != null);
}

test "insert, remove and replace move the version" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    var v = version(f.document);
    const div = try Fixture.smallTree(f.document);
    v = version(f.document);
    _ = try interfaces.Node.call_appendChild(f.body, div);
    v = try expectMoves(f.document, v);
    const p = try Fixture.element(f.document, "p");
    v = version(f.document);
    _ = try interfaces.Node.call_replaceChild(f.body, p, div);
    v = try expectMoves(f.document, v);
    _ = try interfaces.Node.call_removeChild(f.body, p);
    v = try expectMoves(f.document, v);
    // A change inside a detached tree of the document moves it too: a
    // collection rooted there caches under the same number.
    _ = try interfaces.Node.call_appendChild(p, try Fixture.element(f.document, "b"));
    _ = try expectMoves(f.document, v);
    dom.node_creation.destroyUninserted(p);
    dom.node_creation.destroyUninserted(div);
}

test "moveBefore moves the version" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const a = try Fixture.element(f.document, "section");
    const b = try Fixture.element(f.document, "section");
    _ = try interfaces.Node.call_appendChild(f.body, a);
    _ = try interfaces.Node.call_appendChild(f.body, b);
    const moved = try Fixture.element(f.document, "i");
    _ = try interfaces.Node.call_appendChild(a, moved);
    const v = version(f.document);
    try interfaces.ParentNode.call_moveBefore(b, moved, null);
    _ = try expectMoves(f.document, v);
}

test "adoption moves the version of both documents" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.smallTree(f.document);
    defer dom.node_creation.destroyUninserted(div);
    const from = version(f.document);
    const to = version(f.other);
    _ = try interfaces.Document.call_adoptNode(f.other, div);
    _ = try expectMoves(f.document, from);
    _ = try expectMoves(f.other, to);
}

test "any attribute set or removal moves the version" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const div = try Fixture.element(f.document, "div");
    _ = try interfaces.Node.call_appendChild(f.body, div);
    var v = version(f.document);
    try interfaces.Element.call_setAttribute(div, runtime.DOMString.initInterned("data-anything"), .{ .domstring = runtime.DOMString.initInterned("1") });
    v = try expectMoves(f.document, v);
    try interfaces.Element.call_setAttribute(div, runtime.DOMString.initInterned("data-anything"), .{ .domstring = runtime.DOMString.initInterned("2") });
    v = try expectMoves(f.document, v);
    try interfaces.Element.call_removeAttribute(div, runtime.DOMString.initInterned("data-anything"));
    v = try expectMoves(f.document, v);
    try interfaces.Element.call_setAttribute(div, runtime.DOMString.initInterned("href"), .{ .domstring = runtime.DOMString.initInterned("#x") });
    _ = try expectMoves(f.document, v);
}

test "a teardown that bypasses mutation moves the version" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const fragment = try interfaces.Document.call_createDocumentFragment(f.document);
    _ = try interfaces.Node.call_appendChild(fragment, try Fixture.smallTree(f.document));
    const v = version(f.document);
    // The fragment and its subtree are freed by the tree's teardown, with no
    // removal: every node freed moves the version.
    dom.node_creation.destroyUninserted(fragment);
    _ = try expectMoves(f.document, v);
}
