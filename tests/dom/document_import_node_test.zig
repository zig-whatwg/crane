//! Tests for Document.importNode
//! Spec: https://dom.spec.whatwg.org/#dom-document-importnode

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");

const Document = dom.Document;
const Element = dom.Element;
const Text = dom.Text;
const Comment = dom.Comment;
const Node = dom.Node;

test "importNode: shallow copy of element" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create element in source document
    const source_elem = try source_doc.call_createElement("div");
    defer {
        source_elem.deinit();
        allocator.destroy(source_elem);
    }

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Import the element (shallow)
    const imported_node = try target_doc.call_importNode(@ptrCast(source_elem), false);
    defer {
        const imported_elem: *Element = @ptrCast(imported_node);
        imported_elem.deinit();
        allocator.destroy(imported_elem);
    }

    // Verify it's an element with correct tag name
    try std.testing.expectEqual(Node.ELEMENT_NODE, imported_node.node_type);
    const imported_elem: *Element = @ptrCast(imported_node);
    try std.testing.expectEqualStrings("div", imported_elem.tag_name);

    // Verify it has no children (shallow copy)
    try std.testing.expectEqual(@as(usize, 0), imported_node.child_nodes.size());
}

test "importNode: deep copy of element with children" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create element tree: div > p > text
    const source_div = try source_doc.call_createElement("div");
    defer {
        source_div.deinit();
        allocator.destroy(source_div);
    }

    const source_p = try source_doc.call_createElement("p");
    const source_text = try source_doc.call_createTextNode("Hello");

    // Build tree
    try source_p.child_nodes.append(@ptrCast(source_text));
    source_text.parent_node = @ptrCast(source_p);

    try source_div.child_nodes.append(@ptrCast(source_p));
    source_p.parent_node = @ptrCast(source_div);

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Import the element (deep)
    const imported_node = try target_doc.call_importNode(@ptrCast(source_div), true);
    defer {
        const imported_div: *Element = @ptrCast(imported_node);
        // Clean up entire tree
        for (0..imported_div.child_nodes.size()) |i| {
            if (imported_div.child_nodes.get(i)) |child| {
                const child_elem: *Element = @ptrCast(child);
                for (0..child_elem.child_nodes.size()) |j| {
                    if (child_elem.child_nodes.get(j)) |grandchild| {
                        const text_node: *Text = @ptrCast(grandchild);
                        text_node.deinit();
                        allocator.destroy(text_node);
                    }
                }
                child_elem.deinit();
                allocator.destroy(child_elem);
            }
        }
        imported_div.deinit();
        allocator.destroy(imported_div);
    }

    // Verify structure
    try std.testing.expectEqual(@as(usize, 1), imported_node.child_nodes.size());

    const imported_p = imported_node.child_nodes.get(0).?;
    try std.testing.expectEqual(Node.ELEMENT_NODE, imported_p.node_type);
    try std.testing.expectEqual(@as(usize, 1), imported_p.child_nodes.size());

    const imported_text = imported_p.child_nodes.get(0).?;
    try std.testing.expectEqual(Node.TEXT_NODE, imported_text.node_type);
    const text_node: *Text = @ptrCast(imported_text);
    try std.testing.expectEqualStrings("Hello", text_node.data);
}

test "importNode: text node" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create text node
    const source_text = try source_doc.call_createTextNode("Test text");
    defer {
        source_text.deinit();
        allocator.destroy(source_text);
    }

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Import the text node
    const imported_node = try target_doc.call_importNode(@ptrCast(source_text), false);
    defer {
        const imported_text: *Text = @ptrCast(imported_node);
        imported_text.deinit();
        allocator.destroy(imported_text);
    }

    // Verify
    try std.testing.expectEqual(Node.TEXT_NODE, imported_node.node_type);
    const imported_text: *Text = @ptrCast(imported_node);
    try std.testing.expectEqualStrings("Test text", imported_text.data);
}

test "importNode: comment node" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create comment node
    const source_comment = try source_doc.call_createComment("Test comment");
    defer {
        source_comment.deinit();
        allocator.destroy(source_comment);
    }

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Import the comment node
    const imported_node = try target_doc.call_importNode(@ptrCast(source_comment), false);
    defer {
        const imported_comment: *Comment = @ptrCast(imported_node);
        imported_comment.deinit();
        allocator.destroy(imported_comment);
    }

    // Verify
    try std.testing.expectEqual(Node.COMMENT_NODE, imported_node.node_type);
    const imported_comment: *Comment = @ptrCast(imported_node);
    try std.testing.expectEqualStrings("Test comment", imported_comment.data);
}

test "importNode: element with attributes" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create element with attributes
    const source_elem = try source_doc.call_createElement("div");
    defer {
        source_elem.deinit();
        allocator.destroy(source_elem);
    }
    try source_elem.call_setAttribute("id", "test");
    try source_elem.call_setAttribute("class", "container");

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Import the element
    const imported_node = try target_doc.call_importNode(@ptrCast(source_elem), false);
    defer {
        const imported_elem: *Element = @ptrCast(imported_node);
        imported_elem.deinit();
        allocator.destroy(imported_elem);
    }

    // Verify attributes were cloned
    const imported_elem: *Element = @ptrCast(imported_node);
    try std.testing.expectEqual(@as(usize, 2), imported_elem.attributes.items.len);

    const id = imported_elem.getAttribute("id");
    try std.testing.expect(id != null);
    try std.testing.expectEqualStrings("test", id.?);

    const class = imported_elem.getAttribute("class");
    try std.testing.expect(class != null);
    try std.testing.expectEqualStrings("container", class.?);
}

test "importNode: document node throws NotSupportedError" {
    const allocator = std.testing.allocator;

    // Create source document
    var source_doc = try Document.init(allocator);
    defer source_doc.deinit();

    // Create target document
    var target_doc = try Document.init(allocator);
    defer target_doc.deinit();

    // Try to import document - should throw
    const result = target_doc.call_importNode(@ptrCast(&source_doc), false);
    try std.testing.expectError(error.NotSupportedError, result);
}
