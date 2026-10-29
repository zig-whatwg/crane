//! Lane nav2 E: synchronous (same-document) navigations in the joint session
//! history (HTML "URL and history update steps", "navigate to a fragment" and
//! "finalize a same-document navigation").
//!
//! - The synchronous steps make the new entry the navigable's ACTIVE entry and
//!   write its document's view (push: History index + 1, length = index + 1;
//!   the navigation API's entries cut after the current one, the new one
//!   appended; replace: in place) - but the entry is not LISTED: the joint
//!   history's steps, its length and every traversal endpoint ignore it until
//!   its finalize runs on the traversal queue.
//! - Pending entries of a navigable form a FIFO chain, so two synchronous
//!   navigations in one task keep both entries (whatwg/html#10232: the
//!   literal finalize step 2 drops the first, and a replace of it then finds
//!   nothing to replace). The chain is dropped when a traversal activates an
//!   entry for the navigable, and listed by an inline cross-document commit
//!   (stated, until F1).
//! - "Apply the push/replace history step" runs inline in the finalize: the
//!   current step moves to the entry's step, and views not held by a waiting
//!   traversal are written at once.

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame: u64 = 2;
const other: u64 = 3;

fn single(h: *joint.JointHistory) !void {
    try h.addInitialEntry(top, "http://x.test/p", null, "http://x.test");
}

fn apiIds(h: *joint.JointHistory, navigable: u64, out: *std.ArrayListUnmanaged(u64)) !usize {
    var entries: std.ArrayListUnmanaged(*joint.Entry) = .empty;
    defer entries.deinit(testing.allocator);
    const index = try h.apiView(navigable, testing.allocator, &entries);
    out.clearRetainingCapacity();
    for (entries.items) |entry| try out.append(testing.allocator, entry.id);
    return index;
}

test "a same-document push is active at once and listed only when finalized: the traversal endpoints ignore it until then" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const base = h.currentEntry(top).?.id;

    const nav = try h.navigateSameDocument(top, "http://x.test/p#1", .null, .push, null);
    try testing.expect(nav.replaces == null);
    // Active: the entry the document shows, and what its History reads.
    try testing.expectEqual(nav.entry, h.activeEntry(top).?.id);
    try testing.expectEqual(nav.entry, h.currentEntry(top).?.id);
    try testing.expectEqualStrings("http://x.test/p#1", h.entryById(nav.entry).?.url);
    try testing.expect(h.isPending(nav.entry));
    // Not listed: the joint history still has one step.
    try testing.expectEqual(base, h.listedCurrentEntry(top).?.id);
    try testing.expect(h.entryAt(top, 1) == null);
    try testing.expect(h.stepByDelta(-1) == null);
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    // The document's view: "temporary best-guess values for immediate
    // synchronous access", and the navigation API's entries.
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);
    var ids: std.ArrayListUnmanaged(u64) = .empty;
    defer ids.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), try apiIds(&h, top, &ids));
    try testing.expectEqualSlices(u64, &.{ base, nav.entry }, ids.items);
    try testing.expectEqual(nav.entry, h.apiCurrentView(top).?.id);

    // Finalize: listed one step on, the current step moves there (the push
    // step's apply, inline), and the view is the live one again.
    const done = h.finalizeSameDocument(top, nav.entry, nav.replaces) orelse return error.NotFinalized;
    try testing.expectEqual(@as(u32, 1), done.step);
    try testing.expect(!h.isPending(nav.entry));
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expectEqual(@as(usize, 2), h.entryCount(top));
    try testing.expectEqual(nav.entry, h.listedCurrentEntry(top).?.id);
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);
    // Finalizing again finds nothing pending.
    try testing.expect(h.finalizeSameDocument(top, nav.entry, nav.replaces) == null);
}

