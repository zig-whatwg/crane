//! Comprehensive tests for NodeBase pattern with XPath integration
//!
//! Tests the NodeBase polymorphism pattern by building real DOM trees
//! and running XPath queries against them.

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;
const Element = dom.Element;
const Node = dom.Node;
const Text = dom.Text;

const testing = std.testing;

// Use the WithBase types
const NodeBase = dom.NodeBase;
const ElementWithBase = dom.ElementWithBase;
const TextWithBase = dom.TextWithBase;
const AttrWithBase = dom.AttrWithBase;

test "NodeBase - create element with attributes" {
    const allocator = testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    // Set attributes
    try element.setAttribute("id", "myDiv");
    try element.setAttribute("class", "container");

    // Verify attributes
    try testing.expectEqualStrings("myDiv", element.getAttribute("id").?);
    try testing.expectEqualStrings("container", element.getAttribute("class").?);

    // Verify attribute count
    try testing.expectEqual(@as(usize, 2), element.attributes.size());
}

test "NodeBase - element with text children" {
    const allocator = testing.allocator;

    var parent = ElementWithBase.init(allocator, "div");
    defer parent.deinit();

    var text1 = try TextWithBase.init(allocator, "Hello ");
    defer text1.deinit();

    var text2 = try TextWithBase.init(allocator, "World");
    defer text2.deinit();

    // Build tree
    const parent_node = parent.asNode();
    const text1_node = text1.asNode();
    const text2_node = text2.asNode();

    try parent_node.child_nodes.append(text1_node);
    try parent_node.child_nodes.append(text2_node);

    text1_node.parent_node = parent_node;
    text2_node.parent_node = parent_node;

    // Verify tree structure
    try testing.expectEqual(@as(usize, 2), parent_node.child_nodes.size());
    try testing.expectEqual(NodeBase.ELEMENT_NODE, parent_node.node_type);
    try testing.expectEqual(NodeBase.TEXT_NODE, text1_node.node_type);
    try testing.expectEqual(NodeBase.TEXT_NODE, text2_node.node_type);
}

test "NodeBase - attribute axis returns attribute nodes" {
    const allocator = testing.allocator;

    var element = ElementWithBase.init(allocator, "div");
    defer element.deinit();

    // Add attributes
    try element.setAttribute("id", "test");
    try element.setAttribute("class", "foo");

    // Get element as NodeBase
    const node = element.asNode();

    // Cast back to Element and check attributes
    if (NodeBase.asElement(node)) |elem| {
        try testing.expectEqual(@as(usize, 2), elem.attributes.size());

        // Verify first attribute
        const attr1 = elem.attributes.get(0).?;
        try testing.expectEqualStrings("id", attr1.local_name);
        try testing.expectEqualStrings("test", attr1.value);

        // Verify attribute has NodeBase
        const attr_node = attr1.asNode();
        try testing.expectEqual(NodeBase.ATTRIBUTE_NODE, attr_node.node_type);
    } else {
        try testing.expect(false); // Should not fail
    }
}

test "NodeBase - text extraction from element" {
    const allocator = testing.allocator;

    var parent = ElementWithBase.init(allocator, "p");
    defer parent.deinit();

    var text = try TextWithBase.init(allocator, "Hello World");
    defer text.deinit();

    // Build tree
    const parent_node = parent.asNode();
    const text_node = text.asNode();

    try parent_node.child_nodes.append(text_node);
    text_node.parent_node = parent_node;

    // Extract text using CharacterData casting
    const first_child = parent_node.child_nodes.get(0).?;
    if (NodeBase.asCharacterDataConst(first_child)) |char_data| {
        try testing.expectEqualStrings("Hello World", char_data.data);
    } else {
        try testing.expect(false); // Should not fail
    }
}

