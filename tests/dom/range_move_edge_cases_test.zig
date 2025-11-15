//! Range Tracking Edge Cases - Move Tests
//!
//! Tests for live range updates during node moves (moveBefore operation), focusing on:
//! 1. Range offsets shift correctly when nodes move between parents
//! 2. Range boundaries adjust when node moves within same parent
//! 3. Multiple ranges affected by single move
//! 4. Range boundaries in moved subtree remain valid

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Range = dom.Range;

const testing = std.testing;

// Test: Range offsets shift when node moves to new parent before range
//
// Tree structure:
// <parent1>
//   <a>text</a>
// </parent1>
// <parent2>
//   <b>text</b>
//   <c>text</c>
// </parent2>
//
// Range: [parent2, 0] to [parent2, 2]
// Move <a> from parent1 to parent2 at position 0 (before <b>)
// Expected after move: [parent2, 1] to [parent2, 3]
test "Range move - moving node before range shifts offsets" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent1 and child
    const parent1 = try doc_ptr.call_createElement("parent1");
    defer parent1.deinit(allocator);
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit(allocator);
    try dom.mutation.append(a, parent1);

    // Create parent2 and children
    const parent2 = try doc_ptr.call_createElement("parent2");
    defer parent2.deinit(allocator);
    const b = try doc_ptr.call_createElement("b");
    defer b.deinit(allocator);
    const c = try doc_ptr.call_createElement("c");
    defer c.deinit(allocator);
    try dom.mutation.append(b, parent2);
    try dom.mutation.append(c, parent2);

    // Create range: [parent2, 0] to [parent2, 2]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(parent2, 0);
    try range.call_setEnd(parent2, 2);
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());

    // Move <a> to parent2 before <b>
    try dom.ParentNodeMixin.moveBefore(a, parent2, b);

    // After move, range should shift: [parent2, 1] to [parent2, 3]
    try testing.expectEqual(parent2, range.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(parent2, range.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());
}

// Test: Range with boundaries in moved node's old parent adjusts correctly
//
// Tree structure:
// <parent1>
//   <a>text</a>
//   <b>move me</b>
//   <c>text</c>
// </parent1>
// <parent2>
//   <d>text</d>
// </parent2>
//
// Range: [parent1, 1] to [parent1, 3]  (from <a> to end)
// Move <b> from parent1 to parent2
// Expected after move: [parent1, 1] to [parent1, 2] (end offset decreases)
test "Range move - range in old parent adjusts when node moves away" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent1 with children
    const parent1 = try doc_ptr.call_createElement("parent1");
    defer parent1.deinit(allocator);
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit(allocator);
    const b = try doc_ptr.call_createElement("b");
    defer b.deinit(allocator);
    const c = try doc_ptr.call_createElement("c");
    defer c.deinit(allocator);
    try dom.mutation.append(a, parent1);
    try dom.mutation.append(b, parent1);
    try dom.mutation.append(c, parent1);

    // Create parent2
    const parent2 = try doc_ptr.call_createElement("parent2");
    defer parent2.deinit(allocator);
    const d = try doc_ptr.call_createElement("d");
    defer d.deinit(allocator);
    try dom.mutation.append(d, parent2);

    // Create range: [parent1, 1] to [parent1, 3]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(parent1, 1);
    try range.call_setEnd(parent1, 3);
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());

    // Move <b> to parent2
    try dom.ParentNodeMixin.moveBefore(b, parent2, null);

    // After move, range end should decrease: [parent1, 1] to [parent1, 2]
    try testing.expectEqual(parent1, range.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(parent1, range.get_endContainer());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());
}

