//! An element's attribute list, its ID and classes and its qualified name are
//! one object, `dom.element_data.ElementData` (impls boundary B4,
//! tmp/plans/impls-boundary-design.md 3.3): Element's state embeds it, and the
//! tree's own algorithms - the selector matcher, getElementById, named access,
//! the HTML elements' reflection - read it in place through
//! `dom.element_data.of`, where they used to name Element's impl. WebKit's
//! split: Source/WebCore/dom/ElementData.h, held by Element.
//!
//! - The reads are DOM's own algorithms over the data ("get an attribute by
//!   namespace and local name", "get an attribute value"), borrowing the
//!   attribute's bytes.
//! - The writes stay Element's, where the mutation record, the custom element
//!   reaction and the attribute change steps run: `dom.element_attributes.set`
//!   ("set an attribute value") and `remove` ("remove an attribute by namespace
//!   and local name"). The ID and class caches follow them.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const infra = @import("infra");

const allocator = testing.allocator;

fn str(text: []const u8) runtime.DOMString {
    return runtime.DOMString.initInterned(text);
}

/// An engine-less page: an HTML document with one div.
const Page = struct {
    scope: runtime.BrowserScope,
    ctx: runtime.ContextData,
    document: *runtime.Instance = undefined,
    div: *runtime.Instance = undefined,

    /// In place: the scope must not move once it has made an object.
    fn open(self: *Page) !void {
        interfaces.process_hooks.startHooksForTest();
        self.* = .{ .scope = runtime.BrowserScope.init(allocator), .ctx = try runtime.ContextData.init(allocator, .{}) };
        self.ctx.browser_scope = &self.scope;
        self.document = try interfaces.Document.init(allocator, &self.ctx);
        try dom.document_internals.setContentType(self.document, "text/html");
        try dom.document_internals.setDocumentType(self.document, .html);
        self.div = try interfaces.Document.call_createElement(self.document, str("div"), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(self.document, self.div);
    }

    fn close(self: *Page) void {
        interfaces.Document.deinit(self.document);
        dom.teardown_sweeps.runAll(&self.scope);
        self.scope.deinit();
        self.ctx.deinit();
    }
};

test "an element's data answers its qualified name, ID, classes and attributes in place" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    try interfaces.Element.call_setAttribute(page.div, str("id"), .{ .domstring = str("main") });
    try interfaces.Element.call_setAttribute(page.div, str("class"), .{ .domstring = str("a b") });
    try interfaces.Element.call_setAttribute(page.div, str("title"), .{ .domstring = str("t") });
    try interfaces.Element.call_setAttributeNS(page.div, str("urn:x"), str("x:title"), .{ .domstring = str("namespaced") });

    const data = dom.element_data.of(page.div) orelse return error.NoElementData;
    // The qualified name "create an element" gave it.
    try testing.expectEqualStrings("div", data.local_name.asSlice());
    try testing.expectEqualStrings(infra.namespaces.HTML_NAMESPACE, data.namespace_uri.?.asSlice());
    try testing.expect(data.prefix == null);
    // The ID and classes, as the attribute change steps keep them.
    try testing.expectEqualStrings("main", data.id.asSlice());
    try testing.expectEqualStrings("a b", data.class_name.asSlice());
    try testing.expectEqual(@as(usize, 4), data.getAttributeCount());

    // DOM "get an attribute by namespace and local name": a namespace of ""
    // is null, and the namespaced attribute of the same local name is
    // another attribute.
    const title = dom.element_data.getAttributeByNamespaceAndLocalName(data, "", "title") orelse return error.NoTitle;
    try testing.expectEqualStrings("t", title.value);
    const namespaced = dom.element_data.getAttributeByNamespaceAndLocalName(data, "urn:x", "title") orelse return error.NoNamespaced;
    try testing.expectEqualStrings("namespaced", namespaced.value);
    try testing.expectEqualStrings("x", namespaced.prefix.?);
    try testing.expect(dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "lang") == null);

    // DOM "get an attribute value": the value, or the empty string.
    try testing.expectEqualStrings("t", dom.element_data.getAttributeValue(data, "title", null));
    try testing.expectEqualStrings("namespaced", dom.element_data.getAttributeValue(data, "title", "urn:x"));
    try testing.expectEqualStrings("", dom.element_data.getAttributeValue(data, "lang", null));

    // A node that is no element has no element data.
    const text = try interfaces.Document.call_createTextNode(page.document, str("x"));
    _ = try interfaces.Node.call_appendChild(page.div, text);
    try testing.expect(dom.element_data.of(text) == null);
    try testing.expect(dom.element_data.of(page.document) == null);
}

test "writes go through Element: set and remove run the attribute change steps" {
    var page: Page = undefined;
    try page.open();
    defer page.close();

    // DOM "set an attribute value": appended when absent ...
    try dom.element_attributes.set(page.div, "id", "first", .{});
    try dom.element_attributes.set(page.div, "data-x", "1", .{});
    const data = dom.element_data.of(page.div) orelse return error.NoElementData;
    try testing.expectEqualStrings("first", data.id.asSlice());
    // ... and changed in place when present: the list keeps its order.
    try dom.element_attributes.set(page.div, "id", "second", .{});
    try testing.expectEqualStrings("second", data.id.asSlice());
    try testing.expectEqualStrings("id", data.attributeAt(0).?.local_name);
    try testing.expectEqualStrings("data-x", data.attributeAt(1).?.local_name);
    // The IDL getter sees the same attribute.
    var id = try interfaces.Element.get_id(page.div);
    defer id.deinit(page.ctx.allocator);
    try testing.expectEqualStrings("second", id.asSlice());

    // With a namespace and prefix, a different attribute.
    try dom.element_attributes.set(page.div, "id", "other", .{ .prefix = "p", .namespace = "urn:p" });
    try testing.expectEqualStrings("second", data.id.asSlice());
    try testing.expectEqualStrings("other", dom.element_data.getAttributeValue(data, "id", "urn:p"));

    // DOM "remove an attribute by namespace and local name": the null
    // namespace's, not the namespaced one; the ID is unset.
    dom.element_attributes.remove(page.div, null, "id");
    try testing.expectEqualStrings("", data.id.asSlice());
    try testing.expect(dom.element_data.getAttributeByNamespaceAndLocalName(data, null, "id") == null);
    try testing.expectEqualStrings("other", dom.element_data.getAttributeValue(data, "id", "urn:p"));
    // A namespace of "" is null here too; removing an absent one is nothing.
    dom.element_attributes.remove(page.div, "", "data-x");
    dom.element_attributes.remove(page.div, null, "data-x");
    try testing.expectEqual(@as(usize, 1), data.getAttributeCount());
}
