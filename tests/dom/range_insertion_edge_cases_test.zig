//! Range Tracking Edge Cases - Insertion Tests
//!
//! Tests for live range updates during node insertion, focusing on edge cases:
//! 1. Range boundary offsets shift when nodes are inserted before them
//! 2. Multiple ranges affected by single insertion
//! 3. Insertion at various positions relative to range boundaries
//! 4. Inserting nodes with text content affecting offsets

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Range = dom.Range;

const testing = std.testing;

// Test: Range offsets shift when node inserted before range start
//
// Tree structure:
// <parent>
//   <a>text</a>
//   <b>text</b>
// </parent>
//
// Range: [parent, 1] to [parent, 2]  (from <a> to <b>)
// Insert <new> before <a> at position 0
// Expected after insertion: [parent, 2] to [parent, 3]
test "Range insertion - insert before range shifts offsets" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    // Create children
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit();
    const a_text = try doc_ptr.call_createTextNode("text");
    defer a_text.deinit();
    _ = try dom.mutation.append(@ptrCast(a_text), @ptrCast(a));

    const b = try doc_ptr.call_createElement("b");
    defer b.deinit();
    const b_text = try doc_ptr.call_createTextNode("text");
    defer b_text.deinit();
    _ = try dom.mutation.append(@ptrCast(b_text), @ptrCast(b));

    // Build tree
    _ = try dom.mutation.append(@ptrCast(a), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(b), @ptrCast(parent));

    // Create range: [parent, 1] to [parent, 2]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(parent, 1);
    try range.call_setEnd(parent, 2);

    // Register range with document
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());

    // Insert new node before position 0 (before <a>)
    const new_node = try doc_ptr.call_createElement("new");
    defer new_node.deinit();
    try dom.mutation.preInsert(new_node, parent, a);

    // After insertion, range should shift: [parent, 2] to [parent, 3]
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 2), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());
}

// Test: Range with end at insertion point gets shifted
//
// Tree structure:
// <parent>
//   <a>text</a>
//   <b>text</b>
// </parent>
//
// Range: [parent, 0] to [parent, 1]  (from start to <a>)
// Insert <new> at position 1 (between <a> and <b>)
// Expected after insertion: [parent, 0] to [parent, 2]
test "Range insertion - insert at end boundary shifts end offset" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    // Create children
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit();
    const a_text = try doc_ptr.call_createTextNode("text");
    defer a_text.deinit();
    _ = try dom.mutation.append(@ptrCast(a_text), @ptrCast(a));

    const b = try doc_ptr.call_createElement("b");
    defer b.deinit();
    const b_text = try doc_ptr.call_createTextNode("text");
    defer b_text.deinit();
    _ = try dom.mutation.append(@ptrCast(b_text), @ptrCast(b));

    // Build tree
    _ = try dom.mutation.append(@ptrCast(a), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(b), @ptrCast(parent));

    // Create range: [parent, 0] to [parent, 1]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(parent, 0);
    try range.call_setEnd(parent, 1);

    // Register range with document
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 1), range.get_endOffset());

    // Insert new node at position 1 (between <a> and <b>)
    const new_node = try doc_ptr.call_createElement("new");
    defer new_node.deinit();
    try dom.mutation.preInsert(new_node, parent, b);

    // After insertion, end offset should shift: [parent, 0] to [parent, 2]
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());
}

// Test: Multiple overlapping ranges affected by single insertion
//
// Tree structure:
// <parent>
//   <a>text</a>
//   <b>text</b>
//   <c>text</c>
// </parent>
//
// Range1: [parent, 0] to [parent, 2]
// Range2: [parent, 1] to [parent, 3]
// Insert <new> at position 1
// Expected:
//   Range1: [parent, 0] to [parent, 3]
//   Range2: [parent, 2] to [parent, 4]
test "Range insertion - multiple ranges shifted by single insertion" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    // Create children
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit();
    const b = try doc_ptr.call_createElement("b");
    defer b.deinit();
    const c = try doc_ptr.call_createElement("c");
    defer c.deinit();

    // Build tree
    _ = try dom.mutation.append(@ptrCast(a), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(b), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(c), @ptrCast(parent));

    // Create range1: [parent, 0] to [parent, 2]
    const range1 = try allocator.create(dom.Range);
    defer allocator.destroy(range1);
    range1.* = try dom.Range.init(allocator, doc_ptr);
    defer range1.deinit();

    try range1.call_setStart(parent, 0);
    try range1.call_setEnd(parent, 2);
    try doc_ptr.ranges.append(range1);

    // Create range2: [parent, 1] to [parent, 3]
    const range2 = try allocator.create(dom.Range);
    defer allocator.destroy(range2);
    range2.* = try dom.Range.init(allocator, doc_ptr);
    defer range2.deinit();

    try range2.call_setStart(parent, 1);
    try range2.call_setEnd(parent, 3);
    try doc_ptr.ranges.append(range2);

    // Verify initial state
    try testing.expectEqual(@as(u32, 0), range1.get_startOffset());
    try testing.expectEqual(@as(u32, 2), range1.get_endOffset());
    try testing.expectEqual(@as(u32, 1), range2.get_startOffset());
    try testing.expectEqual(@as(u32, 3), range2.get_endOffset());

    // Insert new node at position 1 (between <a> and <b>)
    const new_node = try doc_ptr.call_createElement("new");
    defer new_node.deinit();
    try dom.mutation.preInsert(new_node, parent, b);

    // After insertion:
    // Range1: [parent, 0] to [parent, 3] (end shifts)
    // Range2: [parent, 2] to [parent, 4] (both shift)
    try testing.expectEqual(@as(u32, 0), range1.get_startOffset());
    try testing.expectEqual(@as(u32, 3), range1.get_endOffset());
    try testing.expectEqual(@as(u32, 2), range2.get_startOffset());
    try testing.expectEqual(@as(u32, 4), range2.get_endOffset());
}

// Test: Insertion inside collapsed range (start == end)
//
// Tree structure:
// <parent>
//   <a>text</a>
// </parent>
//
// Range: [parent, 1] to [parent, 1] (collapsed after <a>)
// Insert <new> at position 0
// Expected after insertion: [parent, 2] to [parent, 2]
test "Range insertion - collapsed range shifts when inserted before" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    // Create child
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit();
    _ = try dom.mutation.append(@ptrCast(a), @ptrCast(parent));

    // Create collapsed range: [parent, 1] to [parent, 1]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(parent, 1);
    try range.call_setEnd(parent, 1);
    try doc_ptr.ranges.append(range);

    // Verify initial collapsed state
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(@as(u32, 1), range.get_endOffset());
    try testing.expect(range.call_collapsed());

    // Insert new node at position 0 (before <a>)
    const new_node = try doc_ptr.call_createElement("new");
    defer new_node.deinit();
    try dom.mutation.preInsert(new_node, parent, a);

    // After insertion, collapsed range should shift: [parent, 2] to [parent, 2]
    try testing.expectEqual(@as(u32, 2), range.get_startOffset());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());
    try testing.expect(range.call_collapsed());
}
