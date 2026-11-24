//! Lane mcp1, batch 4: the browser's record of each history step - what
//! Chrome keeps on a NavigationEntry (title, transition type, user-typed
//! URL; content/browser/renderer_host/navigation_entry_impl.h) and CDP's
//! Page.getNavigationHistory lists - kept on the entry that introduced the
//! step (JointHistory.navigationEntries). User agent data: nothing of HTML's
//! reads it. What Chrome 157 does (tests/devtools/mcp1_history_test.zig):
//! the first entry is auto_toplevel; a child's step and a same-document
//! push clone the record of the step they were made from (NavigationEntry
//! CloneAndReplace), a same-document one as a link; a title changes the
//! current step's record only; a reload marks it reload and keeps it.

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame: u64 = 2;

fn expectEntry(got: joint.NavigationEntry, url: []const u8, transition: joint.NavigationEntryRecord.Transition, typed: []const u8, title: []const u8) !void {
    try testing.expectEqualStrings(url, got.url);
    try testing.expectEqual(transition, got.transition);
    try testing.expectEqualStrings(typed, got.user_typed_url);
    try testing.expectEqualStrings(title, got.title);
}

test "navigation entries: one per step, each with its step's record, as Chrome's NavigationController lists them" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var list: std.ArrayList(joint.NavigationEntry) = .empty;
    defer list.deinit(testing.allocator);

    // The traversable's first entry: auto_toplevel, typed as its URL.
    try h.addInitialEntry(top, "about:blank", null, "null");
    var current = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(@as(usize, 0), current);
    try testing.expectEqual(@as(usize, 1), list.items.len);
    try expectEntry(list.items[0], "about:blank", .auto_toplevel, "about:blank", "");
    const first_id = list.items[0].id;

    // A top-level cross-document push: the commit records how it came.
    try h.commitDocument(top, "http://x.test/", null, "http://x.test", .push);
    h.recordNavigationEntry(h.currentEntry(top).?.id, .typed, "http://x.test/");
    h.recordTitle("replay");
    // A child's first entry adds no step; its push does - cloned.
    try h.addChildInitialEntry(frame, top, "about:blank", null, "http://x.test");
    try h.commitDocument(frame, "http://x.test/data.json", null, "http://x.test", .push);
    // A same-document push of the top: cloned, as a link.
    try h.commitSameDocument(top, "http://x.test/pushed", .null, .push, null);
    // A title for the current step only.
    h.recordTitle("Changed");
    current = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(@as(usize, 3), current);
    try testing.expectEqual(@as(usize, 4), list.items.len);
    try testing.expectEqual(first_id, list.items[0].id);
    try expectEntry(list.items[1], "http://x.test/", .typed, "http://x.test/", "replay");
    // The child's step: the top's URL, the top's record cloned.
    try expectEntry(list.items[2], "http://x.test/", .typed, "http://x.test/", "replay");
    try expectEntry(list.items[3], "http://x.test/pushed", .link, "http://x.test/", "Changed");
    // Each step's own id: the entry that introduced it.
    try testing.expect(list.items[1].id != list.items[2].id and list.items[2].id != list.items[3].id);

    // A reload marks the current step's record; its id stays.
    const before = list.items[3].id;
    h.recordReload();
    _ = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(before, list.items[3].id);
    try testing.expectEqual(joint.NavigationEntryRecord.Transition.reload, list.items[3].transition);

    // A replace keeps its step's record with the entry that takes its place.
    try h.commitSameDocument(top, "http://x.test/replaced", .null, .replace, null);
    _ = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(@as(usize, 4), list.items.len);
    try expectEntry(list.items[3], "http://x.test/replaced", .link, "http://x.test/", "Changed");
}

test "navigation entries: a push from a past step drops the forward steps and their records" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var list: std.ArrayList(joint.NavigationEntry) = .empty;
    defer list.deinit(testing.allocator);
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .push);
    h.recordNavigationEntry(h.currentEntry(top).?.id, .form_submit, "http://x.test/b?q");
    try h.commitDocument(top, "http://x.test/c", null, "http://x.test", .push);
    h.recordNavigationEntry(h.currentEntry(top).?.id, .link, "http://x.test/c");
    // Back to b, then a new push: c's step goes.
    h.setCurrentStep(h.stepByDelta(-1).?);
    try h.commitDocument(top, "http://x.test/d", null, "http://x.test", .push);
    h.recordNavigationEntry(h.currentEntry(top).?.id, .typed, "http://x.test/d");
    const current = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(@as(usize, 2), current);
    try testing.expectEqual(@as(usize, 3), list.items.len);
    try expectEntry(list.items[1], "http://x.test/b", .form_submit, "http://x.test/b?q", "");
    try expectEntry(list.items[2], "http://x.test/d", .typed, "http://x.test/d", "");
}

test "pruning all but the current step (CDP Page.resetNavigationHistory, Chrome's PruneAllButLastCommitted): one step left, its entries, its record and id" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var list: std.ArrayList(joint.NavigationEntry) = .empty;
    defer list.deinit(testing.allocator);
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    try h.addChildInitialEntry(frame, top, "http://x.test/f0", null, "http://x.test");
    try h.commitDocument(frame, "http://x.test/f1", null, "http://x.test", .push);
    try h.commitSameDocument(top, "http://x.test/a#1", .null, .push, null);
    h.recordTitle("one");
    try h.commitSameDocument(top, "http://x.test/a#2", .null, .push, null);
    // Back to #1, with #2 ahead.
    h.setCurrentStep(h.stepByDelta(-1).?);
    _ = try h.navigationEntries(testing.allocator, &list);
    const kept_id = list.items[2].id;
    try testing.expectEqual(@as(usize, 4), list.items.len);

    try testing.expect(h.pruneAllButCurrent());
    const current = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqual(@as(usize, 0), current);
    try testing.expectEqual(@as(usize, 1), list.items.len);
    try testing.expectEqual(kept_id, list.items[0].id);
    try expectEntry(list.items[0], "http://x.test/a#1", .link, "http://x.test/a", "one");
    const li = h.lengthAndIndex();
    try testing.expectEqual(@as(u32, 1), li.length);
    try testing.expectEqual(@as(u32, 0), li.index);
    // Each navigable keeps the entry current at that step: the frame's f1.
    try testing.expectEqualStrings("http://x.test/f1", h.currentEntry(frame).?.url);
    try testing.expectEqualStrings("http://x.test/a#1", h.currentEntry(top).?.url);
    try testing.expect(h.stepByDelta(-1) == null and h.stepByDelta(1) == null);
    // The history goes on from there.
    try h.commitSameDocument(top, "http://x.test/a#3", .null, .push, null);
    try testing.expectEqual(@as(u32, 2), h.lengthAndIndex().length);
}

test "a title that arrives while an apply runs is its target step's: a new document's parsed title, before step 20" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var list: std.ArrayList(joint.NavigationEntry) = .empty;
    defer list.deinit(testing.allocator);
    try h.addInitialEntry(top, "http://x.test/a", null, "http://x.test");
    h.recordTitle("A");
    try h.commitDocument(top, "http://x.test/b", null, "http://x.test", .push);
    h.recordTitle("B");
    // A traversal back to a's step: its new document's title lands on a's
    // step, not on the step the traversal leaves.
    h.beginApply(7, h.stepByDelta(-1).?);
    h.recordTitle("A again");
    h.endApply(7);
    _ = try h.navigationEntries(testing.allocator, &list);
    try testing.expectEqualStrings("A again", list.items[0].title);
    try testing.expectEqualStrings("B", list.items[1].title);
}