test "NodeBase - complex tree with mixed node types" {
    const allocator = testing.allocator;

    // Create: <div id="root"><span>Hello</span><p>World</p></div>
    var root = ElementWithBase.init(allocator, "div");
    defer root.deinit();
    try root.setAttribute("id", "root");

    var span = ElementWithBase.init(allocator, "span");
    defer span.deinit();

    var span_text = try TextWithBase.init(allocator, "Hello");
    defer span_text.deinit();

    var p = ElementWithBase.init(allocator, "p");
    defer p.deinit();

    var p_text = try TextWithBase.init(allocator, "World");
    defer p_text.deinit();

    // Build tree
    const root_node = root.asNode();
    const span_node = span.asNode();
    const span_text_node = span_text.asNode();
    const p_node = p.asNode();
    const p_text_node = p_text.asNode();

    // root <- span <- span_text
    try root_node.child_nodes.append(span_node);
    span_node.parent_node = root_node;

    try span_node.child_nodes.append(span_text_node);
    span_text_node.parent_node = span_node;

    // root <- p <- p_text
    try root_node.child_nodes.append(p_node);
    p_node.parent_node = root_node;

    try p_node.child_nodes.append(p_text_node);
    p_text_node.parent_node = p_node;

    // Verify structure
    try testing.expectEqual(@as(usize, 2), root_node.child_nodes.size());
    try testing.expectEqual(@as(usize, 1), span_node.child_nodes.size());
    try testing.expectEqual(@as(usize, 1), p_node.child_nodes.size());

    // Verify we can navigate and downcast
    const first_child = root_node.child_nodes.get(0).?;
    if (NodeBase.asElement(first_child)) |elem| {
        try testing.expectEqualStrings("span", elem.tag_name);
    } else {
        try testing.expect(false);
    }
}

test "NodeBase - attribute value extraction" {
    const allocator = testing.allocator;

    var element = ElementWithBase.init(allocator, "input");
    defer element.deinit();

    try element.setAttribute("type", "text");
    try element.setAttribute("placeholder", "Enter name");

    // Access attributes as nodes
    const attr1 = element.attributes.get(0).?;
    const attr2 = element.attributes.get(1).?;

    // Verify attribute values
    try testing.expectEqualStrings("text", attr1.getValue());
    try testing.expectEqualStrings("Enter name", attr2.getValue());

    // Verify they are attribute nodes
    try testing.expectEqual(NodeBase.ATTRIBUTE_NODE, attr1.asNode().node_type);
    try testing.expectEqual(NodeBase.ATTRIBUTE_NODE, attr2.asNode().node_type);
}

test "NodeBase - getRoot works across type hierarchy" {
    const allocator = testing.allocator;

    var root = ElementWithBase.init(allocator, "html");
    defer root.deinit();

    var body = ElementWithBase.init(allocator, "body");
    defer body.deinit();

    var div = ElementWithBase.init(allocator, "div");
    defer div.deinit();

    var text = try TextWithBase.init(allocator, "Deep text");
    defer text.deinit();

    // Build tree: root <- body <- div <- text
    const root_node = root.asNode();
    const body_node = body.asNode();
    const div_node = div.asNode();
    const text_node = text.asNode();

    try root_node.child_nodes.append(body_node);
    body_node.parent_node = root_node;

    try body_node.child_nodes.append(div_node);
    div_node.parent_node = body_node;

    try div_node.child_nodes.append(text_node);
    text_node.parent_node = div_node;

    // getRoot from any node should return root
    try testing.expectEqual(root_node, text_node.getRoot());
    try testing.expectEqual(root_node, div_node.getRoot());
    try testing.expectEqual(root_node, body_node.getRoot());
    try testing.expectEqual(root_node, root_node.getRoot());
}

test "NodeBase - contains works across type hierarchy" {
    const allocator = testing.allocator;

    var parent = ElementWithBase.init(allocator, "div");
    defer parent.deinit();

    var child = TextWithBase.init(allocator, "text") catch unreachable;
    defer child.deinit();

    const parent_node = parent.asNode();
    const child_node = child.asNode();

    try parent_node.child_nodes.append(child_node);
    child_node.parent_node = parent_node;

    // Parent contains child (across Element->Text boundary)
    try testing.expect(parent_node.contains(child_node));

    // Child doesn't contain parent
    try testing.expect(!child_node.contains(parent_node));

    // Node contains itself
    try testing.expect(parent_node.contains(parent_node));
}
