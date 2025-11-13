//! Comprehensive Integration Tests for WebIDL Interface Inheritance
//!
//! Tests verify that the inheritance hierarchy works correctly:
//! - EventTarget -> Node -> Element -> HTMLElement
//! - Methods are inherited properly
//! - Fields are flattened correctly
//! - @ptrCast works for polymorphism
//! - Child overrides work correctly

const std = @import("std");
const testing = std.testing;

// Import generated types
const EventTarget = @import("webidl").generated.dom.EventTarget;
const Node = @import("webidl").generated.dom.Node;
const Element = @import("webidl").generated.dom.Element;

test "WebIDL Inheritance: EventTarget -> Node -> Element hierarchy" {
    const allocator = testing.allocator;

    // Test 1: Element has all EventTarget fields
    {
        var elem = try Element.init(allocator, "div");
        defer elem.deinit();

        // EventTarget field (flattened into Element)
        try testing.expect(elem.event_listener_list == null);
        try testing.expect(@TypeOf(elem.event_listener_list) == @TypeOf(EventTarget.init(allocator).event_listener_list));
    }

    // Test 2: Element has all Node fields
    {
        var elem = try Element.init(allocator, "div");
        defer elem.deinit();

        // Node fields (flattened into Element)
        try testing.expectEqual(@as(u16, 1), elem.node_type); // ELEMENT_NODE
        try testing.expectEqualStrings("div", elem.node_name);
        try testing.expect(elem.parent_node == null);
    }

    // Test 3: Element has its own fields
    {
        var elem = try Element.init(allocator, "div");
        defer elem.deinit();

        // Element own fields
        try testing.expectEqualStrings("div", elem.tag_name);
    }
}

test "WebIDL Inheritance: Element inherits EventTarget methods" {
    const allocator = testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Test: Element should have addEventListener (from EventTarget)
    // This will compile if method exists and has correct signature
    const has_addEventListener = @hasDecl(Element, "call_addEventListener");
    try testing.expect(has_addEventListener);

    // Test: Element should have dispatchEvent (from EventTarget)
    const has_dispatchEvent = @hasDecl(Element, "call_dispatchEvent");
    try testing.expect(has_dispatchEvent);

    // Test: Element should have removeEventListener (from EventTarget)
    const has_removeEventListener = @hasDecl(Element, "call_removeEventListener");
    try testing.expect(has_removeEventListener);
}

test "WebIDL Inheritance: Element inherits Node methods" {
    const allocator = testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Test: Element should have appendChild (from Node)
    const has_appendChild = @hasDecl(Element, "call_appendChild");
    try testing.expect(has_appendChild);

    // Test: Element should have insertBefore (from Node)
    const has_insertBefore = @hasDecl(Element, "call_insertBefore");
    try testing.expect(has_insertBefore);

    // Test: Element should have removeChild (from Node)
    const has_removeChild = @hasDecl(Element, "call_removeChild");
    try testing.expect(has_removeChild);

    // Test: Element should have replaceChild (from Node)
    const has_replaceChild = @hasDecl(Element, "call_replaceChild");
    try testing.expect(has_replaceChild);
}

test "WebIDL Inheritance: Polymorphism with @ptrCast" {
    const allocator = testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Test 1: Cast Element to Node
    {
        const as_node: *Node = @ptrCast(&elem);

        // Should access Node fields correctly
        try testing.expectEqual(@as(u16, 1), as_node.node_type);
        try testing.expectEqualStrings("div", as_node.node_name);
    }

    // Test 2: Cast Element to EventTarget
    {
        const as_event_target: *EventTarget = @ptrCast(&elem);

        // Should access EventTarget fields correctly
        try testing.expect(as_event_target.event_listener_list == null);
    }

    // Test 3: Modify via Node pointer, verify Element sees changes
    {
        const as_node: *Node = @ptrCast(&elem);
        as_node.node_type = 99; // Modify via Node pointer

        // Element should see the change (same memory)
        try testing.expectEqual(@as(u16, 99), elem.node_type);
    }
}

test "WebIDL Inheritance: appendChild accepts any Node subtype" {
    const allocator = testing.allocator;

    var parent = try Element.init(allocator, "div");
    defer parent.deinit();

    var child = try Element.init(allocator, "span");
    defer child.deinit();

    // Test: appendChild expects *Node, but we pass *Element
    // This should work because Element has all Node fields at same offsets
    const child_as_node: *Node = @ptrCast(&child);
    _ = try parent.call_appendChild(child_as_node);

    // Verify the child was added
    try testing.expectEqual(@as(usize, 1), parent.child_nodes.size());
}

