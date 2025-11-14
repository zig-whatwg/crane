const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;
const Document = dom.Document;
const DocumentType = dom.DocumentType;
const Node = dom.Node;
const Range = dom.Range;

test "Range.setStart - throws InvalidNodeTypeError for DocumentType" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Create a DocumentType node
    var doctype = try dom.DocumentType.init(allocator, "html", "", "");
    defer doctype.deinit();

    // Attempt to set start on DocumentType should throw
    const result = range.call_setStart(@ptrCast(&doctype), 0);
    try std.testing.expectError(error.InvalidNodeTypeError, result);
}

test "Range.setEnd - throws InvalidNodeTypeError for DocumentType" {
    const allocator = std.testing.allocator;

    // Create a document
    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Create a DocumentType node
    var doctype = try dom.DocumentType.init(allocator, "html", "", "");
    defer doctype.deinit();

    // Attempt to set end on DocumentType should throw
    const result = range.call_setEnd(@ptrCast(&doctype), 0);
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
    _ = try element.call_appendChild((&child1));
    _ = try element.call_appendChild((&child2));

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Attempt to set start with offset 3 (element has only 2 children)
    const result = range.call_setStart(@ptrCast(&element), 3);
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
    _ = try element.call_appendChild((&child1));
    _ = try element.call_appendChild((&child2));

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Attempt to set end with offset 3 (element has only 2 children)
    const result = range.call_setEnd(@ptrCast(&element), 3);
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
    _ = try element.call_appendChild((&child1));
    _ = try element.call_appendChild((&child2));

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Set start with valid offset
    try range.call_setStart(@ptrCast(&element), 1);
    try std.testing.expectEqual(@ptrCast(&element), range.start_container);
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
    _ = try element.call_appendChild((&child1));
    _ = try element.call_appendChild((&child2));

    // Create a range
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Set end with valid offset
    try range.call_setEnd(@ptrCast(&element), 1);
    try std.testing.expectEqual(@ptrCast(&element), range.end_container);
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
    _ = try div.call_appendChild((&span1));
    _ = try div.call_appendChild((&span2));

    // Create a range from (div, 0) to (div, 1)
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();
    try range.call_setStart((&div), 0);
    try range.call_setEnd((&div), 1);

    // Set start to (div, 2) - after end
    try range.call_setStart((&div), 2);

    // End should be adjusted to match start
    try std.testing.expectEqual((&div), range.start_container);
    try std.testing.expectEqual(@as(u32, 2), range.start_offset);
    try std.testing.expectEqual((&div), range.end_container);
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
    _ = try div.call_appendChild((&span1));
    _ = try div.call_appendChild((&span2));

    // Create a range from (div, 1) to (div, 2)
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();
    try range.call_setStart((&div), 1);
    try range.call_setEnd((&div), 2);

    // Set end to (div, 0) - before start
    try range.call_setEnd((&div), 0);

    // Start should be adjusted to match end
    try std.testing.expectEqual((&div), range.start_container);
    try std.testing.expectEqual(@as(u32, 0), range.start_offset);
    try std.testing.expectEqual((&div), range.end_container);
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
    var range = try dom.Range.init(allocator, @ptrCast(&doc));
    defer range.deinit();

    // Valid: offset 5 (equal to length)
    try range.call_setStart(@ptrCast(&text).base, 5);
    try std.testing.expectEqual(@as(u32, 5), range.start_offset);

    // Invalid: offset 6 (greater than length)
    const result = range.call_setStart(@ptrCast(&text).base, 6);
    try std.testing.expectError(error.IndexSizeError, result);
}
