const std = @import("std");
const dom = @import("dom");

test "Range.insertNode - splits Text node at start offset" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("HelloWorld");
    _ = try div.call_appendChild(&text.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set range to middle of text (offset 5)
    try range.call_setStart(&text.base.base, 5);
    try range.call_collapse(true);

    // Insert element
    const span = try doc.call_createElement("span");
    try range.call_insertNode(&span.base);

    // Text should be split: "Hello" + span + "World"
    try std.testing.expectEqual(@as(usize, 3), div.base.child_nodes.size());

    const first = div.base.child_nodes.item(0).?;
    const firstText = try dom.Text.fromNode(first);
    try std.testing.expectEqualStrings("Hello", firstText.base.get_data());

    const second = div.base.child_nodes.item(1).?;
    try std.testing.expectEqual(&span.base, second);

    const third = div.base.child_nodes.item(2).?;
    const thirdText = try dom.Text.fromNode(third);
    try std.testing.expectEqualStrings("World", thirdText.base.get_data());
}

test "Range.insertNode - splits at start of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    try range.call_setStart(&text.base.base, 0);
    try range.call_collapse(true);

    const span = try doc.call_createElement("span");
    try range.call_insertNode(&span.base);

    // Should be: span + "Hello"
    try std.testing.expectEqual(@as(usize, 2), div.base.child_nodes.size());

    const first = div.base.child_nodes.item(0).?;
    try std.testing.expectEqual(&span.base, first);

    const second = div.base.child_nodes.item(1).?;
    const secondText = try dom.Text.fromNode(second);
    try std.testing.expectEqualStrings("Hello", secondText.base.get_data());
}

test "Range.insertNode - splits at end of Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    try range.call_setStart(&text.base.base, 5);
    try range.call_collapse(true);

    const span = try doc.call_createElement("span");
    try range.call_insertNode(&span.base);

    // Should be: "Hello" + span
    try std.testing.expectEqual(@as(usize, 2), div.base.child_nodes.size());

    const first = div.base.child_nodes.item(0).?;
    const firstText = try dom.Text.fromNode(first);
    try std.testing.expectEqualStrings("Hello", firstText.base.get_data());

    const second = div.base.child_nodes.item(1).?;
    try std.testing.expectEqual(&span.base, second);
}
