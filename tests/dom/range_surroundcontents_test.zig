const std = @import("std");
const dom = @import("dom");

test "Range.surroundContents - wraps range content in new parent" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello World");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select "World" (offset 6 to 11)
    try range.call_setStart(&text.base.base, 6);
    try range.call_setEnd(&text.base.base, 11);

    // Wrap in span
    const span = try doc.call_createElement("span");
    try range.call_surroundContents(&span.base);

    // div should contain: "Hello " + span + "" (empty text from split)
    const firstText = try dom.Text.fromNode(div.base.child_nodes.item(0).?);
    try std.testing.expectEqualStrings("Hello ", firstText.base.get_data());

    const middleSpan = div.base.child_nodes.item(1).?;
    try std.testing.expectEqual(&span.base, middleSpan);

    // Span should contain "World"
    const spanText = try dom.Text.fromNode(span.base.child_nodes.item(0).?);
    try std.testing.expectEqualStrings("World", spanText.base.get_data());
}

test "Range.surroundContents - clears existing newParent children" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text = try doc.call_createTextNode("Hello");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    try range.call_setStart(&text.base.base, 0);
    try range.call_setEnd(&text.base.base, 5);

    // Create span with existing child
    const span = try doc.call_createElement("span");
    const oldChild = try doc.call_createTextNode("Old");
    _ = try span.call_appendChild(&oldChild.base.base);

    // Old child should be removed
    try range.call_surroundContents(&span.base);

    // Span should only contain "Hello", not "Old"
    try std.testing.expectEqual(@as(usize, 1), span.base.child_nodes.size());
    const spanText = try dom.Text.fromNode(span.base.child_nodes.item(0).?);
    try std.testing.expectEqualStrings("Hello", spanText.base.get_data());
}

test "Range.surroundContents - throws for Document parent" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    try range.call_setStart(&text.base.base, 0);
    try range.call_setEnd(&text.base.base, 5);

    // Try to use Document as newParent
    var newDoc = try dom.Document.init(allocator);
    defer newDoc.deinit();

    const result = range.call_surroundContents(&newDoc.base);
    try std.testing.expectError(error.InvalidNodeTypeError, result);
}

test "Range.surroundContents - throws for DocumentFragment parent" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(&text.base.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    try range.call_setStart(&text.base.base, 0);
    try range.call_setEnd(&text.base.base, 5);

    // Try to use DocumentFragment as newParent
    const fragment = try allocator.create(dom.DocumentFragment);
    defer allocator.destroy(fragment);
    fragment.* = try dom.DocumentFragment.init(allocator);
    defer fragment.deinit();

    const result = range.call_surroundContents(&fragment.base);
    try std.testing.expectError(error.InvalidNodeTypeError, result);
}