// Test: Range boundary inside moved subtree remains valid
//
// Tree structure:
// <parent1>
//   <a>
//     <text>content</text>  <-- range points here
//   </a>
// </parent1>
// <parent2></parent2>
//
// Range: [a.firstChild, 3] to [a.firstChild, 7]
// Move <a> to parent2
// Expected: Range boundaries remain unchanged (still pointing to text node)
test "Range move - boundaries in moved subtree remain valid" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent1 with child
    const parent1 = try doc_ptr.call_createElement("parent1");
    defer parent1.deinit(allocator);
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit(allocator);
    const text = try dom.NodeBase.createText(allocator, "content", doc_ptr);
    defer text.deinit(allocator);
    try dom.mutation.append(text, a);
    try dom.mutation.append(a, parent1);

    // Create parent2
    const parent2 = try doc_ptr.call_createElement("parent2");
    defer parent2.deinit(allocator);

    // Create range: [text, 3] to [text, 7]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(text, 3);
    try range.call_setEnd(text, 7);
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(text, range.get_startContainer());
    try testing.expectEqual(@as(u32, 3), range.get_startOffset());
    try testing.expectEqual(text, range.get_endContainer());
    try testing.expectEqual(@as(u32, 7), range.get_endOffset());

    // Move <a> (and its subtree) to parent2
    try dom.ParentNodeMixin.moveBefore(a, parent2, null);

    // After move, range boundaries should remain unchanged
    try testing.expectEqual(text, range.get_startContainer());
    try testing.expectEqual(@as(u32, 3), range.get_startOffset());
    try testing.expectEqual(text, range.get_endContainer());
    try testing.expectEqual(@as(u32, 7), range.get_endOffset());
}

// Test: Multiple ranges affected by node moving within same parent
//
// Tree structure:
// <parent>
//   <a>text</a>
//   <b>move me</b>
//   <c>text</c>
// </parent>
//
// Range1: [parent, 0] to [parent, 2]
// Range2: [parent, 1] to [parent, 3]
// Move <b> to position after <c> (within same parent)
// Expected:
//   Range1: [parent, 0] to [parent, 1] (end decreases)
//   Range2: [parent, 1] to [parent, 2] (both decrease)
test "Range move - multiple ranges shift when node moves within parent" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent with children
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit(allocator);
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit(allocator);
    const b = try doc_ptr.call_createElement("b");
    defer b.deinit(allocator);
    const c = try doc_ptr.call_createElement("c");
    defer c.deinit(allocator);

    try dom.mutation.append(a, parent);
    try dom.mutation.append(b, parent);
    try dom.mutation.append(c, parent);

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

    // Move <b> to end (after <c>) within same parent
    try dom.ParentNodeMixin.moveBefore(b, parent, null);

    // After move:
    // Tree order: <a>, <c>, <b>
    // Range1 should adjust: [parent, 0] to [parent, 1]
    // Range2 should adjust: [parent, 1] to [parent, 2]
    try testing.expectEqual(@as(u32, 0), range1.get_startOffset());
    try testing.expectEqual(@as(u32, 1), range1.get_endOffset());
    try testing.expectEqual(@as(u32, 1), range2.get_startOffset());
    try testing.expectEqual(@as(u32, 2), range2.get_endOffset());
}

// Test: Collapsed range at move source position adjusts correctly
//
// Tree structure:
// <parent1>
//   <a>text</a>
//   <b>move me</b>
// </parent1>
// <parent2></parent2>
//
// Range: [parent1, 1] to [parent1, 1] (collapsed between <a> and <b>)
// Move <b> to parent2
// Expected: [parent1, 1] to [parent1, 1] (remains collapsed, no shift needed)
test "Range move - collapsed range at source adjusts when node after it moves" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent1 with children
    const parent1 = try doc_ptr.call_createElement("parent1");
    defer parent1.deinit(allocator);
    const a = try doc_ptr.call_createElement("a");
    defer a.deinit(allocator);
    const b = try doc_ptr.call_createElement("b");
    defer b.deinit(allocator);
    try dom.mutation.append(a, parent1);
    try dom.mutation.append(b, parent1);

    // Create parent2
    const parent2 = try doc_ptr.call_createElement("parent2");
    defer parent2.deinit(allocator);

    // Create collapsed range: [parent1, 1] to [parent1, 1]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();
    try range.call_setStart(parent1, 1);
    try range.call_setEnd(parent1, 1);
    try doc_ptr.ranges.append(range);

    // Verify initial collapsed state
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(@as(u32, 1), range.get_endOffset());
    try testing.expect(range.call_collapsed());

    // Move <b> to parent2
    try dom.ParentNodeMixin.moveBefore(b, parent2, null);

    // After move, collapsed range remains at [parent1, 1]
    // (no adjustment needed since move is after the collapsed position)
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(@as(u32, 1), range.get_endOffset());
    try testing.expect(range.call_collapsed());
}
