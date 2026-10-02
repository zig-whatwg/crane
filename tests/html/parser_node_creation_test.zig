//! The nodes the scripting parser's DOM adapter makes for the tree builder:
//! their node type, an element's namespace and local name, a doctype's
//! identifiers.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#create-an-element-for-the-token
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#the-initial-insertion-mode
//!
//! The adapter makes them through their interfaces and sets what no IDL
//! member sets through dom.node_creation, which Element and DocumentType
//! install. These pin what it makes, so that no step the adapter drops - the
//! node type every node's init already sets - and no step it reroutes changes
//! a node.

const std = @import("std");
const html = @import("html");
const html_core = @import("html_core");
const runtime = @import("runtime");

const interfaces = html.interfaces;
const DomTreeAdapter = html.parser_script_execution.DomTreeAdapter;
const TreeNode = html_core.parser.TreeNode;

const testing = std.testing;

/// A runtime, a realm-less context and a document to parse into.
const Fixture = struct {
    ctx_data: runtime.ContextData,
    document: *runtime.Instance,

    fn init(self: *Fixture) !void {
        runtime.initializeRuntime(testing.allocator);
        self.ctx_data = try runtime.ContextData.init(testing.allocator, .{});
        self.document = try interfaces.Document.init(testing.allocator, &self.ctx_data);
    }

    fn deinit(self: *Fixture) void {
        interfaces.Document.deinit(self.document);
        self.ctx_data.deinit();
        runtime.deinitializeRuntime();
    }
};

fn expectString(expected: []const u8, actual: runtime.DOMString) !void {
    var owned = actual;
    defer owned.deinit(testing.allocator);
    try testing.expectEqualStrings(expected, owned.asSlice());
}

test "a foreign element the adapter makes is an element with the token's namespace and local name" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    var adapter = DomTreeAdapter.init(testing.allocator, &fixture.ctx_data, fixture.document);
    defer adapter.deinit();

    const svg_tn = try TreeNode.initElement(testing.allocator, "circle", .svg);
    defer svg_tn.deinit();
    try adapter.onNodeCreated(svg_tn);
    const svg = adapter.getDomNode(svg_tn).?;

    try testing.expectEqual(interfaces.Node.get_ELEMENT_NODE(), try interfaces.Node.get_nodeType(svg));
    try expectString("circle", try interfaces.Element.get_localName(svg));
    try expectString("http://www.w3.org/2000/svg", (try interfaces.Element.get_namespaceURI(svg)).?);

    const div_tn = try TreeNode.initElement(testing.allocator, "div", .html);
    defer div_tn.deinit();
    try adapter.onNodeCreated(div_tn);
    const div = adapter.getDomNode(div_tn).?;

    try testing.expectEqual(interfaces.Node.get_ELEMENT_NODE(), try interfaces.Node.get_nodeType(div));
    try expectString("div", try interfaces.Element.get_localName(div));
    try expectString("http://www.w3.org/1999/xhtml", (try interfaces.Element.get_namespaceURI(div)).?);
}

test "a comment the adapter makes is a comment node" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    var adapter = DomTreeAdapter.init(testing.allocator, &fixture.ctx_data, fixture.document);
    defer adapter.deinit();

    const comment_tn = try TreeNode.initComment(testing.allocator);
    defer comment_tn.deinit();
    try adapter.onNodeCreated(comment_tn);
    const comment = adapter.getDomNode(comment_tn).?;

    try testing.expectEqual(interfaces.Node.get_COMMENT_NODE(), try interfaces.Node.get_nodeType(comment));
}

test "a doctype the adapter makes has the token's name, public ID and system ID, and \"\" for a missing one" {
    // The hooks this test's objects reach (no Browser here: crane.Process is not started).
    @import("interfaces").process_hooks.startHooksForTest();
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();

    var adapter = DomTreeAdapter.init(testing.allocator, &fixture.ctx_data, fixture.document);
    defer adapter.deinit();

    const full_tn = try TreeNode.initDoctype(testing.allocator, "html", "-//W3C//DTD HTML 4.01//EN", "http://www.w3.org/TR/html4/strict.dtd", false);
    defer full_tn.deinit();
    try adapter.onNodeCreated(full_tn);
    const full = adapter.getDomNode(full_tn).?;

    try testing.expectEqual(interfaces.Node.get_DOCUMENT_TYPE_NODE(), try interfaces.Node.get_nodeType(full));
    try expectString("html", try interfaces.DocumentType.get_name(full));
    try expectString("-//W3C//DTD HTML 4.01//EN", try interfaces.DocumentType.get_publicId(full));
    try expectString("http://www.w3.org/TR/html4/strict.dtd", try interfaces.DocumentType.get_systemId(full));

    const bare_tn = try TreeNode.initDoctype(testing.allocator, "html", null, null, false);
    defer bare_tn.deinit();
    try adapter.onNodeCreated(bare_tn);
    const bare = adapter.getDomNode(bare_tn).?;

    try expectString("html", try interfaces.DocumentType.get_name(bare));
    try expectString("", try interfaces.DocumentType.get_publicId(bare));
    try expectString("", try interfaces.DocumentType.get_systemId(bare));
}
