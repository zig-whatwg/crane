//! A traversable's session history: steps, push/replace, length and index,
//! traversal targets, and destroyed navigables (HTML 7.4.1, 7.4.6).

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame: u64 = 2;

test "a new traversable has one step; a push adds one, a replace none" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/a", null);
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);

    try h.commitDocument(top, "http://x.test/b", null, .push);
    var li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqual(@as(u32, 1), li.index);

    try h.commitDocument(top, "http://x.test/c", null, .replace);
    li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqualStrings("http://x.test/c", h.currentEntry(top).?.url);
}

test "a child's push is a step of the joint history; its initial entry is not" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null);
    try h.addInitialEntry(frame, "about:blank", null);
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    // The frame's first navigation replaces its initial about:blank.
    try h.commitDocument(frame, "http://x.test/f1", null, .replace);
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    try h.commitDocument(frame, "http://x.test/f2", null, .push);
    try testing.expectEqual(@as(u32, 2), h.lengthAndIndex().length);
    // Back one step: the frame's entry there is f1; the top's is unchanged.
    const back = h.stepByDelta(-1).?;
    try testing.expectEqualStrings("http://x.test/f1", h.entryAt(frame, back).?.url);
    try testing.expectEqual(h.currentEntry(top).?, h.entryAt(top, back).?);
    try testing.expect(h.stepByDelta(-2) == null);
    try testing.expect(h.stepByDelta(1) == null);
}

test "pushing clears the forward history" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/1", null);
    try h.commitDocument(top, "http://x.test/2", null, .push);
    try h.commitDocument(top, "http://x.test/3", null, .push);
    h.current_step = h.stepByDelta(-2).?;
    try h.commitDocument(top, "http://x.test/4", null, .push);
    const li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 2), li.length);
    try testing.expectEqual(@as(u32, 1), li.index);
}

test "same-document entries share the document state and carry state" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var doc: u8 = 0;
    try h.addInitialEntry(top, "http://x.test/p", &doc);
    const first_state = h.currentEntry(top).?.document_state;
    const s = try testing.allocator.dupe(u8, "state");
    try h.commitSameDocument(top, "http://x.test/p#x", .{ .string = s }, .push);
    const current = h.currentEntry(top).?;
    try testing.expectEqual(first_state, current.document_state);
    try testing.expectEqual(@as(?*anyopaque, &doc), current.document);
    try testing.expectEqualStrings("state", current.state.string);
}

test "a destroyed navigable's entries go, and the current step stays used" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null);
    try h.addInitialEntry(frame, "about:blank", null);
    try h.commitDocument(frame, "http://x.test/f2", null, .push);
    try testing.expectEqual(@as(u32, 2), h.lengthAndIndex().length);
    h.removeNavigable(frame);
    const li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 1), li.length);
    try testing.expectEqual(@as(u32, 0), li.index);
}

test "a srcdoc document's resource stays with its entries, and a new document drops it" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null);
    try h.addInitialEntry(frame, "about:blank", null);
    try h.commitDocument(frame, "about:srcdoc", null, .push);
    try h.setCurrentResource(frame, "<p>one");
    const srcdoc_step = h.current_step;
    // A fragment navigation on it shares its document state, resource and all.
    try h.commitSameDocument(frame, "about:srcdoc#yo", .null, .push);
    try testing.expectEqualStrings("<p>one", h.currentEntry(frame).?.resource.?);
    // A new document has none of its own until it is given one.
    try h.commitDocument(frame, "http://x.test/f", null, .push);
    try testing.expect(h.currentEntry(frame).?.resource == null);
    try testing.expectEqualStrings("<p>one", h.entryAt(frame, srcdoc_step).?.resource.?);
    // A replace is a new document state: the old resource goes with it.
    try h.commitDocument(frame, "about:srcdoc", null, .replace);
    try h.setCurrentResource(frame, "<p>two");
    try h.commitDocument(frame, "about:srcdoc", null, .replace);
    try testing.expect(h.currentEntry(frame).?.resource == null);
}
