//! Lane nav2 C2: the session history while "apply the history step" runs
//! (HTML 7.4.6.1), from its step 8 to its step 20 (JointHistory.beginApply /
//! endApply):
//!
//! - step 8.2 sets each changing navigable's current session history entry
//!   to its target entry, while the traversable's current session history
//!   step stays where it was until step 20;
//! - what the documents read is computed given targetStep (steps 14.7, 14.9
//!   and 17): a view written meanwhile, and a navigable made meanwhile, see
//!   the target step;
//! - an update-only change (a population that made no document) keeps the
//!   displayed entry at the target step;
//! - a destroyed navigable's entries go at once ("destroy a child navigable"
//!   step 7), and so do the other documents' History lengths - main's
//!   behaviour, a stated deviation from the queued update's step 18 (see
//!   JointHistory.removeNavigable: the browsers split three ways) -
//!   while the step moves only with the queued "update for navigable
//!   creation/destruction" ("getting the used step");
//! - a commit made inline while an apply runs settles the apply first - the
//!   stated deviation until E and F1 make those commits queue items (the
//!   test that pins it says what flips it).

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame: u64 = 2;
const other: u64 = 3;

/// top at step 0; the frame's entries f0 (step 0) and f1 (step 1, a
/// cross-document push); the other frame's single entry o0.
fn twoFrames(h: *joint.JointHistory) !void {
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addChildInitialEntry(frame, top, "http://x.test/f0", null, "http://x.test");
    try h.addChildInitialEntry(other, top, "http://x.test/o0", null, "http://x.test");
    try h.commitDocument(frame, "http://x.test/f1", null, "http://x.test", .push);
}

test "while an apply runs, a changing navigable's current entry is its target and the step is set only at step 20" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    const f0 = h.entryAt(frame, 0).?.id;
    try testing.expectEqual(@as(u32, 1), h.current_step);

    h.beginApply(7, 0);
    h.setCurrentEntry(frame, f0);
    // Step 8.2: the frame's current entry is the target; the step is not.
    try testing.expectEqual(f0, h.currentEntry(frame).?.id);
    try testing.expectEqual(@as(u32, 1), h.current_step);
    // A navigable that does not change reads what it read.
    try testing.expectEqualStrings("http://x.test/t", h.currentEntry(top).?.url);
    try testing.expect(h.isApplying(7));
    // Another apply's step 20 changes nothing.
    h.endApply(8);
    try testing.expectEqual(@as(u32, 1), h.current_step);

    // Step 20.
    h.endApply(7);
    try testing.expect(!h.isApplying(7));
    try testing.expectEqual(@as(u32, 0), h.current_step);
    try testing.expectEqual(f0, h.currentEntry(frame).?.id);
}

test "views written while an apply runs are computed given its target step, and so is a navigable made meanwhile" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    const f0 = h.entryAt(frame, 0).?.id;
    const f1 = h.entryAt(frame, 1).?.id;

    h.beginApply(1, 0);
    h.setCurrentEntry(frame, f0);
    h.holdAllViews();
    // Held: every document still reads index 1, the frame f1.
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);
    try testing.expectEqual(f1, h.apiCurrentView(frame).?.id);

    // "Update document for history step application" for the frame: index
    // and entries given the target step.
    h.releaseView(frame);
    try testing.expectEqual(@as(u32, 0), h.historyView(frame).index);
    try testing.expectEqual(f0, h.apiCurrentView(frame).?.id);
    // The others stay held until their step 18.
    try testing.expectEqual(@as(u32, 1), h.historyView(top).index);

    // The frame's new document makes a frame of its own: its first entry is
    // at the step its parent's (target) document began at, and its view -
    // never held - reads the target step.
    const nested: u64 = 4;
    try h.addChildInitialEntry(nested, frame, "about:blank", null, "http://x.test");
    try testing.expectEqual(@as(u32, 0), h.entryAt(nested, 0).?.step);
    try testing.expectEqual(@as(u32, 0), h.historyView(nested).index);

    // Step 18 for the rest, then step 20: everyone reads the live history.
    h.releaseView(top);
    h.releaseView(other);
    try testing.expectEqual(@as(u32, 0), h.historyView(top).index);
    h.endApply(1);
    h.releaseAllViews();
    try testing.expectEqual(@as(u32, 0), h.current_step);
    try testing.expectEqual(@as(u32, 0), h.historyView(other).index);
}

