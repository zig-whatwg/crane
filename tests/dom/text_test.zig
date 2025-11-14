//! Text Tests (DOM Standard §4.12)
//! Tests for Text interface and text-specific methods

const std = @import("std");
const dom = @import("dom");
const Document = dom.Document;
const Node = dom.Node;
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;

const testing = std.testing;

test "Text: createTextNode creates text with data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqualStrings("Hello World", text.get_data());
    try testing.expectEqual(@as(u32, 11), text.get_length());
}

test "Text: createTextNode with empty string" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqualStrings("", text.get_data());
    try testing.expectEqual(@as(u32, 0), text.get_length());
}

test "Text: inherits CharacterData methods" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Can use CharacterData methods
    try text.call_appendData(" World");
    try testing.expectEqualStrings("Hello World", text.get_data());

    const substr = try text.call_substringData(0, 5);
    try testing.expectEqualStrings("Hello", substr);

    try text.call_replaceData(6, 5, "Zig");
    try testing.expectEqualStrings("Hello Zig", text.get_data());
}

test "Text: splitText at middle" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("HelloWorld");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Split at offset 5
    var new_text = try text.call_splitText(5);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    // Original text should have first part
    try testing.expectEqualStrings("Hello", text.get_data());
    try testing.expectEqual(@as(u32, 5), text.get_length());

    // New text should have second part
    try testing.expectEqualStrings("World", new_text.get_data());
    try testing.expectEqual(@as(u32, 5), new_text.get_length());
}

test "Text: splitText at beginning" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    var new_text = try text.call_splitText(0);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    // Original is empty
    try testing.expectEqualStrings("", text.get_data());

    // New text has all data
    try testing.expectEqualStrings("Hello", new_text.get_data());
}

test "Text: splitText at end" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    var new_text = try text.call_splitText(5);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    // Original has all data
    try testing.expectEqualStrings("Hello", text.get_data());

    // New text is empty
    try testing.expectEqualStrings("", new_text.get_data());
}

test "Text: splitText throws on invalid offset" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Offset > length should throw
    const result = text.call_splitText(10);
    try testing.expectError(error.IndexSizeError, result);
}

test "Text: splitText with unicode" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello→World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // The arrow (→) is 3 bytes in UTF-8
    // Split after "Hello→" (8 bytes)
    var new_text = try text.call_splitText(8);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    try testing.expectEqualStrings("Hello→", text.get_data());
    try testing.expectEqualStrings("World", new_text.get_data());
}

test "Text: wholeText returns data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Without sibling text nodes, wholeText = data
    const whole = try text.get_wholeText();
    try testing.expectEqualStrings("Hello World", whole);
}

test "Text: wholeText after modification" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_appendData(" World");

    const whole = try text.get_wholeText();
    try testing.expectEqualStrings("Hello World", whole);
}

test "Text: multiple operations" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("abc");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Append
    try text.call_appendData("def");
    try testing.expectEqualStrings("abcdef", text.get_data());

    // Split
    var text2 = try text.call_splitText(3);
    defer {
        text2.deinit();
        allocator.destroy(text2);
    }

    try testing.expectEqualStrings("abc", text.get_data());
    try testing.expectEqualStrings("def", text2.get_data());

    // Modify both
    try text.call_insertData(0, "123");
    try text2.call_appendData("789");

    try testing.expectEqualStrings("123abc", text.get_data());
    try testing.expectEqualStrings("def789", text2.get_data());
}

test "Text: data manipulation after split" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("0123456789");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Split into three parts
    var text2 = try text.call_splitText(5);
    defer {
        text2.deinit();
        allocator.destroy(text2);
    }

    var text3 = try text2.call_splitText(3);
    defer {
        text3.deinit();
        allocator.destroy(text3);
    }

    try testing.expectEqualStrings("01234", text.get_data());
    try testing.expectEqualStrings("567", text2.get_data());
    try testing.expectEqualStrings("89", text3.get_data());

    // Modify middle part
    try text2.call_replaceData(0, 3, "xyz");
    try testing.expectEqualStrings("xyz", text2.get_data());

    // Other parts unchanged
    try testing.expectEqualStrings("01234", text.get_data());
    try testing.expectEqualStrings("89", text3.get_data());
}

