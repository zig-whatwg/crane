const std = @import("std");
const Node = @import("node").Node;
const Element = @import("element").Element;
const DocumentFragment = @import("document_fragment").DocumentFragment;
const ShadowRoot = @import("shadow_root").ShadowRoot;
const ShadowRootMode = @import("shadow_root").ShadowRootMode;
const SlotAssignmentMode = @import("shadow_root").SlotAssignmentMode;

test "Node.cloneNode - ShadowRoot throws NotSupportedError" {
    const allocator = std.testing.allocator;

    var host = try Element.create(allocator, "div", null, null);
    defer host.deinit();

    // Create a ShadowRoot
    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.open,
        false, // delegates_focus
        SlotAssignmentMode.named,
        false, // clonable (explicitly non-clonable for this test)
        false, // serializable
        false, // available_to_element_internals
        false, // declarative
    );
    defer shadow.deinit();

    const shadow_node = shadow.asNode();

    // Attempting to clone a ShadowRoot should throw NotSupportedError
    const result = shadow_node.call_cloneNode(false);
    try std.testing.expectError(error.NotSupportedError, result);
}

test "Node.cloneNode - DocumentFragment can be cloned" {
    const allocator = std.testing.allocator;

    var frag = try DocumentFragment.create(allocator);
    defer frag.deinit();

    const frag_node = frag.asNode();

    // Cloning a DocumentFragment should succeed
    const cloned = try frag_node.call_cloneNode(false);
    defer cloned.deinit();

    try std.testing.expect(cloned.node_type == Node.DOCUMENT_FRAGMENT_NODE);
}

test "Node.cloneNode - ShadowRoot deep clone also throws" {
    const allocator = std.testing.allocator;

    var host = try Element.create(allocator, "div", null, null);
    defer host.deinit();

    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.open,
        false,
        SlotAssignmentMode.named,
        false,
        false,
        false,
        false,
    );
    defer shadow.deinit();

    const shadow_node = shadow.asNode();

    // Deep clone of ShadowRoot should also throw NotSupportedError
    const result = shadow_node.call_cloneNode(true);
    try std.testing.expectError(error.NotSupportedError, result);
}