test "an update-only change during an apply keeps the displayed entry at the target step" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    const f0 = h.entryAt(frame, 0).?.id;
    const f1 = h.entryAt(frame, 1).?.id;

    h.beginApply(2, 0);
    h.setCurrentEntry(frame, f0);
    // The population of f0 made no document (a 204): the frame keeps
    // showing f1, at the step the traversal goes to.
    try h.keepActiveEntry(frame, f1);
    h.endApply(2);
    try testing.expectEqual(@as(u32, 0), h.current_step);
    try testing.expectEqual(f1, h.activeEntry(frame).?.id);
    try testing.expectEqual(f0, h.currentEntry(frame).?.id);
}

test "a destroyed navigable's entries and the other documents' lengths go at once; the step moves with the queued update" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    // The frame pushed the only step-1 entry; the current step is 1.
    try testing.expectEqual(@as(u32, 2), h.historyView(top).length);

    h.removeNavigable(frame);
    // Step 7: its entries are gone...
    try testing.expect(!h.hasNavigable(frame));
    try testing.expect(!h.views.contains(frame));
    // ...the other documents' History lengths with them (stated deviation,
    // see removeNavigable), and the step stays until the update: no longer a
    // used step.
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 0), h.historyView(top).index);
    // "Getting the used step": the greatest used step at or before it.
    try testing.expectEqual(@as(?u32, 0), h.usedStepAtOrBefore(h.current_step));
    // Readers of the step treat it as that used step meanwhile.
    try testing.expectEqual(@as(u32, 1), h.lengthAndIndex().length);
    try testing.expectEqual(@as(u32, 0), h.lengthAndIndex().index);
    try testing.expect(h.stepByDelta(-1) == null);
    try testing.expectEqual(@as(?u32, 0), h.stepByDelta(0));

    // "Update for navigable creation/destruction": apply the used step.
    h.setCurrentStep(h.usedStepAtOrBefore(h.current_step).?);
    try testing.expectEqual(@as(u32, 0), h.current_step);
    try testing.expectEqual(@as(u32, 1), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(other).length);
}

test "holdAllViews holds every navigable the history has" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    h.holdAllViews();
    for ([_]u64{ top, frame, other }) |navigable| try testing.expect(h.isViewHeld(navigable));
    h.releaseAllViews();
    for ([_]u64{ top, frame, other }) |navigable| try testing.expect(!h.isViewHeld(navigable));
}

// Stated deviation (lane nav2 C2, integrator 2026-10-28): HTML queues
// "finalize a cross-document navigation" and a same-document navigation's
// finalize steps on the session history traversal queue, so a commit never
// runs inside an apply. Crane still commits both inline (E and F1 make them
// items), so a commit made while an apply runs settles it first - the step
// moves to the apply's target and the non-changing documents' views are
// released, as C1 had them - and the push lands after the target. When E or
// F1 lands, this test FLIPS: the commit is queued behind the apply and this
// settle path goes.
test "STATED DEVIATION until E/F1: a commit made while an apply runs settles it first" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try twoFrames(&h);
    const f0 = h.entryAt(frame, 0).?.id;

    h.beginApply(5, 0);
    h.setCurrentEntry(frame, f0);
    h.holdAllViews();
    // The other frame commits a cross-document push meanwhile.
    try h.commitDocument(other, "http://x.test/o1", null, "http://x.test", .push);
    // The apply was settled: step 0 (its target), then the push at step 1 -
    // which cleared the frame's f1 (forward of the target).
    try testing.expect(!h.isApplying(5));
    try testing.expectEqual(@as(u32, 1), h.current_step);
    try testing.expectEqualStrings("http://x.test/o1", h.currentEntry(other).?.url);
    try testing.expectEqual(f0, h.currentEntry(frame).?.id);
    try testing.expectEqual(@as(usize, 1), h.entryCount(frame));
    // The changing frame's view stays held until its target is active; the
    // non-changing ones were released and read the push.
    try testing.expect(h.isViewHeld(frame));
    try testing.expect(!h.isViewHeld(other));
    try testing.expectEqual(@as(u32, 1), h.historyView(other).index);
    // The apply's own step 20, later, does not move the step back.
    h.endApply(5);
    try testing.expectEqual(@as(u32, 1), h.current_step);
}
