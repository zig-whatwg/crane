//! DOM parser integration tests need the HTML test target with engine linkage.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const document_internals = @import("dom").document_internals;
const parseHTML = @import("html").dom_parser.parseHTML;
const parseFragment = @import("html").dom_parser.parseFragment;

test "DOM fragment modes use the full reset algorithm" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    try document_internals.setDocumentType(document, .html);
    const cases = .{
        .{ "frameset", "<template>x</template><frame>", "<frame>" },
        .{ "head", "<div>x</div>", "<div>x</div>" },
        .{ "td", "<tr><td>x", "x" },
    };
    inline for (cases) |case| {
        const element = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(case[0]), .{ .was_passed = false, .value = undefined });
        defer @import("dom").node_creation.destroyUninserted(element);
        try interfaces.Element.set_innerHTML(element, .{ .domstring = runtime.DOMString.initInterned(case[1]) });
        var markup = try interfaces.Element.get_innerHTML(element);
        defer markup.deinit(allocator);
        try std.testing.expectEqualStrings(case[2], markup.asSlice());
    }
}

test "innerHTML parses processing instructions and serializes them as <?target data?>" {
    // HTML 13.2.5.72-76 and "insert a processing instruction" through the
    // fragment parser; the serializer's ProcessingInstruction case appends
    // "<?", the target, a space, the data and "?>".
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const document = try interfaces.Document.call_constructor(&context);
    defer interfaces.Document.deinit(document);
    try document_internals.setDocumentType(document, .html);
    const cases = .{
        .{ "div", "<?pi data>x<?empty>", "<?pi data?>x<?empty ?>" },
        .{ "div", "<?a b??><?c ?d>", "<?a b??><?c ?d?>" },
        // Bogus comments: a disallowed target, a bad first character, a bad
        // target character.
        .{ "div", "<?xml v?><?1a><?a$b>", "<!--?xml v?--><!--?1a--><!--?a$b-->" },
        .{ "table", "<?pi><tr><td>x", "<?pi ?><tbody><tr><td>x</td></tr></tbody>" },
        .{ "template", "<?pi t>", "<?pi t?>" },
        .{ "textarea", "<?pi>", "&lt;?pi&gt;" },
    };
    inline for (cases) |case| {
        const element = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned(case[0]), .{ .was_passed = false, .value = undefined });
        defer @import("dom").node_creation.destroyUninserted(element);
        try interfaces.Element.set_innerHTML(element, .{ .domstring = runtime.DOMString.initInterned(case[1]) });
        var markup = try interfaces.Element.get_innerHTML(element);
        defer markup.deinit(allocator);
        try std.testing.expectEqualStrings(case[2], markup.asSlice());
    }
}

test "a parsed document puts a processing instruction before the html element in the Document" {
    // The "initial" insertion mode: "Insert a processing instruction given
    // (the Document object, null)" - through the tree-then-convert path.
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();

    const doc = try parseHTML(allocator, &context, "<?first one><!DOCTYPE html><body><?second two?>", .{});
    defer interfaces.Document.deinit(doc);

    const first = (try interfaces.Node.get_firstChild(doc)).?;
    try std.testing.expectEqual(interfaces.Node.get_PROCESSING_INSTRUCTION_NODE(), try interfaces.Node.get_nodeType(first));
    var target = try interfaces.ProcessingInstruction.get_target(first);
    defer target.deinit(allocator);
    try std.testing.expectEqualStrings("first", target.asSlice());
    try std.testing.expectEqual(doc, (try interfaces.Node.get_ownerDocument(first)).?);
    // Before the doctype, it leaves the document in no-quirks mode.
    try std.testing.expect(document_internals.getMode(doc).? == .no_quirks);

    const body = (try interfaces.Document.get_body(doc)).?;
    var markup = try interfaces.Element.get_innerHTML(body);
    defer markup.deinit(allocator);
    try std.testing.expectEqualStrings("<?second two?>", markup.asSlice());
}

test "HTMLParser - parse simple HTML document" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const ctx = &context;

    const doc = try parseHTML(allocator, ctx, "<!DOCTYPE html><html><head></head><body>Hello</body></html>", .{});
    defer interfaces.Document.deinit(doc);

    // Verify document was created
    try std.testing.expectEqual(interfaces.Node.get_DOCUMENT_NODE(), try interfaces.Node.get_nodeType(doc));

    // Verify document element exists
    try std.testing.expect(document_internals.getDocumentElement(doc) != null);
    try std.testing.expect(document_internals.getDocumentType(doc) == .html);
}

test "HTMLParser - parse HTML with nested elements" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const ctx = &context;

    const html =
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>Test</title></head>
        \\<body>
        \\  <div id="main">
        \\    <p>Paragraph 1</p>
        \\    <p>Paragraph 2</p>
        \\  </div>
        \\</body>
        \\</html>
    ;

    const doc = try parseHTML(allocator, ctx, html, .{});
    defer interfaces.Document.deinit(doc);

    try std.testing.expect(document_internals.getDocumentElement(doc) != null);
}

test "HTMLParser - parse fragment" {
    const allocator = std.testing.allocator;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(allocator);
    defer runtime.deinitializeRuntime();
    var context = try runtime.ContextData.init(allocator, .{});
    defer context.deinit();
    const ctx = &context;

    const frag = try parseFragment(allocator, ctx, "<div>Hello</div><span>World</span>", null);
    defer interfaces.DocumentFragment.deinit(frag);

    try std.testing.expect((try interfaces.Node.get_firstChild(frag)) != null);
}
