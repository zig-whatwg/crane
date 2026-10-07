//! Template ownership with a leak-checking allocator and no JavaScript engine.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const parser = @import("html").dom_parser;

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
        interfaces.Document.deinit(self.document);
        self.context.deinit();
        runtime.deinitializeRuntime();
    }
};

fn template(document: *runtime.Instance) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("template"), .{ .was_passed = false, .value = undefined });
}

test "template host cycle detection has no nesting depth cutoff" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const root = try template(fixture.document);
    defer interfaces.HTMLTemplateElement.deinit(root);
    var current = root;
    for (0..80) |_| {
        const next = try template(fixture.document);
        _ = try interfaces.Node.call_appendChild(try interfaces.HTMLTemplateElement.get_content(current), next);
        current = next;
    }
    try std.testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(try interfaces.HTMLTemplateElement.get_content(current), root));
}

test "template fragments share one inert document and are freed with their hosts" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const first = try template(fixture.document);
    defer interfaces.HTMLTemplateElement.deinit(first);
    const second = try template(fixture.document);
    defer interfaces.HTMLTemplateElement.deinit(second);
    const content = try interfaces.HTMLTemplateElement.get_content(first);
    try std.testing.expectEqual(content, try interfaces.HTMLTemplateElement.get_content(first));
    const owner = (try interfaces.Node.get_ownerDocument(content)).?;
    try std.testing.expect(owner != fixture.document);
    try std.testing.expectEqual(owner, (try interfaces.Node.get_ownerDocument(try interfaces.HTMLTemplateElement.get_content(second))).?);
    const nested = try template(owner);
    _ = try interfaces.Node.call_appendChild(content, nested);
    try std.testing.expectEqual(owner, (try interfaces.Node.get_ownerDocument(try interfaces.HTMLTemplateElement.get_content(nested))).?);
    try std.testing.expectEqual(first, dom.template_contents.host(content).?);
    try std.testing.expectError(error.HierarchyRequestError, interfaces.Node.call_appendChild(content, first));
}

test "template parsing cloning and adoption preserve the existing fragment" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const source = try template(fixture.document);
    defer interfaces.HTMLTemplateElement.deinit(source);
    const content = try interfaces.HTMLTemplateElement.get_content(source);
    const fragment = try parser.parseFragment(std.testing.allocator, &fixture.context, "<template><span>x</span></template>", source);
    defer interfaces.DocumentFragment.deinit(fragment);
    _ = try interfaces.Node.call_appendChild(content, fragment);
    const clone = try dom.node_creation.clone(source, fixture.document, true, null);
    defer interfaces.HTMLTemplateElement.deinit(clone);
    const copied = try interfaces.HTMLTemplateElement.get_content(clone);
    try std.testing.expect(copied != content);
    const nested = (try interfaces.Node.get_firstChild(copied)).?;
    const nested_content = try interfaces.HTMLTemplateElement.get_content(nested);
    try std.testing.expect((try interfaces.Node.get_firstChild(nested_content)) != null);

    const other = try interfaces.Document.call_constructor(&fixture.context);
    defer interfaces.Document.deinit(other);
    _ = try interfaces.Document.call_adoptNode(other, clone);
    try std.testing.expectEqual(copied, try interfaces.HTMLTemplateElement.get_content(clone));
    const owner = try dom.template_contents.ownerDocument(other);
    try std.testing.expectEqual(owner, (try interfaces.Node.get_ownerDocument(copied)).?);
    try std.testing.expectEqual(owner, (try interfaces.Node.get_ownerDocument(nested_content)).?);
}

test "unwrapped parser subtrees return their instance slots and state blocks" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const slots_before = runtime.SlabAllocator.get().stats().currently_allocated;
    const bytes_before = runtime.ArenaAllocator.get().stats().bytes_in_use;
    const fragment = try parser.parseFragment(std.testing.allocator, &fixture.context, "<b><p>x</b>", null);
    dom.node_creation.destroyUninserted(fragment);
    try std.testing.expectEqual(slots_before, runtime.SlabAllocator.get().stats().currently_allocated);
    try std.testing.expectEqual(bytes_before, runtime.ArenaAllocator.get().stats().bytes_in_use);
}

