const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Comment = dom.Comment;
const Document = dom.Document;
const Node = dom.Node;
const Range = dom.Range;
const Text = dom.Text;

test "Range.extractContents - extracts substring from Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create text node "Hello World"
    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select "World" (offset 6 to 11)
    try range.call_setStart(@ptrCast(text), 6);
    try range.call_setEnd(@ptrCast(text), 11);

    // Extract contents
    const fragment = try range.call_extractContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain cloned text with "World"
    try std.testing.expectEqual(@as(usize, 1), fragment.child_nodes.size());
    const extractedNode = fragment.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, extractedNode.node_type);

    const extractedText = extractedNode.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("World", extractedText.get_data());

    // Original text should now be "Hello " (extracted part removed)
    try std.testing.expectEqualStrings("Hello ", text.get_data());
}

test "Range.extractContents - handles entire Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select entire text
    try range.call_setStart(@ptrCast(text), 0);
    try range.call_setEnd(@ptrCast(text), 5);

    const fragment = try range.call_extractContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain "Hello"
    const extractedNode = fragment.child_nodes.get(0).?;
    const extractedText = extractedNode.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Hello", extractedText.get_data());

    // Original text should be empty
    try std.testing.expectEqualStrings("", text.get_data());
}

test "Range.extractContents - handles Comment node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const comment = try doc.call_createComment("This is a comment");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(comment));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select "is a" (offset 5 to 10)
    try range.call_setStart(@ptrCast(comment), 5);
    try range.call_setEnd(@ptrCast(comment), 10);

    const fragment = try range.call_extractContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain comment with "is a"
    const extractedNode = fragment.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.COMMENT_NODE, extractedNode.node_type);

    const extractedComment = try dom.Comment.fromNode(extractedNode);
    try std.testing.expectEqualStrings("is a", extractedComment.get_data());

    // Original comment should be "This  comment"
    try std.testing.expectEqualStrings("This  comment", comment.get_data());
}

test "Range.cloneContents - clones substring from Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create text node "Hello World"
    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select "World" (offset 6 to 11)
    try range.call_setStart(@ptrCast(text), 6);
    try range.call_setEnd(@ptrCast(text), 11);

    // Clone contents
    const fragment = try range.call_cloneContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain cloned text with "World"
    try std.testing.expectEqual(@as(usize, 1), fragment.child_nodes.size());
    const clonedNode = fragment.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.TEXT_NODE, clonedNode.node_type);

    const clonedText = clonedNode.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("World", clonedText.get_data());

    // Original text should remain unchanged
    try std.testing.expectEqualStrings("Hello World", text.get_data());
}

test "Range.cloneContents - handles entire Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select entire text
    try range.call_setStart(@ptrCast(text), 0);
    try range.call_setEnd(@ptrCast(text), 5);

    const fragment = try range.call_cloneContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain "Hello"
    const clonedNode = fragment.child_nodes.get(0).?;
    const clonedText = clonedNode.as(dom.Text) orelse unreachable;
    try std.testing.expectEqualStrings("Hello", clonedText.get_data());

    // Original text should remain unchanged
    try std.testing.expectEqualStrings("Hello", text.get_data());
}

test "Range.cloneContents - handles Comment node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const comment = try doc.call_createComment("This is a comment");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(comment));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Select "is a" (offset 5 to 10)
    try range.call_setStart(@ptrCast(comment), 5);
    try range.call_setEnd(@ptrCast(comment), 10);

    const fragment = try range.call_cloneContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should contain comment with "is a"
    const clonedNode = fragment.child_nodes.get(0).?;
    try std.testing.expectEqual(dom.Node.COMMENT_NODE, clonedNode.node_type);

    const clonedComment = try dom.Comment.fromNode(clonedNode);
    try std.testing.expectEqualStrings("is a", clonedComment.get_data());

    // Original comment should remain unchanged
    try std.testing.expectEqualStrings("This is a comment", comment.get_data());
}

test "Range.extractContents vs cloneContents - different behavior" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create two identical text nodes
    const text1 = try doc.call_createTextNode("Hello World");
    const text2 = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text1));
    _ = try div.call_appendChild(@ptrCast(text2));

    // Extract from text1
    var range1 = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range1.deinit();
    try range1.call_setStart(@ptrCast(text1), 6);
    try range1.call_setEnd(@ptrCast(text1), 11);
    const fragment1 = try range1.call_extractContents();
    defer {
        fragment1.deinit();
        allocator.destroy(fragment1);
    }

    // Clone from text2
    var range2 = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range2.deinit();
    try range2.call_setStart(@ptrCast(text2), 6);
    try range2.call_setEnd(@ptrCast(text2), 11);
    const fragment2 = try range2.call_cloneContents();
    defer {
        fragment2.deinit();
        allocator.destroy(fragment2);
    }

    // Both fragments should contain "World"
    const extracted = try fragment1.child_nodes.get(0.as(dom.Text) orelse unreachable.?);
    const cloned = try fragment2.child_nodes.get(0.as(dom.Text) orelse unreachable.?);
    try std.testing.expectEqualStrings("World", extracted.get_data());
    try std.testing.expectEqualStrings("World", cloned.get_data());

    // text1 should be modified (extracted), text2 unchanged (cloned)
    try std.testing.expectEqualStrings("Hello ", text1.get_data());
    try std.testing.expectEqualStrings("Hello World", text2.get_data());
}

test "Range.extractContents - empty range returns empty fragment" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Collapsed range (same start and end)
    try range.call_setStart(@ptrCast(text), 2);
    try range.call_setEnd(@ptrCast(text), 2);

    const fragment = try range.call_extractContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should be empty
    try std.testing.expectEqual(@as(usize, 0), fragment.child_nodes.size());

    // Original text unchanged
    try std.testing.expectEqualStrings("Hello", text.get_data());
}

test "Range.cloneContents - empty range returns empty fragment" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Collapsed range
    try range.call_setStart(@ptrCast(text), 2);
    try range.call_setEnd(@ptrCast(text), 2);

    const fragment = try range.call_cloneContents();
    defer {
        fragment.deinit();
        allocator.destroy(fragment);
    }

    // Fragment should be empty
    try std.testing.expectEqual(@as(usize, 0), fragment.child_nodes.size());
}
