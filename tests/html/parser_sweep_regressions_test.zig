//! Regressions found by the parser lane's complete worklist comparison.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");

const Fixture = struct {
    context: runtime.ContextData,
    document: *runtime.Instance,

    fn init(self: *Fixture) !void {
        interfaces.process_hooks.startHooksForTest();
        runtime.initializeRuntime(std.testing.allocator);
        self.context = try runtime.ContextData.init(std.testing.allocator, .{});
        self.document = try interfaces.Document.call_constructor(&self.context);
        try dom.document_internals.setDocumentType(self.document, .html);
    }

    fn deinit(self: *Fixture) void {
        dom.node_creation.destroyUninserted(self.document);
        self.context.deinit();
        runtime.deinitializeRuntime();
    }
};

test "outerHTML uses a temporary body for a DocumentFragment parent and reclaims it" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const before = runtime.SlabAllocator.get().stats().currently_allocated;
    for (0..10) |_| {
        const fragment = try interfaces.Document.call_createDocumentFragment(fixture.document);
        defer dom.node_creation.destroyUninserted(fragment);
        const old = try interfaces.Document.call_createElement(fixture.document, runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
        defer if ((interfaces.Node.get_parentNode(old) catch null) == null) dom.node_creation.destroyUninserted(old);
        _ = try interfaces.Node.call_appendChild(fragment, old);
        try interfaces.Element.set_outerHTML(old, .{ .domstring = runtime.DOMString.initInterned("<body><span>replaced</span></body>") });
        try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_parentNode(old));
        const replacement = (try interfaces.Node.get_firstChild(fragment)).?;
        var name = try interfaces.Element.get_localName(replacement);
        defer name.deinit(fixture.context.allocator);
        try std.testing.expectEqualStrings("span", name.asSlice());
        try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_nextSibling(replacement));
    }
    try std.testing.expectEqual(before, runtime.SlabAllocator.get().stats().currently_allocated);
}

test "cloning character data creates it in the destination document context" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    var destination_context = try runtime.ContextData.init(std.testing.allocator, .{});
    defer destination_context.deinit();
    const destination = try interfaces.Document.call_constructor(&destination_context);
    defer dom.node_creation.destroyUninserted(destination);
    inline for (.{ interfaces.Text, interfaces.Comment }) |Interface| {
        const source = try Interface.call_constructor(&fixture.context, .{ .was_passed = true, .value = runtime.DOMString.initInterned("x") });
        defer dom.node_creation.destroyUninserted(source);
        try dom.node_document.set(source, fixture.document);
        const copy = try dom.node_creation.clone(source, destination, false, null);
        defer dom.node_creation.destroyUninserted(copy);
        try std.testing.expect(copy.ctx == &destination_context);
        try std.testing.expectEqual(destination, (try interfaces.Node.get_ownerDocument(copy)).?);
        var data = try interfaces.CharacterData.get_data(copy);
        defer data.deinit(copy.ctx.allocator);
        try std.testing.expectEqualStrings("x", data.asSlice());
    }
}

test "SVG script cloning copies already started without copying parser insertion" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const source = try interfaces.Document.call_createElementNS(fixture.document, runtime.DOMString.initInterned("http://www.w3.org/2000/svg"), runtime.DOMString.initInterned("script"), .{ .was_passed = false, .value = undefined });
    defer dom.node_creation.destroyUninserted(source);
    dom.script_elements.markParserInserted(source, fixture.document);
    dom.script_elements.markAlreadyStarted(source);
    const copy = try dom.node_creation.clone(source, fixture.document, true, null);
    defer dom.node_creation.destroyUninserted(copy);
    const flags = dom.script_elements.svgFlags(copy).?;
    try std.testing.expect(flags.already_started);
    try std.testing.expect(!flags.parser_inserted);
}
