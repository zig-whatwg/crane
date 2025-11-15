//! Range Tracking Edge Cases - Removal Tests
//!
//! Tests for live range updates during node removal, focusing on edge cases:
//! 1. Range spanning removed subtree
//! 2. Multiple overlapping ranges
//! 3. Boundaries in various positions relative to removal

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Range = dom.Range;

const testing = std.testing;

// Test: Range with start in removed node, end in kept node
//
// Tree structure:
// <parent>
//   <a>text</a>
//   <b>remove</b>  <-- this gets removed
//   <c>text</c>
// </parent>
//
// Range: [b.firstChild, 2] to [c.firstChild, 3]
// Expected after removal: [parent, 1] to [c.firstChild, 3]
test "Range removal - start in removed, end in kept" {
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
    const b_text = try doc_ptr.call_createTextNode("remove");
    defer b_text.deinit();
    _ = try dom.mutation.append(@ptrCast(b_text), @ptrCast(b));

    const c = try doc_ptr.call_createElement("c");
    defer c.deinit();
    const c_text = try doc_ptr.call_createTextNode("text");
    defer c_text.deinit();
    _ = try dom.mutation.append(@ptrCast(c_text), @ptrCast(c));

    // Build tree
    _ = try dom.mutation.append(@ptrCast(a), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(b), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(c), @ptrCast(parent));

    // Create range: [b.firstChild, 2] to [c.firstChild, 3]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(b_text, 2);
    try range.call_setEnd(c_text, 3);

    // Register range with document
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(b_text, range.get_startContainer());
    try testing.expectEqual(@as(u32, 2), range.get_startOffset());
    try testing.expectEqual(c_text, range.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());

    // Remove node b
    try dom.mutation.remove(b, false);

    // After removal, start should be [parent, 1] (index of removed node)
    // End should stay [c.firstChild, 3]
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(c_text, range.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());
}

// Test: Range fully contained within removed subtree
//
// Tree structure:
// <parent>
//   <removed>
//     <child1>start</child1>
//     <child2>end</child2>
//   </removed>
// </parent>
//
// Range: [child1.firstChild, 2] to [child2.firstChild, 3]
// Expected after removal: [parent, 0] to [parent, 0] (collapsed)
test "Range removal - fully contained in removed subtree" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent element
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    // Create removed subtree
    const removed = try doc_ptr.call_createElement("removed");
    defer removed.deinit();

    const child1 = try doc_ptr.call_createElement("child1");
    defer child1.deinit();
    const child1_text = try doc_ptr.call_createTextNode("start");
    defer child1_text.deinit();
    _ = try dom.mutation.append(@ptrCast(child1_text), @ptrCast(child1));

    const child2 = try doc_ptr.call_createElement("child2");
    defer child2.deinit();
    const child2_text = try doc_ptr.call_createTextNode("end");
    defer child2_text.deinit();
    _ = try dom.mutation.append(@ptrCast(child2_text), @ptrCast(child2));

    // Build tree
    _ = try dom.mutation.append(@ptrCast(child1), @ptrCast(removed));
    _ = try dom.mutation.append(@ptrCast(child2), @ptrCast(removed));
    _ = try dom.mutation.append(@ptrCast(removed), @ptrCast(parent));

    // Create range: [child1.firstChild, 2] to [child2.firstChild, 3]
    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, doc_ptr);
    defer range.deinit();

    try range.call_setStart(child1_text, 2);
    try range.call_setEnd(child2_text, 3);

    // Register range with document
    try doc_ptr.ranges.append(range);

    // Verify initial state
    try testing.expectEqual(child1_text, range.get_startContainer());
    try testing.expectEqual(@as(u32, 2), range.get_startOffset());
    try testing.expectEqual(child2_text, range.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range.get_endOffset());

    // Remove entire subtree
    try dom.mutation.remove(removed, false);

    // After removal, both boundaries should be [parent, 0] (collapsed at removal point)
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 0), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 0), range.get_endOffset());

    // Range should be collapsed
    try testing.expect(range.get_collapsed());
}

