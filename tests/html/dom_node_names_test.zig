//! DOM members whose answers depend on a node's kind, namespace and document,
//! which XML documents exercise: nodeValue (DOM 4.4), tagName's
//! "HTML-uppercased qualified name" (DOM 4.9) and SVG 2's
//! Document.rootElement.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const html_ns = "http://www.w3.org/1999/xhtml";
const svg_ns = "http://www.w3.org/2000/svg";

const Harness = struct {
    context: runtime.ContextData,

    fn init(self: *Harness) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.context = try runtime.ContextData.init(std.testing.allocator, .{});
    }

    fn deinit(self: *Harness) void {
        self.context.deinit();
        runtime.deinitializeRuntime();
    }

    fn document(self: *Harness, kind: dom.document_internals.DocType) !*runtime.Instance {
        const doc = try interfaces.Document.call_constructor(&self.context);
        try dom.document_internals.setDocumentType(doc, kind);
        return doc;
    }
};

/// A new element in `document`, appended to `parent` (the document when null).
fn elementNS(document: *runtime.Instance, parent: ?*runtime.Instance, namespace: ?[]const u8, qualified: []const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(
        document,
        if (namespace) |ns| runtime.DOMString.initInterned(ns) else null,
        runtime.DOMString.initInterned(qualified),
        .{ .was_passed = false, .value = undefined },
    );
    _ = try interfaces.Node.call_appendChild(parent orelse document, element);
    return element;
}

fn expectTagName(element: *runtime.Instance, expected: []const u8) !void {
    var name = try interfaces.Element.get_tagName(element);
    defer name.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, name.asSlice());
}

test "nodeValue is null for an element, a document, a doctype and a fragment" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const document = try h.document(.html);
    defer interfaces.Document.deinit(document);
    const element = try elementNS(document, null, html_ns, "div");
    try std.testing.expect(try interfaces.Node.get_nodeValue(element) == null);
    try std.testing.expect(try interfaces.Node.get_nodeValue(document) == null);
    const fragment = try interfaces.Document.call_createDocumentFragment(document);
    defer dom.node_creation.destroyUninserted(fragment);
    try std.testing.expect(try interfaces.Node.get_nodeValue(fragment) == null);
    const text = try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned("x"));
    defer dom.node_creation.destroyUninserted(text);
    var value = (try interfaces.Node.get_nodeValue(text)).?;
    defer value.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("x", value.asSlice());
}

test "tagName is uppercased only for an HTML-namespace element in an HTML document" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const html = try h.document(.html);
    defer interfaces.Document.deinit(html);
    const div = try elementNS(html, null, html_ns, "x:div");
    try expectTagName(div, "X:DIV");
    try expectTagName(try elementNS(html, div, null, "foo"), "foo");
    try expectTagName(try elementNS(html, div, svg_ns, "foreignObject"), "foreignObject");

    const xml = try h.document(.xml);
    defer interfaces.Document.deinit(xml);
    const root = try elementNS(xml, null, html_ns, "div");
    try expectTagName(root, "div");
}

test "rootElement is the document element when it is an svg element" {
    var h: Harness = undefined;
    try h.init();
    defer h.deinit();
    const svg_doc = try h.document(.xml);
    defer interfaces.Document.deinit(svg_doc);
    try std.testing.expect(try interfaces.Document.get_rootElement(svg_doc) == null);
    const svg = try elementNS(svg_doc, null, svg_ns, "svg");
    try std.testing.expectEqual(svg, (try interfaces.Document.get_rootElement(svg_doc)).?);

    const other = try h.document(.xml);
    defer interfaces.Document.deinit(other);
    _ = try elementNS(other, null, svg_ns, "g");
    try std.testing.expect(try interfaces.Document.get_rootElement(other) == null);
}
