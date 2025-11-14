const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Range = dom.Range;
const Text = dom.Text;

test "Range.insertNode - splits Text node at start offset" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("HelloWorld");
    _ = try div.call_appendChild(@ptrCast(text));
    _ = try doc.call_appendChild((&div));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Set range to middle of text (offset 5)
    try range.call_setStart((&text), 5);
    try range.call_collapse(true);

    // Insert element
    const span = try doc.call_createElement("span");
    try range.call_insertNode((&span));

    // Text should be split: "Hello" + span + "World"
    try std.testing.expectEqual(@as(usize, 3), div.child_nodes.size());

    const first = div.child_nodes.item(0).?;
    const firstText = try dom.Text.fromNode(first);
    try std.testing.expectEqualStrings("Hello", firstText.get_data());

    const second = div.child_nodes.item(1).?;
    try std.testing.expectEqual((&span), second);

    const third = div.child_nodes.item(2).?;
    const thirdText = try dom.Text.fromNode(third);
    try std.testing.expectEqualStrings("World", thirdText.get_data());
}

test "Range.insertNode - splits at start of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    try range.call_setStart((&text), 0);
    try range.call_collapse(true);

    const span = try doc.call_createElement("span");
    try range.call_insertNode((&span));

    // Should be: span + "Hello"
    try std.testing.expectEqual(@as(usize, 2), div.child_nodes.size());

    const first = div.child_nodes.item(0).?;
    try std.testing.expectEqual((&span), first);

    const second = div.child_nodes.item(1).?;
    const secondText = try dom.Text.fromNode(second);
    try std.testing.expectEqualStrings("Hello", secondText.get_data());
}

test "Range.insertNode - splits at end of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello");
    _ = try div.call_appendChild(@ptrCast(text));

    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    try range.call_setStart((&text), 5);
    try range.call_collapse(true);

    const span = try doc.call_createElement("span");
    try range.call_insertNode((&span));

    // Should be: "Hello" + span
    try std.testing.expectEqual(@as(usize, 2), div.child_nodes.size());

    const first = div.child_nodes.item(0).?;
    const firstText = try dom.Text.fromNode(first);
    try std.testing.expectEqualStrings("Hello", firstText.get_data());

    const second = div.child_nodes.item(1).?;
    try std.testing.expectEqual((&span), second);
}