test "WebIDL Inheritance: Field offset alignment" {
    // This test verifies that flattened fields maintain compatible offsets
    // across the inheritance hierarchy

    // Test 1: Node fields in Element match Node field offsets
    {
        const node_allocator_offset = @offsetOf(Node, "allocator");
        const elem_allocator_offset = @offsetOf(Element, "allocator");
        try testing.expectEqual(node_allocator_offset, elem_allocator_offset);

        const node_type_offset = @offsetOf(Node, "node_type");
        const elem_type_offset = @offsetOf(Element, "node_type");
        try testing.expectEqual(node_type_offset, elem_type_offset);

        const node_name_offset = @offsetOf(Node, "node_name");
        const elem_name_offset = @offsetOf(Element, "node_name");
        try testing.expectEqual(node_name_offset, elem_name_offset);
    }

    // Test 2: EventTarget fields in Node match EventTarget field offsets
    {
        const et_allocator_offset = @offsetOf(EventTarget, "allocator");
        const node_allocator_offset = @offsetOf(Node, "allocator");
        try testing.expectEqual(et_allocator_offset, node_allocator_offset);

        const et_listener_offset = @offsetOf(EventTarget, "event_listener_list");
        const node_listener_offset = @offsetOf(Node, "event_listener_list");
        try testing.expectEqual(et_listener_offset, node_listener_offset);
    }

    // Test 3: EventTarget fields in Element match EventTarget field offsets (transitive)
    {
        const et_allocator_offset = @offsetOf(EventTarget, "allocator");
        const elem_allocator_offset = @offsetOf(Element, "allocator");
        try testing.expectEqual(et_allocator_offset, elem_allocator_offset);

        const et_listener_offset = @offsetOf(EventTarget, "event_listener_list");
        const elem_listener_offset = @offsetOf(Element, "event_listener_list");
        try testing.expectEqual(et_listener_offset, elem_listener_offset);
    }
}

test "WebIDL Inheritance: Method calls through cast pointers" {
    const allocator = testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Test 1: Call Node method through Element
    {
        var child = try Element.init(allocator, "span");
        defer child.deinit();

        const child_as_node: *Node = @ptrCast(&child);
        _ = try elem.call_appendChild(child_as_node);

        try testing.expectEqual(@as(usize, 1), elem.child_nodes.size());
    }

    // Test 2: Call inherited Node method on Element directly
    {
        var child2 = try Element.init(allocator, "p");
        defer child2.deinit();

        const child2_as_node: *Node = @ptrCast(&child2);
        _ = try elem.call_appendChild(child2_as_node);

        try testing.expectEqual(@as(usize, 2), elem.child_nodes.size());
    }
}

test "WebIDL Inheritance: Constants are accessible" {
    // Test: Element has access to Node constants
    try testing.expectEqual(@as(u16, 1), Element.ELEMENT_NODE);
    try testing.expectEqual(@as(u16, 3), Element.TEXT_NODE);
    try testing.expectEqual(@as(u16, 9), Element.DOCUMENT_NODE);

    // Test: Node has access to Node constants
    try testing.expectEqual(@as(u16, 1), Node.ELEMENT_NODE);
    try testing.expectEqual(@as(u16, 3), Node.TEXT_NODE);
}

test "WebIDL Inheritance: Deep hierarchy (3+ levels)" {
    const allocator = testing.allocator;

    // EventTarget -> Node -> Element (3 levels)
    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Test 1: Element can be cast to Node
    const as_node: *Node = @ptrCast(&elem);
    try testing.expectEqual(@as(u16, 1), as_node.node_type);

    // Test 2: Element can be cast to EventTarget (skip Node)
    const as_et: *EventTarget = @ptrCast(&elem);
    try testing.expect(as_et.event_listener_list == null);

    // Test 3: Verify all three levels see same allocator
    try testing.expect(&elem.allocator == &as_node.allocator);
    try testing.expect(&elem.allocator == &as_et.allocator);
}

test "WebIDL Inheritance: Mixin fields are flattened correctly" {
    const allocator = testing.allocator;

    var elem = try Element.init(allocator, "div");
    defer elem.deinit();

    // Element includes Slottable mixin
    // Test: Slottable fields should be in Element
    const has_slottable_name = @hasField(Element, "slottable_name");
    try testing.expect(has_slottable_name);

    const has_assigned_slot = @hasField(Element, "assigned_slot");
    try testing.expect(has_assigned_slot);
}

test "WebIDL Inheritance: Child override methods are used" {
    const allocator = testing.allocator;

    // Both Node and Element define init()
    // Element's init() should be the one used, not inherited from Node

    var elem = try Element.init(allocator, "custom-element");
    defer elem.deinit();

    // If Element's init() was used, tag_name should be set
    try testing.expectEqualStrings("custom-element", elem.tag_name);

    // If Element's init() was used, node_type should be ELEMENT_NODE (1)
    try testing.expectEqual(@as(u16, 1), elem.node_type);
}

test "WebIDL Inheritance: Memory layout size calculation" {
    // Test that Element size >= Node size >= EventTarget size
    // (Each child adds fields, so should be larger or equal)

    const et_size = @sizeOf(EventTarget);
    const node_size = @sizeOf(Node);
    const elem_size = @sizeOf(Element);

    try testing.expect(node_size >= et_size);
    try testing.expect(elem_size >= node_size);
}

test "WebIDL Inheritance: Type metadata is correct" {
    // Test: Each type has correct __webidl__ metadata

    try testing.expectEqualStrings("EventTarget", EventTarget.__webidl__.name);
    try testing.expectEqualStrings("Node", Node.__webidl__.name);
    try testing.expectEqualStrings("Element", Element.__webidl__.name);

    try testing.expectEqual(@TypeOf(EventTarget.__webidl__.kind), @TypeOf(Node.__webidl__.kind));
    try testing.expectEqual(@TypeOf(Node.__webidl__.kind), @TypeOf(Element.__webidl__.kind));
}
