const std = @import("std");
const dom = @import("dom");

test "Range.setStart - throws InvalidNodeTypeError for DocumentType" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create a DocumentType node
    var doctype = try dom.DocumentType.init(allocator, "html", "", "");
    defer doctype.deinit();

    // Attempt to set start on DocumentType should throw
    const result = range.call_setStart(&doctype.base, 0);
    try std.testing.expectError(error.InvalidNodeTypeError, result);
}

test "Range.setEnd - throws InvalidNodeTypeError for DocumentType" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create a DocumentType node
    var doctype = try dom.DocumentType.init(allocator, "html", "", "");
    defer doctype.deinit();

    // Attempt to set end on DocumentType should throw
    const result = range.call_setEnd(&doctype.base, 0);
    try std.testing.expectError(error.InvalidNodeTypeError, result);
}

test "Range.setStart - throws IndexSizeError when offset > node length" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create an element with 2 children
    const element = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("span");
    _ = try element.call_appendChild(&child1.base);
    _ = try element.call_appendChild(&child2.base);

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Attempt to set start with offset 3 (element has only 2 children)
    const result = range.call_setStart(&element.base, 3);
    try std.testing.expectError(error.IndexSizeError, result);
}

test "Range.setEnd - throws IndexSizeError when offset > node length" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create an element with 2 children
    const element = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("span");
    _ = try element.call_appendChild(&child1.base);
    _ = try element.call_appendChild(&child2.base);

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Attempt to set end with offset 3 (element has only 2 children)
    const result = range.call_setEnd(&element.base, 3);
    try std.testing.expectError(error.IndexSizeError, result);
}

test "Range.setStart - valid offset within node length" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create an element with 2 children
    const element = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("span");
    _ = try element.call_appendChild(&child1.base);
    _ = try element.call_appendChild(&child2.base);

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set start with valid offset
    try range.call_setStart(&element.base, 1);
    try std.testing.expectEqual(&element.base, range.start_container);
    try std.testing.expectEqual(@as(u32, 1), range.start_offset);
}

test "Range.setEnd - valid offset within node length" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create an element with 2 children
    const element = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("span");
    _ = try element.call_appendChild(&child1.base);
    _ = try element.call_appendChild(&child2.base);

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set end with valid offset
    try range.call_setEnd(&element.base, 1);
    try std.testing.expectEqual(&element.base, range.end_container);
    try std.testing.expectEqual(@as(u32, 1), range.end_offset);
}

test "Range.setStart - adjusts end when start is after end" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create elements
    const div = try doc.call_createElement("div");
    const span1 = try doc.call_createElement("span");
    const span2 = try doc.call_createElement("span");
    _ = try div.call_appendChild(&span1.base);
    _ = try div.call_appendChild(&span2.base);

    // Create a range from (div, 0) to (div, 1)
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();
    try range.call_setStart(&div.base, 0);
    try range.call_setEnd(&div.base, 1);

    // Set start to (div, 2) - after end
    try range.call_setStart(&div.base, 2);

    // End should be adjusted to match start
    try std.testing.expectEqual(&div.base, range.start_container);
    try std.testing.expectEqual(@as(u32, 2), range.start_offset);
    try std.testing.expectEqual(&div.base, range.end_container);
    try std.testing.expectEqual(@as(u32, 2), range.end_offset);
}

test "Range.setEnd - adjusts start when end is before start" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create elements
    const div = try doc.call_createElement("div");
    const span1 = try doc.call_createElement("span");
    const span2 = try doc.call_createElement("span");
    _ = try div.call_appendChild(&span1.base);
    _ = try div.call_appendChild(&span2.base);

    // Create a range from (div, 1) to (div, 2)
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();
    try range.call_setStart(&div.base, 1);
    try range.call_setEnd(&div.base, 2);

    // Set end to (div, 0) - before start
    try range.call_setEnd(&div.base, 0);

    // Start should be adjusted to match end
    try std.testing.expectEqual(&div.base, range.start_container);
    try std.testing.expectEqual(@as(u32, 0), range.start_offset);
    try std.testing.expectEqual(&div.base, range.end_container);
    try std.testing.expectEqual(@as(u32, 0), range.end_offset);
}

test "Range.setStart - CharacterData node uses data length" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a text node with "Hello" (length 5)
    const text = try doc.call_createTextNode("Hello");

    // Create a range
    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Valid: offset 5 (equal to length)
    try range.call_setStart(&text.base.base, 5);
    try std.testing.expectEqual(@as(u32, 5), range.start_offset);

    // Invalid: offset 6 (greater than length)
    const result = range.call_setStart(&text.base.base, 6);
    try std.testing.expectError(error.IndexSizeError, result);
}