test "Text: empty text node operations" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqual(@as(u32, 0), text.get_length());

    // Can append to empty
    try text.call_appendData("Hello");
    try testing.expectEqualStrings("Hello", text.get_data());

    // Can split empty (at offset 0)
    try text.call_deleteData(0, 5);
    var new_text = try text.call_splitText(0);
    defer {
        new_text.deinit();
        allocator.destroy(new_text);
    }

    try testing.expectEqualStrings("", text.get_data());
    try testing.expectEqualStrings("", new_text.get_data());
}

test "Text: splitText inserts new node into parent tree" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create parent element
    const parent = try doc.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    // Create and append text node
    const text = try doc.call_createTextNode("HelloWorld");
    const text_node: *Node = @ptrCast(text);
    const parent_node: *Node = @ptrCast(parent);
    _ = try parent_node.call_appendChild(text_node);

    // Verify tree structure before split
    try testing.expectEqual(@as(usize, 1), parent_node.child_nodes.len);
    try testing.expectEqual(text_node, parent_node.get_firstChild().?);

    // Split the text node
    const new_text = try text.call_splitText(5);
    const new_text_node: *Node = @ptrCast(new_text);

    // Verify both text nodes have correct data
    try testing.expectEqualStrings("Hello", text.get_data());
    try testing.expectEqualStrings("World", new_text.get_data());

    // Verify tree structure after split:
    // Parent should now have 2 children: original text and new text
    try testing.expectEqual(@as(usize, 2), parent_node.child_nodes.len);
    try testing.expectEqual(text_node, parent_node.child_nodes.get(0));
    try testing.expectEqual(new_text_node, parent_node.child_nodes.get(1));

    // Verify parent relationships
    try testing.expectEqual(parent_node, text_node.parent_node.?);
    try testing.expectEqual(parent_node, new_text_node.parent_node.?);

    // Verify sibling relationships
    try testing.expectEqual(new_text_node, text_node.get_nextSibling().?);
    try testing.expectEqual(text_node, new_text_node.get_previousSibling().?);
}

test "Text: splitText with siblings inserts in correct position" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // Create parent element
    const parent = try doc.call_createElement("div");
    defer {
        parent.deinit();
        allocator.destroy(parent);
    }

    // Create and append multiple nodes
    const text1 = try doc.call_createTextNode("First");
    const text2 = try doc.call_createTextNode("SecondThird");
    const text3 = try doc.call_createTextNode("Fourth");

    const parent_node: *Node = @ptrCast(parent);
    const text1_node: *Node = @ptrCast(text1);
    const text2_node: *Node = @ptrCast(text2);
    const text3_node: *Node = @ptrCast(text3);

    _ = try parent_node.call_appendChild(text1_node);
    _ = try parent_node.call_appendChild(text2_node);
    _ = try parent_node.call_appendChild(text3_node);

    // Verify initial state: 3 children
    try testing.expectEqual(@as(usize, 3), parent_node.child_nodes.len);

    // Split the middle text node
    const new_text = try text2.call_splitText(6);
    const new_text_node: *Node = @ptrCast(new_text);

    // Verify data
    try testing.expectEqualStrings("Second", text2.get_data());
    try testing.expectEqualStrings("Third", new_text.get_data());

    // Verify tree structure: should now have 4 children
    // Order: text1, text2, new_text, text3
    try testing.expectEqual(@as(usize, 4), parent_node.child_nodes.len);
    try testing.expectEqual(text1_node, parent_node.child_nodes.get(0));
    try testing.expectEqual(text2_node, parent_node.child_nodes.get(1));
    try testing.expectEqual(new_text_node, parent_node.child_nodes.get(2));
    try testing.expectEqual(text3_node, parent_node.child_nodes.get(3));

    // Verify sibling relationships
    try testing.expectEqual(text2_node, text1_node.get_nextSibling().?);
    try testing.expectEqual(new_text_node, text2_node.get_nextSibling().?);
    try testing.expectEqual(text3_node, new_text_node.get_nextSibling().?);
}