test "two pushes in one task keep both entries (whatwg/html#10232), finalized in order, ending at the second" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const first = try h.navigateSameDocument(top, "http://x.test/1", .null, .push, .undefined);
    const second = try h.navigateSameDocument(top, "http://x.test/2", .null, .push, .undefined);
    try testing.expectEqual(second.entry, h.activeEntry(top).?.id);
    try testing.expectEqual(@as(u32, 3), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 2), h.historyView(top).index);

    // The first finalize lists the first entry; the view stays as the
    // synchronous steps wrote it while the second is pending.
    try testing.expectEqual(@as(u32, 1), (h.finalizeSameDocument(top, first.entry, first.replaces) orelse return error.NotFinalized).step);
    try testing.expect(h.isPending(second.entry));
    try testing.expectEqual(@as(u32, 3), h.historyView(top).length);
    try testing.expectEqual(second.entry, h.activeEntry(top).?.id);
    try testing.expectEqual(@as(u32, 2), (h.finalizeSameDocument(top, second.entry, second.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(@as(u32, 2), h.current_step);
    try testing.expectEqual(@as(usize, 3), h.entryCount(top));
    try testing.expectEqual(@as(u32, 3), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 2), h.historyView(top).index);
    // Back lands on the first.
    try testing.expectEqual(first.entry, h.entryAt(top, h.stepByDelta(-1).?).?.id);
}

test "a later entry's finalize lists the earlier pending ones of its navigable first" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const first = try h.navigateSameDocument(top, "http://x.test/1", .null, .push, .undefined);
    const second = try h.navigateSameDocument(top, "http://x.test/2", .null, .push, .undefined);
    try testing.expectEqual(@as(u32, 2), (h.finalizeSameDocument(top, second.entry, second.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(first.entry, h.entryAt(top, 1).?.id);
    try testing.expect(h.finalizeSameDocument(top, first.entry, first.replaces) == null);
    try testing.expectEqual(@as(u32, 2), h.current_step);
}

test "push then replace in one task: the replacing entry takes the pushed entry's place, with its key" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const pushed = try h.navigateSameDocument(top, "http://x.test/1", .null, .push, .undefined);
    const key = h.entryById(pushed.entry).?.api_key;
    const replaced = try h.navigateSameDocument(top, "http://x.test/1b", .null, .replace, .undefined);
    try testing.expectEqual(@as(?u64, pushed.entry), replaced.replaces);
    try testing.expectEqualSlices(u8, &key, &h.entryById(replaced.entry).?.api_key);
    // A replace keeps the best-guess length and index.
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);

    _ = h.finalizeSameDocument(top, pushed.entry, pushed.replaces) orelse return error.NotFinalized;
    try testing.expectEqual(@as(u32, 1), (h.finalizeSameDocument(top, replaced.entry, replaced.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expectEqual(@as(usize, 2), h.entryCount(top));
    try testing.expect(h.entryById(pushed.entry) == null);
    try testing.expectEqual(replaced.entry, h.entryAt(top, 1).?.id);
    try testing.expectEqualStrings("http://x.test/1b", h.entryAt(top, 1).?.url);
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);
}

test "replace then replace in one task: the listed entry is replaced in place twice, at its step" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const base = h.currentEntry(top).?.id;
    const a = try h.navigateSameDocument(top, "http://x.test/a", .null, .replace, .undefined);
    const b = try h.navigateSameDocument(top, "http://x.test/b", .null, .replace, .undefined);
    try testing.expectEqual(@as(?u64, base), a.replaces);
    try testing.expectEqual(@as(?u64, a.entry), b.replaces);
    try testing.expectEqual(@as(u32, 0), (h.finalizeSameDocument(top, a.entry, a.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(@as(u32, 0), (h.finalizeSameDocument(top, b.entry, b.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(@as(usize, 1), h.entryCount(top));
    try testing.expectEqualStrings("http://x.test/b", h.currentEntry(top).?.url);
    try testing.expectEqual(@as(u32, 0), h.current_step);
}

test "a traversal's activation drops the navigable's pending entries, and their finalize does nothing" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    const base = h.currentEntry(top).?.id;
    const nav = try h.navigateSameDocument(top, "http://x.test/p#1", .null, .push, null);
    h.dropPending(top);
    try testing.expect(h.entryById(nav.entry) == null);
    try testing.expectEqual(base, h.activeEntry(top).?.id);
    try testing.expect(h.finalizeSameDocument(top, nav.entry, nav.replaces) == null);
    try testing.expectEqual(@as(usize, 1), h.entryCount(top));
    try testing.expectEqual(@as(u32, 0), h.current_step);
    // The view is written from the history again.
    h.updateViews();
    try testing.expectEqual(@as(u32, 1), h.historyView(top).length);
}

test "an inline cross-document commit lists the pending same-document entries first (stated, until F1)" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    try h.addChildInitialEntry(frame, top, "about:srcdoc", null, "http://x.test");
    const nav = try h.navigateSameDocument(frame, "about:srcdoc#1", .null, .push, null);
    try h.commitDocument(top, "http://x.test/q", null, "http://x.test", .push);
    // The frame's push at step 1, then the top's new document at step 2.
    try testing.expect(!h.isPending(nav.entry));
    try testing.expectEqual(nav.entry, h.entryAt(frame, 1).?.id);
    try testing.expectEqualStrings("http://x.test/q", h.entryAt(top, 2).?.url);
    try testing.expectEqual(@as(u32, 2), h.current_step);
    try testing.expect(h.finalizeSameDocument(frame, nav.entry, nav.replaces) == null);
    try testing.expectEqual(@as(u32, 3), h.historyView(frame).length);
}

test "a same-document entry copies the active entry's scroll restoration mode and document state" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    var doc: u8 = 0;
    try h.addInitialEntry(top, "http://x.test/p", &doc, "http://x.test");
    h.currentEntry(top).?.scroll_restoration_manual = true;
    const state = h.currentEntry(top).?.document_state;
    const nav = try h.navigateSameDocument(top, "http://x.test/p#1", .null, .push, null);
    const entry = h.entryById(nav.entry).?;
    try testing.expect(entry.scroll_restoration_manual);
    try testing.expectEqual(state, entry.document_state);
    try testing.expectEqual(@as(?*anyopaque, &doc), entry.document);
    // State-wide changes reach pending entries too.
    var replacement: u8 = 0;
    h.setDocumentOfState(state, &replacement);
    try testing.expectEqual(@as(?*anyopaque, &replacement), h.entryById(nav.entry).?.document);
    h.forgetDocumentWithPolicy(@ptrCast(&replacement), null);
    try testing.expect(h.entryById(nav.entry).?.document == null);
}

test "a pending push names the forward entries it will prune: the view loses their keys at once" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    try h.commitSameDocument(top, "http://x.test/p#f", .null, .push, null);
    const forward = h.currentEntry(top).?;
    const forward_key = forward.api_key;
    const forward_id = forward.id;
    h.setCurrentStep(0);
    try testing.expect(h.viewHasKey(top, &forward_key));
    try testing.expect(!h.hasPendingPush());
    const nav = try h.navigateSameDocument(top, "http://x.test/p#c", .null, .push, null);
    try testing.expect(h.hasPendingPush());
    // Still listed until the finalize clears the forward history, but no
    // longer in the document's navigation API entries.
    try testing.expect(h.entryById(forward_id) != null);
    try testing.expect(!h.viewHasKey(top, &forward_key));
    const done = h.finalizeSameDocument(top, nav.entry, nav.replaces) orelse return error.NotFinalized;
    try testing.expect(done.removed);
    try testing.expect(h.entryById(forward_id) == null);
    try testing.expect(!h.hasPendingPush());
}

test "every document's view reads a pending push at once, as if listed: a frame's push moves its parent's history.length (001.html)" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    try h.addChildInitialEntry(frame, top, "about:srcdoc", null, "http://x.test");
    const nav = try h.navigateSameDocument(frame, "about:srcdoc#1", .null, .push, null);
    try testing.expectEqual(@as(u32, 2), h.historyView(frame).length);
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);
    // The listed history - the traversal endpoints' - has not moved.
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    try testing.expect(h.stepByDelta(-1) == null);
    // Another navigable's push, finalized at once: both read both.
    try h.commitSameDocument(top, "http://x.test/p#t", .null, .push, null);
    try testing.expectEqual(@as(u32, 3), h.historyView(frame).length);
    try testing.expectEqual(@as(u32, 3), h.historyView(top).length);
    _ = h.finalizeSameDocument(frame, nav.entry, nav.replaces) orelse return error.NotFinalized;
    try testing.expectEqual(@as(u32, 3), h.historyView(frame).length);
    try testing.expectEqual(@as(u32, 3), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 2), h.current_step);
}

test "a finalize that jumps a waiting traversal (14.1) lists its entry, but the views the traversal holds stay until it writes them" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    try h.addChildInitialEntry(frame, top, "about:srcdoc", null, "http://x.test");
    try h.addChildInitialEntry(other, top, "about:srcdoc", null, "http://x.test");
    try h.commitSameDocument(frame, "about:srcdoc#1", .null, .push, null);
    try h.commitSameDocument(frame, "about:srcdoc#2", .null, .push, null);
    const at_1 = h.entryAt(frame, 1).?.id;
    // A traversal to step 1 waits for its change jobs: the frame changes;
    // every view is held.
    h.beginApply(9, 1);
    h.setCurrentEntry(frame, at_1);
    h.holdAllViews();
    // Meanwhile the frame navigates to #3: its own document's view is written
    // as the synchronous steps write it; the held others are not.
    const nav = try h.navigateSameDocument(frame, "about:srcdoc#3", .null, .push, null);
    try testing.expectEqual(@as(u32, 4), h.historyView(frame).length);
    try testing.expectEqual(nav.entry, h.apiCurrentView(frame).?.id);
    try testing.expectEqual(@as(u32, 3), h.historyView(other).length);
    // Its finalize jumps the traversal: listed at the current step (2) + 1,
    // and the current step is 3 until the traversal's step 20.
    try testing.expectEqual(@as(u32, 3), (h.finalizeSameDocument(frame, nav.entry, nav.replaces) orelse return error.NotFinalized).step);
    try testing.expectEqual(@as(u32, 3), h.current_step);
    try testing.expect(h.isApplying(9));
    // The residual difference (stated in finalizeSameDocument): the other
    // frame's held view keeps its length until the traversal's step 18
    // writes it - given the traversal's target step.
    try testing.expectEqual(@as(u32, 3), h.historyView(other).length);
    h.releaseView(other);
    try testing.expectEqual(@as(u32, 4), h.historyView(other).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(other).index);
    // The frame's document shows #3 until the traversal's update writes its
    // view: 12.1's displayedEntry.
    try testing.expectEqual(nav.entry, h.displayedEntry(frame).?.id);
    h.releaseView(frame);
    try testing.expectEqual(at_1, h.apiCurrentView(frame).?.id);
    h.endApply(9);
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expectEqual(@as(u32, 4), h.lengthAndIndex().length);
}

test "a same-document navigation while an apply runs does not settle it (E flipped the stated deviation for same-document commits)" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try single(&h);
    try h.addChildInitialEntry(frame, top, "about:srcdoc", null, "http://x.test");
    try h.commitSameDocument(frame, "about:srcdoc#1", .null, .push, null);
    h.beginApply(4, 0);
    h.setCurrentEntry(frame, h.entryAt(frame, 0).?.id);
    h.holdAllViews();
    const nav = try h.navigateSameDocument(top, "http://x.test/p#t", .null, .push, null);
    try testing.expect(h.isApplying(4));
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expect(h.isPending(nav.entry));
    h.endApply(4);
    try testing.expectEqual(@as(u32, 0), h.current_step);
    h.releaseAllViews();
}
