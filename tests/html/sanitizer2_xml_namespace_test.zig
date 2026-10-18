//! XML namespace regressions use constructed DOM nodes, independent of parsing.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const serialization = @import("html").serialization;
const fixture = @import("rf_fixture.zig");
const str = fixture.str;
const xmlns = "http://www.w3.org/2000/xmlns/";

fn append(page: *fixture.Page, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(page.document, null, str(name), .notPassed());
    errdefer interfaces.Element.deinit(element);
    _ = try interfaces.Node.call_appendChild(parent, element);
    return element;
}

fn attribute(element: *runtime.Instance, namespace: []const u8, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttributeNS(element, str(namespace), str(name), .{ .domstring = str(value) });
}

fn expectXml(node: *runtime.Instance, expected: []const u8) !void {
    var result = try serialization.xml(std.testing.allocator, node);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, result.asSlice());
}

test "XML attributes do not rebind an ancestor prefix" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:p", "urn:one");
    const child = try append(&page, root, "child");
    try attribute(child, "urn:two", "p:value", "kept");
    try expectXml(root, "<root xmlns:p=\"urn:one\"><child xmlns:ns1=\"urn:two\" ns1:value=\"kept\"/></root>");
}

test "XML serialization retains an explicit empty default namespace" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns", "");
    try attribute(root, xmlns, "xmlns:foo", "");
    try expectXml(root, "<root xmlns=\"\" xmlns:foo=\"\"/>");
}

test "XML fragment serialization accepts an empty default namespace but rejects an empty prefix binding" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try @import("dom").document_internals.setDocumentType(page.document, .xml);
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns", "");
    var outer = try serialization.outer(root);
    defer outer.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("<root xmlns=\"\"/>", outer.asSlice());
    try attribute(root, xmlns, "xmlns:p", "");
    try std.testing.expectError(error.InvalidStateError, serialization.outer(root));
}

test "XML attributes cannot reuse a shadowed namespace prefix" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:p", "urn:one");
    try attribute(root, xmlns, "xmlns:q", "urn:one");
    const child = try append(&page, root, "child");
    try attribute(child, xmlns, "xmlns:q", "urn:two");
    try attribute(child, "urn:one", "value", "kept");
    const sibling = try append(&page, root, "sibling");
    try attribute(sibling, "urn:one", "q:value", "again");
    try expectXml(root, "<root xmlns:p=\"urn:one\" xmlns:q=\"urn:one\"><child xmlns:q=\"urn:two\" p:value=\"kept\"/><sibling q:value=\"again\"/></root>");
}

test "XML generated prefixes avoid local and inherited namespace declarations" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:ns2", "urn:two");
    const child = try append(&page, root, "child");
    try attribute(child, xmlns, "xmlns:ns1", "urn:one");
    try attribute(child, "urn:three", "value", "kept");
    try expectXml(root, "<root xmlns:ns2=\"urn:two\"><child xmlns:ns1=\"urn:one\" xmlns:ns3=\"urn:three\" ns3:value=\"kept\"/></root>");
}

test "XML elements use their matching explicit default namespace" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:p", "urn:one");
    const child = try interfaces.Document.call_createElementNS(page.document, str("urn:one"), str("child"), .notPassed());
    _ = try interfaces.Node.call_appendChild(root, child);
    try attribute(child, xmlns, "xmlns", "urn:one");
    try expectXml(root, "<root xmlns:p=\"urn:one\"><child xmlns=\"urn:one\"/></root>");
}

test "XML elements preserve a prefix when their namespace matches the inherited default" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try interfaces.Document.call_createElementNS(page.document, str("urn:one"), str("root"), .notPassed());
    _ = try interfaces.Node.call_appendChild(page.element, root);
    try attribute(root, xmlns, "xmlns", "urn:one");
    const child = try interfaces.Document.call_createElementNS(page.document, str("urn:one"), str("p:child"), .notPassed());
    _ = try interfaces.Node.call_appendChild(root, child);
    try attribute(child, xmlns, "xmlns:p", "urn:one");
    try expectXml(root, "<root xmlns=\"urn:one\"><p:child xmlns:p=\"urn:one\"/></root>");
}

test "XML prefix bindings restore an ancestor mapping after a shadowing child" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:p", "urn:one");
    const child = try append(&page, root, "child");
    try attribute(child, xmlns, "xmlns:p", "urn:two");
    const leaf = try append(&page, child, "leaf");
    try attribute(leaf, xmlns, "xmlns:p", "urn:one");
    try attribute(leaf, "urn:one", "p:value", "kept");
    try expectXml(root, "<root xmlns:p=\"urn:one\"><child xmlns:p=\"urn:two\"><leaf xmlns:p=\"urn:one\" p:value=\"kept\"/></child></root>");
}

fn serializeTrial(allocator: std.mem.Allocator, node: *runtime.Instance) !void {
    var result = try serialization.xml(allocator, node);
    defer result.deinit(allocator);
    try std.testing.expectEqualStrings("<root xmlns:ns1=\"urn:one\" xmlns:ns2=\"urn:two\" ns2:value=\"kept\"/>", result.asSlice());
}

test "XML generated prefixes and output are released on every allocation failure" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "root");
    try attribute(root, xmlns, "xmlns:ns1", "urn:one");
    try attribute(root, "urn:two", "value", "kept");
    try std.testing.checkAllAllocationFailures(std.testing.allocator, serializeTrial, .{root});
}
