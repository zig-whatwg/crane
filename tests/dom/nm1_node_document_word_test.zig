//! The node document as ONE word of NodeBase (lane nm1 batch 1, step 5; the
//! design's N4: "the second owner-document pointer" goes).
//!
//! A node named its document twice: NodeBase.owner_document, the Document's
//! NodeBase, which src/dom's algorithms read, and Node's own
//! `owner_document`, the Document's Instance, which the ownerDocument getter
//! and everything outside src/dom read - with a slab generation as the net
//! under "a node keeps its document". Both were written by one setter. They
//! are one word now, read through NodeBase's accessors:
//!
//! - `documentInstance()`: what Node's copy held;
//! - `documentBase()`: what NodeBase's copy held, and null - not a dangling
//!   pointer - once the document's slot was freed under the node;
//! - `documentKey()`: the identity `==` and `!= null` compared, with no read
//!   through the word (`keyAsDocument()` is a Document's own).
//!
//! These tests hold the rule the change was made under: every reader gets
//! the answer it got from its own copy. An owner-less NodeBase (the tests'
//! fixtures, the WithBase types) has no Instance: its document is a bare
//! NodeBase, kept in the same word (`setDocumentBase`).
//!
//! It names generated interfaces and src/dom only (AGENTS.md "The impls
//! boundary").

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const NodeBase = dom.NodeBase;

/// Whether NodeBase has the one-word node document (red before step 5).
const one_word = @hasDecl(NodeBase, "documentBase");

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

const no_options: @import("webidl").Opt(runtime.JSValue) = .{ .was_passed = false, .value = undefined };

/// An engine-less page (the fixture of tests/dom/perf3e1_element_registry_test.zig).
const Page = struct {
    allocator: std.mem.Allocator,
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    host: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page, allocator: std.mem.Allocator) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .allocator = allocator, .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try self.newDocument();
        self.host = try interfaces.Document.call_createElement(self.document, str("div"), no_options);
        _ = try interfaces.Node.call_appendChild(self.document, self.host);
    }

    fn newDocument(self: *Page) !*runtime.Instance {
        const document = try interfaces.Document.init(self.allocator, &self.ctx);
        try dom.document_internals.setContentType(document, "text/html");
        try dom.document_internals.setDocumentType(document, .html);
        _ = try dom.custom_elements.ensureGlobalRegistry(document);
        return document;
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

fn baseOf(instance: *runtime.Instance) !*NodeBase {
    return dom.instance_bridge.getNodeBase(instance) orelse error.NoNodeBase;
}

/// Every reader's answer for `node`, a node of `document`: the Instance, the
/// Document's NodeBase, the ownerDocument getter, the identity key.
fn expectDocument(node: *runtime.Instance, document: *runtime.Instance) !void {
    const base = try baseOf(node);
    const document_base = try baseOf(document);
    try testing.expectEqual(@as(?*runtime.Instance, document), base.documentInstance());
    try testing.expectEqual(@as(?*NodeBase, document_base), base.documentBase());
    try testing.expectEqual(@as(?*runtime.Instance, document), try interfaces.Node.get_ownerDocument(node));
    try testing.expect(base.documentKey() != 0);
    try testing.expectEqual(document_base.keyAsDocument(), base.documentKey());
    // src/dom's own reader of "the node document" agrees.
    try testing.expectEqual(@as(?*NodeBase, document_base), base.getNodeDocument());
}

test "a created element, a created Text and a parsed tree name their document once, and every reader agrees" {
    if (comptime !one_word) return error.NoDocumentWord;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const div = try interfaces.Document.call_createElement(page.document, str("div"), no_options);
    try expectDocument(div, page.document);
    const text = try interfaces.Document.call_createTextNode(page.document, str("x"));
    try expectDocument(text, page.document);
    _ = try interfaces.Node.call_appendChild(page.host, div);
    _ = try interfaces.Node.call_appendChild(div, text);
    try expectDocument(div, page.document);
    try expectDocument(text, page.document);

    try interfaces.Element.set_innerHTML(page.host, .{ .domstring = str("<p><b>t</b><!--c--></p>") });
    const p = (try interfaces.Node.get_firstChild(page.host)) orelse return error.NothingParsed;
    const b = (try interfaces.Node.get_firstChild(p)) orelse return error.NothingParsed;
    const t = (try interfaces.Node.get_firstChild(b)) orelse return error.NothingParsed;
    const c = (try interfaces.Node.get_nextSibling(b)) orelse return error.NothingParsed;
    inline for (.{ p, b, t, c }) |node| try expectDocument(node, page.document);
}

test "a Document names no node document: it is its own" {
    if (comptime !one_word) return error.NoDocumentWord;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();

    const base = try baseOf(page.document);
    try testing.expectEqual(@as(?*runtime.Instance, null), base.documentInstance());
    try testing.expectEqual(@as(?*NodeBase, null), base.documentBase());
    try testing.expectEqual(@as(usize, 0), base.documentKey());
    try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_ownerDocument(page.document));
    // A Document's own key is what its nodes' keys equal.
    try testing.expectEqual(@intFromPtr(page.document), base.keyAsDocument());
    // DOM: "the node document of a document is that document itself".
    try testing.expectEqual(@as(?*NodeBase, base), base.getNodeDocument());
}

