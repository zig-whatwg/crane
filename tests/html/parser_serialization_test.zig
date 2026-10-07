//! Namespace identity and escaping in template serialization, with leak checks.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

test "XML template serialization carries its namespace into content and releases strings" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    const ns = runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml");
    const template = try interfaces.Document.call_createElementNS(document, ns, runtime.DOMString.initInterned("template"), .{ .was_passed = false, .value = undefined });
    defer interfaces.HTMLTemplateElement.deinit(template);
    const child = try interfaces.Document.call_createElementNS(document, ns, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(try interfaces.HTMLTemplateElement.get_content(template), child);
    try interfaces.Element.call_setAttribute(child, runtime.DOMString.initInterned("title"), .{ .domstring = runtime.DOMString.initInterned("a\nb&c") });
    var serialized = try interfaces.Element.get_outerHTML(template);
    defer serialized.deinit(testing.allocator);
    try testing.expectEqualStrings("<template xmlns=\"http://www.w3.org/1999/xhtml\"><div title=\"a&#xA;b&amp;c\"></div></template>", serialized.asSlice());
}

test "HTML void serialization ignores DOM children but foreign names are not void" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    try dom.document_internals.setDocumentType(document, .html);
    const element = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("br"), .{ .was_passed = false, .value = undefined });
    defer interfaces.Element.deinit(element);
    _ = try interfaces.Node.call_appendChild(element, try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned("ignored")));
    var inner = try interfaces.Element.get_innerHTML(element);
    defer inner.deinit(testing.allocator);
    try testing.expectEqualStrings("", inner.asSlice());
    var outer = try interfaces.Element.get_outerHTML(element);
    defer outer.deinit(testing.allocator);
    try testing.expectEqualStrings("<br>", outer.asSlice());
    const foreign = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/2000/svg"), runtime.DOMString.initInterned("br"), .{ .was_passed = false, .value = undefined });
    defer dom.node_creation.destroyUninserted(foreign);
    _ = try interfaces.Node.call_appendChild(foreign, try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned("kept")));
    var foreign_outer = try interfaces.Element.get_outerHTML(foreign);
    defer foreign_outer.deinit(testing.allocator);
    try testing.expectEqualStrings("<br>kept</br>", foreign_outer.asSlice());
}

test "XML serialization scopes generated prefixes and frees them" {
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(testing.allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    const root = try interfaces.Document.call_createElementNS(document, null, runtime.DOMString.initInterned("r"), .{ .was_passed = false, .value = undefined });
    defer dom.node_creation.destroyUninserted(root);
    for ([_][]const u8{ "a", "b" }) |name| {
        const child = try interfaces.Document.call_createElementNS(document, null, runtime.DOMString.initInterned(name), .{ .was_passed = false, .value = undefined });
        _ = try interfaces.Node.call_appendChild(root, child);
        try interfaces.Element.call_setAttributeNS(child, runtime.DOMString.initInterned("urn:x"), runtime.DOMString.initInterned("x"), .{ .domstring = runtime.DOMString.initInterned("1") });
    }
    var serialized = try interfaces.Element.get_outerHTML(root);
    defer serialized.deinit(testing.allocator);
    try testing.expectEqualStrings("<r><a xmlns:ns1=\"urn:x\" ns1:x=\"1\"/><b xmlns:ns2=\"urn:x\" ns2:x=\"1\"/></r>", serialized.asSlice());
}
