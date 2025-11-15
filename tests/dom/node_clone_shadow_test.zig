const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

// Type aliases
const Element = dom.Element;
const Node = dom.Node;
const ShadowRoot = dom.ShadowRoot;
const ShadowRootMode = dom.ShadowRootMode;
const SlotAssignmentMode = dom.SlotAssignmentMode;

test "Node.cloneNode - element with clonable shadow root is cloned" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    // Attach clonable shadow root
    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.open,
        false, // delegates_focus
        SlotAssignmentMode.named,
        true, // clonable = true
        false, // serializable
    );
    host.shadow_root = &shadow;

    const host_node = &host;

    // Clone the host element
    const cloned_node = try host_node.call_cloneNode(false);
    defer {
        // Clean up cloned shadow root if it exists
        const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));
        if (cloned_elem.shadow_root) |cloned_shadow| {
            cloned_shadow.deinit();
        }
        cloned_node.deinit();
    }

    const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));

    // Verify shadow root was cloned
    try std.testing.expect(cloned_elem.shadow_root != null);

    const cloned_shadow = cloned_elem.shadow_root.?;

    // Verify shadow root properties
    try std.testing.expect(cloned_shadow.shadow_mode == ShadowRootMode.open);
    try std.testing.expect(cloned_shadow.clonable_flag == true);
    try std.testing.expect(cloned_shadow.delegates_focus_flag == false);

    // Shadow roots should be different objects
    try std.testing.expect(cloned_shadow != &shadow);
}

test "Node.cloneNode - element with non-clonable shadow root is not cloned" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    // Attach non-clonable shadow root
    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.closed,
        false,
        SlotAssignmentMode.named,
        false, // clonable = false
        false,
        false,
        false,
    );
    host.shadow_root = &shadow;

    const host_node = &host;

    // Clone the host element
    const cloned_node = try host_node.call_cloneNode(false);
    defer cloned_node.deinit();

    const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));

    // Shadow root should NOT be cloned
    try std.testing.expect(cloned_elem.shadow_root == null);
}

test "Node.cloneNode - shadow root declarative flag is preserved" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    // Attach clonable declarative shadow root
    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.open,
        false,
        SlotAssignmentMode.named,
        true, // clonable
        false,
        false,
        true, // declarative = true
    );
    host.shadow_root = &shadow;

    const host_node = &host;

    // Clone the host element
    const cloned_node = try host_node.call_cloneNode(false);
    defer {
        const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));
        if (cloned_elem.shadow_root) |cloned_shadow| {
            cloned_shadow.deinit();
        }
        cloned_node.deinit();
    }

    const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));
    const cloned_shadow = cloned_elem.shadow_root.?;

    // Declarative flag should be preserved
    try std.testing.expect(cloned_shadow.declarative_flag == true);
}

test "Node.cloneNode - shadow root children are cloned with subtree=true" {
    const allocator = std.testing.allocator;

    var host = try Element.init(allocator, "div");
    defer host.deinit();

    // Attach clonable shadow root
    var shadow = try ShadowRoot.init(
        allocator,
        &host,
        ShadowRootMode.open,
        false,
        SlotAssignmentMode.named,
        true, // clonable
        false,
        false,
        false,
    );
    host.shadow_root = &shadow;

    // Add a child to the shadow root
    var shadow_child = try Element.init(allocator, "span");
    defer shadow_child.deinit();

    const shadow_node = &shadow;
    const shadow_child_node = &shadow_child;
    _ = try shadow_node.call_appendChild(shadow_child_node);

    const host_node = &host;

    // Clone the host element with subtree=true
    const cloned_node = try host_node.call_cloneNode(true);
    defer {
        const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));
        if (cloned_elem.shadow_root) |cloned_shadow| {
            // Clean up shadow root children
            const cloned_shadow_node = &cloned_shadow;
            for (cloned_shadow_node.child_nodes.items) |child| {
                child.deinit();
            }
            cloned_shadow.deinit();
        }
        cloned_node.deinit();
    }

    const cloned_elem: *Element = @ptrCast(@alignCast(cloned_node));
    const cloned_shadow = cloned_elem.shadow_root.?;
    const cloned_shadow_node = &cloned_shadow;

    // Shadow root should have cloned children
    try std.testing.expectEqual(@as(usize, 1), cloned_shadow_node.child_nodes.len);

    const cloned_child = cloned_shadow_node.child_nodes.items[0];
    try std.testing.expect(cloned_child.node_type == Node.ELEMENT_NODE);

    // Children should be different objects
    try std.testing.expect(cloned_child != shadow_child_node);
}