// Test: Multiple ranges affected by single removal
//
// Range1: [before, 5] to [removed.child, 2]
// Range2: [removed.child, 0] to [after, 3]
// Range3: [removed, 0] to [removed, 1]
//
// All should update correctly without interfering
test "Range removal - multiple overlapping ranges" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent and siblings
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

    const before = try doc_ptr.call_createTextNode("before text");
    defer before.deinit();

    const removed = try doc_ptr.call_createElement("removed");
    defer removed.deinit();
    const removed_child = try doc_ptr.call_createTextNode("child");
    defer removed_child.deinit();
    _ = try dom.mutation.append(@ptrCast(removed_child), @ptrCast(removed));

    const after = try doc_ptr.call_createTextNode("after text");
    defer after.deinit();

    // Build tree
    _ = try dom.mutation.append(@ptrCast(before), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(removed), @ptrCast(parent));
    _ = try dom.mutation.append(@ptrCast(after), @ptrCast(parent));

    // Create three ranges
    const range1 = try allocator.create(dom.Range);
    defer allocator.destroy(range1);
    range1.* = try dom.Range.init(allocator, @ptrCast(doc_ptr));
    defer range1.deinit();

    const range2 = try allocator.create(dom.Range);
    defer allocator.destroy(range2);
    range2.* = try dom.Range.init(allocator, doc_ptr);
    defer range2.deinit();

    const range3 = try allocator.create(dom.Range);
    defer allocator.destroy(range3);
    range3.* = try dom.Range.init(allocator, doc_ptr);
    defer range3.deinit();

    // Range1: [before, 5] to [removed.child, 2]
    try range1.call_setStart(before, 5);
    try range1.call_setEnd(removed_child, 2);

    // Range2: [removed.child, 0] to [after, 3]
    try range2.call_setStart(removed_child, 0);
    try range2.call_setEnd(after, 3);

    // Range3: [removed, 0] to [removed, 1]
    try range3.call_setStart(removed, 0);
    try range3.call_setEnd(removed, 1);

    // Register all ranges
    try doc_ptr.ranges.append(range1);
    try doc_ptr.ranges.append(range2);
    try doc_ptr.ranges.append(range3);

    // Remove node
    try dom.mutation.remove(removed, false);

    // Range1: Start should stay [before, 5], end should become [parent, 1]
    try testing.expectEqual(before, range1.get_startContainer());
    try testing.expectEqual(@as(u32, 5), range1.get_startOffset());
    try testing.expectEqual(parent, range1.get_endContainer());
    try testing.expectEqual(@as(u32, 1), range1.get_endOffset());

    // Range2: Start should become [parent, 1], end should stay [after, 3]
    try testing.expectEqual(parent, range2.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range2.get_startOffset());
    try testing.expectEqual(after, range2.get_endContainer());
    try testing.expectEqual(@as(u32, 3), range2.get_endOffset());

    // Range3: Should collapse at [parent, 1]
    try testing.expectEqual(parent, range3.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range3.get_startOffset());
    try testing.expectEqual(parent, range3.get_endContainer());
    try testing.expectEqual(@as(u32, 1), range3.get_endOffset());
    try testing.expect(range3.get_collapsed());
}

// Test: Range in parent with offset adjustments
//
// <parent>
//   <a/>
//   <b/>  <-- remove this (index 1)
//   <c/>
// </parent>
//
// Range: [parent, 2] to [parent, 3]
// After removal: [parent, 1] to [parent, 2]
test "Range removal - offset adjustment in parent" {
    const allocator = testing.allocator;

    // Create document
    const doc_ptr = try allocator.create(dom.Document);
    defer allocator.destroy(doc_ptr);
    doc_ptr.* = try dom.Document.init(allocator);
    defer doc_ptr.deinit();

    // Create parent and children
    const parent = try doc_ptr.call_createElement("parent");
    defer parent.deinit();

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

    const range = try allocator.create(dom.Range);
    defer allocator.destroy(range);
    range.* = try dom.Range.init(allocator, @ptrCast(doc_ptr));
    defer range.deinit();

    try range.call_setStart(@ptrCast(parent), 2);
    try range.call_setEnd(parent, 3);

    // Register range
    try doc_ptr.ranges.append(range);

    // Remove node b (at index 1)
    try dom.mutation.remove(b, false);

    // After removal:
    // - start offset 2 > removed index 1, so decrease by 1 → 1
    // - end offset 3 > removed index 1, so decrease by 1 → 2
    try testing.expectEqual(parent, range.get_startContainer());
    try testing.expectEqual(@as(u32, 1), range.get_startOffset());
    try testing.expectEqual(parent, range.get_endContainer());
    try testing.expectEqual(@as(u32, 2), range.get_endOffset());
}