test "repeated unwrapped template parse clone and import have no retained native storage" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    // The one inert owner belongs to the document, across every cycle.
    _ = try dom.template_contents.ownerDocument(fixture.document);
    const slots_before = runtime.SlabAllocator.get().stats().currently_allocated;
    const bytes_before = runtime.ArenaAllocator.get().stats().bytes_in_use;
    for (0..50) |_| {
        const source = try template(fixture.document);
        try interfaces.Element.set_innerHTML(source, .{ .domstring = runtime.DOMString.initInterned("<b><p>x</b>") });
        const clone = try interfaces.Node.call_cloneNode(source, .{ .was_passed = true, .value = true });
        const imported = try interfaces.Document.call_importNode(fixture.document, clone, .{ .was_passed = true, .value = .{ .boolean = true } });
        dom.node_creation.destroyUninserted(imported);
        dom.node_creation.destroyUninserted(clone);
        dom.node_creation.destroyUninserted(source);
        try std.testing.expectEqual(slots_before, runtime.SlabAllocator.get().stats().currently_allocated);
        try std.testing.expectEqual(bytes_before, runtime.ArenaAllocator.get().stats().bytes_in_use);
    }
}

// Integration regression: innerHTML's CE-aware entry point must share the
// parser's template-content insertion rules.
test "CE fragment parsing puts nested template descendants in content" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const source = try template(fixture.document);
    defer interfaces.HTMLTemplateElement.deinit(source);
    const fragment = try @import("html").custom_elements.parseFragment(source, "<template><span>x</span></template>");
    defer dom.node_creation.destroyUninserted(fragment);
    const nested = (try interfaces.Node.get_firstChild(fragment)).?;
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_firstChild(nested));
    const content = try interfaces.HTMLTemplateElement.get_content(nested);
    try std.testing.expect((try interfaces.Node.get_firstChild(content)) != null);
}

test "fragment registry inheritance stops at nested template contents" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const registry = try interfaces.CustomElementRegistry.call_constructor(&fixture.context);
    defer runtime.Instance.deinit(registry);
    try interfaces.CustomElementRegistry.call_initialize(registry, fixture.document);
    const context = try interfaces.Document.call_createElement(fixture.document, .initInterned("div"), .notPassed());
    defer dom.node_creation.destroyUninserted(context);
    const fragment = try @import("html").custom_elements.parseFragment(context, "<template><span></span></template><b></b>");
    defer dom.node_creation.destroyUninserted(fragment);
    const nested = (try interfaces.Node.get_firstChild(fragment)).?;
    try std.testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Element.get_customElementRegistry(nested));
    const sibling = (try interfaces.Node.get_nextSibling(nested)).?;
    try std.testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Element.get_customElementRegistry(sibling));
    const content = try interfaces.HTMLTemplateElement.get_content(nested);
    const span = (try interfaces.Node.get_firstChild(content)).?;
    // Look up a custom element registry step 4: a template's fragment has
    // no registry. Its descendants must not inherit the outer root's one.
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Element.get_customElementRegistry(span));
}

test "template fragment context creates top-level descendants without a registry" {
    var fixture: Fixture = undefined;
    try fixture.init();
    defer fixture.deinit();
    const registry = try interfaces.CustomElementRegistry.call_constructor(&fixture.context);
    defer runtime.Instance.deinit(registry);
    try interfaces.CustomElementRegistry.call_initialize(registry, fixture.document);
    const context = try template(fixture.document);
    defer dom.node_creation.destroyUninserted(context);
    try std.testing.expectEqual(@as(?*runtime.Instance, registry), try interfaces.Element.get_customElementRegistry(context));

    const fragment = try parser.parseFragment(std.testing.allocator, &fixture.context, "<some-element><span></span></some-element>", context);
    defer dom.node_creation.destroyUninserted(fragment);
    const child = (try interfaces.Node.get_firstChild(fragment)).?;
    const grandchild = (try interfaces.Node.get_firstChild(child)).?;
    // HTML create-for-token step 6 consults the intended parent: the
    // template's content fragment, which has no custom-element registry.
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Element.get_customElementRegistry(child));
    try std.testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Element.get_customElementRegistry(grandchild));
}
