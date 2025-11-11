//! Range Tests (DOM Standard §5)
//! Tests for Range interface

const std = @import("std");
const testing = std.testing;
const Range = @import("range").Range;
const Document = @import("document").Document;
const Node = @import("node").Node;
const Element = @import("element").Element;
const Text = @import("text").Text;

test "Range: init creates range with document boundary" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    try testing.expect(range.get_startContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expect(range.get_endContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_endOffset());
}

test "Range: collapsed returns true for same boundary points" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Initially collapsed
    try testing.expect(range.get_collapsed());

    // Set different end position
    var elem = try doc.call_createElement("div");
    try range.call_setEnd(&elem.base, 0);

    // Should not be collapsed anymore (different container)
    if (range.get_startContainer() != range.get_endContainer()) {
        try testing.expect(!range.get_collapsed());
    }
}

test "Range: setStart updates start boundary point" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 5);

    try testing.expect(range.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 5), range.get_startOffset());
}

test "Range: setEnd updates end boundary point" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setEnd(&elem.base, 10);

    try testing.expect(range.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 10), range.get_endOffset());
}

test "Range: collapse to start" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set different start and end
    var elem1 = try doc.call_createElement("div");
    var elem2 = try doc.call_createElement("span");

    try range.call_setStart(&elem1.base, 0);
    try range.call_setEnd(&elem2.base, 5);

    // Collapse to start
    range.call_collapse(true);

    try testing.expect(range.get_collapsed());
    try testing.expect(range.get_startContainer() == &elem1.base);
    try testing.expect(range.get_endContainer() == &elem1.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(@as(u32, 0), range.get_endOffset());
}

test "Range: collapse to end" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Set different start and end
    var elem1 = try doc.call_createElement("div");
    var elem2 = try doc.call_createElement("span");

    try range.call_setStart(&elem1.base, 0);
    try range.call_setEnd(&elem2.base, 5);

    // Collapse to end
    range.call_collapse(false);

    try testing.expect(range.get_collapsed());
    try testing.expect(range.get_startContainer() == &elem2.base);
    try testing.expect(range.get_endContainer() == &elem2.base);
    try testing.expectEqual(@as(u32, 5), range.get_startOffset());
    try testing.expectEqual(@as(u32, 5), range.get_endOffset());
}

test "Range: selectNodeContents sets range to node's children" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    // Add some children
    const text1 = try doc.call_createTextNode("Hello");
    try elem.call_appendChild(&text1.base);

    const text2 = try doc.call_createTextNode(" World");
    try elem.call_appendChild(&text2.base);

    // Select node contents
    try range.call_selectNodeContents(&elem.base);

    try testing.expect(range.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expect(range.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 2), range.get_endOffset()); // 2 children
}

test "Range: cloneRange creates independent copy" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range1 = try Range.init(allocator, &doc.base);
    defer range1.deinit();

    var elem = try doc.call_createElement("div");
    try range1.call_setStart(&elem.base, 5);
    try range1.call_setEnd(&elem.base, 10);

    var range2 = try range1.call_cloneRange();
    defer {
        range2.deinit();
        allocator.destroy(range2);
    }

    // Should have same boundary points
    try testing.expect(range2.get_startContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 5), range2.get_startOffset());
    try testing.expect(range2.get_endContainer() == &elem.base);
    try testing.expectEqual(@as(u32, 10), range2.get_endOffset());

    // Should be independent
    try range2.call_setStart(&doc.base, 0);
    try testing.expect(range1.get_startContainer() == &elem.base); // Original unchanged
}

test "Range: detach does nothing (compatibility)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Should not crash or change state
    range.call_detach();

    try testing.expect(range.get_startContainer() == &doc.base);
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
}

test "Range: commonAncestorContainer for same node" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    var elem = try doc.call_createElement("div");

    try range.call_setStart(&elem.base, 0);
    try range.call_setEnd(&elem.base, 5);

    const common = range.get_commonAncestorContainer();
    try testing.expect(common == &elem.base);
}

test "Range: commonAncestorContainer finds parent" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var range = try Range.init(allocator, &doc.base);
    defer range.deinit();

    // Create: parent > child1, child2
    var parent = try doc.call_createElement("div");
    const child1 = try doc.call_createElement("span");
    const child2 = try doc.call_createElement("p");

    try parent.call_appendChild(&child1.base);
    try parent.call_appendChild(&child2.base);

    // Range from child1 to child2
    try range.call_setStart(&child1.base, 0);
    try range.call_setEnd(&child2.base, 0);

    const common = range.get_commonAncestorContainer();
    try testing.expect(common == &parent.base);
}
