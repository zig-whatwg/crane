//! XML element step 11: use the inherited default namespace in both tags.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const serialization = @import("html").serialization;
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

fn append(page: *fixture.Page, parent: *runtime.Instance, namespace: []const u8, name: []const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(page.document, str(namespace), str(name), .notPassed());
    errdefer interfaces.Element.deinit(element);
    _ = try interfaces.Node.call_appendChild(parent, element);
    return element;
}

test "XML serialization drops element prefixes in the inherited default namespace without changing DOM prefixes" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const root = try append(&page, page.element, "urn:xr1", "root");
    const child = try append(&page, root, "urn:xr1", "p:child");
    _ = try append(&page, child, "urn:xr1", "q:leaf");
    var result = try serialization.xml(std.testing.allocator, root);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("<root xmlns=\"urn:xr1\"><child><leaf/></child></root>", result.asSlice());
    var prefix = (try interfaces.Element.get_prefix(child)).?;
    defer prefix.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("p", prefix.asSlice());
}

test "XML fragment serialization drops only prefixes in the inherited default namespace" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try @import("dom").document_internals.setDocumentType(page.document, .xml);
    const root = try append(&page, page.element, "urn:xr1", "root");
    const child = try append(&page, root, "urn:xr1", "p:child");
    _ = try append(&page, child, "urn:other", "q:leaf");
    var result = try serialization.outer(root);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("<root xmlns=\"urn:xr1\"><child><q:leaf xmlns:q=\"urn:other\"/></child></root>", result.asSlice());
}
