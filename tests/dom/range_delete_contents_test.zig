const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Comment = dom.Comment;
const Document = dom.Document;
const Range = dom.Range;
const Text = dom.Text;

test "Range.deleteContents - deletes text data within same Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a text node with "Hello World"
    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select "o Wor" (offset 4 to 9)
    try range.call_setStart((&text), 4);
    try range.call_setEnd((&text), 9);

    // Delete the range
    try range.call_deleteContents();

    // Text should now be "Hellld"
    const data = text.base.get_data();
    try std.testing.expectEqualStrings("Hellld", data);
}

test "Range.deleteContents - deletes from start of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select "Hello " (offset 0 to 6)
    try range.call_setStart((&text), 0);
    try range.call_setEnd((&text), 6);

    // Delete the range
    try range.call_deleteContents();

    // Text should now be "World"
    const data = text.base.get_data();
    try std.testing.expectEqualStrings("World", data);
}

test "Range.deleteContents - deletes to end of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select " World" (offset 5 to 11)
    try range.call_setStart((&text), 5);
    try range.call_setEnd((&text), 11);

    // Delete the range
    try range.call_deleteContents();

    // Text should now be "Hello"
    const data = text.base.get_data();
    try std.testing.expectEqualStrings("Hello", data);
}

test "Range.deleteContents - deletes entire Text node content" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select entire text (offset 0 to 5)
    try range.call_setStart((&text), 0);
    try range.call_setEnd((&text), 5);

    // Delete the range
    try range.call_deleteContents();

    // Text should now be empty
    const data = text.base.get_data();
    try std.testing.expectEqualStrings("", data);
}

test "Range.deleteContents - deletes contained element nodes" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div><span>A</span><span>B</span><span>C</span></div>
    const div = try doc.call_createElement("div");
    const span1 = try doc.call_createElement("span");
    const span2 = try doc.call_createElement("span");
    const span3 = try doc.call_createElement("span");
    const textA = try doc.call_createTextNode("A");
    const textB = try doc.call_createTextNode("B");
    const textC = try doc.call_createTextNode("C");

    _ = try span1.call_appendChild(@ptrCast(textA));
    _ = try span2.call_appendChild(@ptrCast(textB));
    _ = try span3.call_appendChild(@ptrCast(textC));
    _ = try div.call_appendChild((&span1));
    _ = try div.call_appendChild((&span2));
    _ = try div.call_appendChild((&span3));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select middle span (offset 1 to 2)
    try range.call_setStart((&div), 1);
    try range.call_setEnd((&div), 2);

    // Delete the range
    try range.call_deleteContents();

    // Div should now have only 2 children (span1 and span3)
    try std.testing.expectEqual(@as(usize, 2), div.base.child_nodes.size());

    // First child should be span1
    const firstChild = div.base.child_nodes.item(0).?;
    try std.testing.expectEqual((&span1), firstChild);

    // Second child should be span3
    const secondChild = div.base.child_nodes.item(1).?;
    try std.testing.expectEqual((&span3), secondChild);
}

test "Range.deleteContents - collapsed range does nothing" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Collapsed range at offset 2
    try range.call_setStart((&text), 2);
    try range.call_setEnd((&text), 2);

    // Delete the range (should do nothing)
    try range.call_deleteContents();

    // Text should remain unchanged
    const data = text.base.get_data();
    try std.testing.expectEqualStrings("Hello", data);
}

test "Range.deleteContents - Comment node data deletion" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a comment node with "This is a comment"
    const comment = try doc.call_createComment("This is a comment");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(comment));
    _ = try doc.base.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, (&doc));
    defer range.deinit();

    // Select "is a " (offset 5 to 10)
    try range.call_setStart((&comment), 5);
    try range.call_setEnd((&comment), 10);

    // Delete the range
    try range.call_deleteContents();

    // Comment should now be "This comment"
    const data = comment.base.get_data();
    try std.testing.expectEqualStrings("This comment", data);
}
