//! HTML 13.4: fragment DOM construction preserves the target's registry.
//! Shared by Element and ShadowRoot; neither implementation calls the other.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const parser = @import("html_core").parser;
const creation = @import("creation.zig");
const parser_steps = @import("../parser_script_execution.zig");

pub fn parse(target: *runtime.Instance, input: []const u8) !*runtime.Instance {
    const allocator = target.ctx.allocator;
    const document = (try interfaces.Node.get_ownerDocument(target)) orelse return error.InvalidStateError;
    // Steps 2 and 13: a shadow root supplies the registry; its host supplies
    // the tokenizer context. These are deliberately separate inputs.
    const is_shadow = target.stateAs(interfaces.ShadowRoot.State) != null;
    const context = if (is_shadow) try interfaces.ShadowRoot.get_host(target) else target;
    const registry = if (is_shadow)
        try interfaces.ShadowRoot.get_customElementRegistry(target)
    else
        try interfaces.Element.get_customElementRegistry(target);
    var name = try interfaces.Element.get_localName(context);
    defer name.deinit(context.ctx.allocator);
    var ns = try interfaces.Element.get_namespaceURI(context);
    defer if (ns) |*value| value.deinit(context.ctx.allocator);
    const namespace: parser.Namespace = if (ns) |value| blk: {
        if (std.mem.eql(u8, value.asSlice(), "http://www.w3.org/2000/svg")) break :blk .svg;
        if (std.mem.eql(u8, value.asSlice(), "http://www.w3.org/1998/Math/MathML")) break :blk .mathml;
        break :blk .html;
    } else .html;
    const context_node = try parser.TreeNode.initElement(allocator, name.asSlice(), namespace);
    defer context_node.deinit();
    // Step 19 includes attributes (notably annotation-xml's encoding) used
    // to decide HTML integration points in foreign content.
    var index: usize = 0;
    while (dom.element_attributes.at(context, index)) |attribute| : (index += 1) {
        try context_node.addAttribute(attribute.local_name, attribute.value, null);
    }
    const mode: parser.QuirksMode = switch (dom.document_internals.getMode(document) orelse .no_quirks) {
        .no_quirks => .no_quirks,
        .quirks => .quirks,
        .limited_quirks => .limited_quirks,
    };
    var parsed = try parser.parseFragment(allocator, context_node, input, .{
        .quirks_mode = mode,
        .scripting_enabled = (try interfaces.Document.get_defaultView(document)) != null,
    });
    defer parsed.deinit();
    // Step 16: the returned fragment belongs to the target's document.
    const fragment = try interfaces.DocumentFragment.init(allocator, target.ctx);
    errdefer dom.node_creation.destroyUninserted(fragment);
    try dom.node_document.set(fragment, document);
    for (parsed.children) |child| try appendTree(document, registry, fragment, child);
    return fragment;
}

fn appendTree(document: *runtime.Instance, registry: ?*runtime.Instance, parent: *runtime.Instance, tree: *parser.TreeNode) !void {
    const node = switch (tree.node_type) {
        .element => blk: {
            const local_name = tree.local_name orelse return error.InvalidStateError;
            const namespace = switch (tree.namespace) {
                .html => creation.html_namespace,
                .svg => "http://www.w3.org/2000/svg",
                .mathml => "http://www.w3.org/1998/Math/MathML",
            };
            // Create-for-token: fragment construction enqueues upgrades; it
            // does not invoke constructors before token attributes are copied.
            const element = try creation.create(.{
                .document = document,
                .local_name = local_name,
                .namespace = namespace,
                .is_value = @import("parser.zig").isValue(tree),
                .registry = .{ .explicit = registry },
            });
            if (std.mem.eql(u8, local_name, "script")) {
                dom.script_elements.markParserInserted(element, document);
                dom.script_elements.markAlreadyStarted(element);
            }
            for (tree.attributes.toSlice()) |attribute| parser_steps.appendParsedAttribute(element, attribute);
            break :blk element;
        },
        .text => try interfaces.Document.call_createTextNode(document, runtime.DOMString.initInterned(tree.text_content.toSlice())),
        .comment => try interfaces.Document.call_createComment(document, runtime.DOMString.initInterned(tree.text_content.toSlice())),
        else => return error.InvalidStateError,
    };
    var attached = false;
    errdefer if (!attached) dom.node_creation.destroyUninserted(node);
    _ = try interfaces.Node.call_appendChild(parent, node);
    attached = true;
    var child = tree.first_child;
    while (child) |value| : (child = value.next_sibling) try appendTree(document, registry, node, value);
}