test "adoption moves a whole tree's node document, for every reader at once" {
    if (comptime !one_word) return error.NoDocumentWord;
    var page: Page = undefined;
    try page.open(testing.allocator);
    defer page.close();
    const other = try page.newDocument();
    defer interfaces.Document.deinit(other);

    try interfaces.Element.set_innerHTML(page.host, .{ .domstring = str("<section><i>t</i></section>") });
    const section = (try interfaces.Node.get_firstChild(page.host)) orelse return error.NothingParsed;
    const i = (try interfaces.Node.get_firstChild(section)) orelse return error.NothingParsed;
    const t = (try interfaces.Node.get_firstChild(i)) orelse return error.NothingParsed;
    inline for (.{ section, i, t }) |node| try expectDocument(node, page.document);

    // DOM adopt: "set inclusiveDescendant's node document to document".
    _ = try interfaces.Document.call_adoptNode(other, section);
    inline for (.{ section, i, t }) |node| try expectDocument(node, other);
    // What stayed, stayed.
    try expectDocument(page.host, page.document);
    // The two documents' nodes do not share a key.
    try testing.expect((try baseOf(section)).documentKey() != (try baseOf(page.host)).documentKey());

    // And back, by insertion: "insert" adopts into the parent's document.
    _ = try interfaces.Node.call_appendChild(page.host, section);
    inline for (.{ section, i, t }) |node| try expectDocument(node, page.document);
}

test "an owner-less NodeBase keeps a bare NodeBase as its document, in the same word" {
    if (comptime !one_word) return error.NoDocumentWord;
    var document: NodeBase = .{ .node_type = NodeBase.DOCUMENT_NODE, .owner = NodeBase.ownerless(&testing.allocator) };
    var node: NodeBase = .{ .node_type = NodeBase.ELEMENT_NODE, .owner = NodeBase.ownerless(&testing.allocator) };

    try testing.expectEqual(@as(?*NodeBase, null), node.documentBase());
    try testing.expectEqual(@as(usize, 0), node.documentKey());

    node.setDocumentBase(&document);
    try testing.expectEqual(@as(?*NodeBase, &document), node.documentBase());
    try testing.expectEqual(@as(?*NodeBase, &document), node.getNodeDocument());
    // No Instance owns the document, so none is named.
    try testing.expectEqual(@as(?*runtime.Instance, null), node.documentInstance());
    try testing.expectEqual(document.keyAsDocument(), node.documentKey());
    try testing.expectEqual(@intFromPtr(&document), node.documentKey());

    node.setDocumentBase(null);
    try testing.expectEqual(@as(?*NodeBase, null), node.documentBase());
    try testing.expectEqual(@as(usize, 0), node.documentKey());
}
