//! Lane nav2, piece D: each navigable's view of the session history
//! (joint_history View) - what its active document's History length and
//! index, navigation API entry list, current entry and entry indexes read -
//! is rewritten by every change of the history, so it always equals a live
//! read of the entries (lengthAndIndex, apiEntries, activeEntry). The spec's
//! moments replace that writer later; until then a view that differs from
//! the live read is a regression of what script sees.

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame_a: u64 = 2;
const frame_b: u64 = 3;
const nested: u64 = 4;
const navigables = [_]u64{ top, frame_a, frame_b, nested };
const parents = [_]?u64{ null, top, top, frame_a };

/// Every navigable's view equals the live read: History length and index,
/// the navigation API entry list (the same entries, in order) and its index,
/// the current entry, and each listed entry's index.
fn expectViewsLive(h: *joint.JointHistory) !void {
    const live_li = try liveLengthAndIndex(h);
    for (navigables) |navigable| {
        const view_li = h.historyView(navigable);
        try testing.expectEqual(live_li.length, view_li.length);
        try testing.expectEqual(live_li.index, view_li.index);

        var live: std.ArrayListUnmanaged(*joint.Entry) = .empty;
        defer live.deinit(testing.allocator);
        var view: std.ArrayListUnmanaged(*joint.Entry) = .empty;
        defer view.deinit(testing.allocator);
        const live_index = try h.apiEntries(navigable, testing.allocator, &live);
        const view_index = try h.apiView(navigable, testing.allocator, &view);
        try testing.expectEqual(live_index, view_index);
        try testing.expectEqualSlices(*joint.Entry, live.items, view.items);
        try testing.expectEqual(h.activeEntry(navigable), h.apiCurrentView(navigable));
        for (live.items, 0..) |entry, i| try testing.expectEqual(@as(?usize, i), h.apiIndexOf(navigable, entry.id, testing.allocator));
    }
}

/// `lengthAndIndex`, read with the test's allocator (the history's may be
/// failing).
fn liveLengthAndIndex(h: *joint.JointHistory) !joint.LengthAndIndex {
    var steps: std.ArrayListUnmanaged(u32) = .empty;
    defer steps.deinit(testing.allocator);
    try h.usedSteps(testing.allocator, &steps);
    if (steps.items.len == 0) return .{ .length = 1, .index = 0 };
    const index = std.mem.indexOfScalar(u32, steps.items, h.current_step) orelse steps.items.len - 1;
    return .{ .length = @intCast(steps.items.len), .index = @intCast(index) };
}

/// The used steps of `h`, for picking a traversal target.
fn usedSteps(h: *joint.JointHistory) !std.ArrayListUnmanaged(u32) {
    var steps: std.ArrayListUnmanaged(u32) = .empty;
    try h.usedSteps(testing.allocator, &steps);
    return steps;
}

/// One random change of `h`: an initial entry, a cross- or same-document
/// push or replace (of one of two origins), a traversal, a cleared forward
/// history, a kept active entry, a document given to a document state, or a
/// navigable removed.
fn randomChange(h: *joint.JointHistory, random: std.Random, documents: []u8) !void {
    const pick = random.uintLessThan(usize, navigables.len);
    const navigable = navigables[pick];
    const origin: []const u8 = if (random.boolean()) "http://x.test" else "http://y.test";
    var url_buffer: [64]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "{s}/{d}", .{ origin, random.int(u16) });
    const handling: joint.HistoryHandling = if (random.uintLessThan(u8, 3) == 0) .replace else .push;
    switch (random.uintLessThan(u8, 9)) {
        0 => if (parents[pick]) |parent| {
            if (h.hasNavigable(parent)) try h.addChildInitialEntry(navigable, parent, "about:blank", null, origin);
        } else try h.addInitialEntry(navigable, url, null, origin),
        1, 2 => if (h.hasNavigable(navigable)) try h.commitDocument(navigable, url, null, origin, handling),
        // A navigable with no entry at the current step (a traversal went
        // back past its first) has no document to push or replace on.
        3, 4 => if (h.hasNavigable(navigable)) h.commitSameDocument(navigable, url, .null, handling, null) catch |err| switch (err) {
            error.NoCurrentEntry => {},
            else => return err,
        },
        5 => {
            var steps = try usedSteps(h);
            defer steps.deinit(testing.allocator);
            if (steps.items.len > 0) h.setCurrentStep(steps.items[random.uintLessThan(usize, steps.items.len)]);
        },
        6 => if (random.boolean()) h.clearForward() else if (h.entries.items.len > 0) {
            const entry = h.entries.items[random.uintLessThan(usize, h.entries.items.len)];
            try h.keepActiveEntry(entry.navigable, entry.id);
        },
        7 => if (h.entries.items.len > 0) {
            const entry = h.entries.items[random.uintLessThan(usize, h.entries.items.len)];
            h.setDocumentOfState(entry.document_state, &documents[random.uintLessThan(usize, documents.len)]);
        },
        else => if (navigable != top) h.removeNavigable(navigable),
    }
}

test "every navigable's view is what a live read gives, after every kind of change" {
    var documents: [4]u8 = undefined;
    var seed: u64 = 1;
    while (seed <= 40) : (seed += 1) {
        var prng = std.Random.DefaultPrng.init(seed);
        var h = joint.JointHistory.init(testing.allocator);
        defer h.deinit();
        try h.addInitialEntry(top, "http://x.test/0", null, "http://x.test");
        try expectViewsLive(&h);
        for (0..60) |_| {
            try randomChange(&h, prng.random(), &documents);
            try expectViewsLive(&h);
        }
    }
}

test "a view reads the history it was last written for: a push in one navigable, a traversal of all" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addChildInitialEntry(frame_a, top, "about:blank", null, "http://x.test");
    try testing.expectEqual(@as(u32, 1), h.historyView(top).length);
    try testing.expectEqual(@as(u32, 1), h.historyView(frame_a).length);

    // The frame pushes: both documents read length 2, index 1; the frame's
    // list has two entries, the top's one.
    try h.commitSameDocument(frame_a, "about:blank#2", .null, .push, null);
    for ([_]u64{ top, frame_a }) |navigable| {
        try testing.expectEqual(@as(u32, 2), h.historyView(navigable).length);
        try testing.expectEqual(@as(u32, 1), h.historyView(navigable).index);
    }
    var list: std.ArrayListUnmanaged(*joint.Entry) = .empty;
    defer list.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 1), try h.apiView(frame_a, testing.allocator, &list));
    try testing.expectEqual(@as(usize, 2), list.items.len);
    try testing.expectEqual(@as(usize, 0), try h.apiView(top, testing.allocator, &list));
    try testing.expectEqual(@as(usize, 1), list.items.len);

    // A traversal back: index 0 for both, the frame's current entry its first.
    const first = h.entryAt(frame_a, 0).?.id;
    h.setCurrentStep(h.stepByDelta(-1).?);
    try testing.expectEqual(@as(u32, 0), h.historyView(top).index);
    try testing.expectEqual(@as(u32, 0), h.historyView(frame_a).index);
    try testing.expectEqual(first, h.apiCurrentView(frame_a).?.id);
    try testing.expectEqual(@as(?usize, 0), h.apiIndexOf(frame_a, first, testing.allocator));
}

test "a removed navigable's view goes with it" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addChildInitialEntry(frame_a, top, "about:blank", null, "http://x.test");
    try h.commitDocument(frame_a, "http://x.test/f", null, "http://x.test", .push);
    try testing.expect(h.views.contains(frame_a));
    h.removeNavigable(frame_a);
    try testing.expect(!h.views.contains(frame_a));
    try testing.expect(h.apiCurrentView(frame_a) == null);
    try expectViewsLive(&h);
}

test "views that could not be written are read from the entries until a write succeeds" {
    // Every allocation index of a fixed script of changes fails once: each
    // change either happens or not, and after it every reader gives what a
    // live read gives; once allocations succeed again, the next change
    // writes every view.
    var fail_index: usize = 0;
    var failed_any = true;
    while (failed_any) : (fail_index += 1) {
        var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = fail_index });
        var h = joint.JointHistory.init(failing.allocator());
        defer h.deinit();
        script: {
            h.addInitialEntry(top, "http://x.test/0", null, "http://x.test") catch break :script;
            h.addChildInitialEntry(frame_a, top, "about:blank", null, "http://x.test") catch break :script;
            h.commitDocument(frame_a, "http://x.test/f1", null, "http://x.test", .push) catch break :script;
            h.commitSameDocument(top, "http://x.test/0#a", .null, .push, null) catch break :script;
            h.commitDocument(top, "http://y.test/1", null, "http://y.test", .replace) catch break :script;
            h.setCurrentStep(h.stepByDelta(-1) orelse 0);
            h.keepActiveEntry(frame_a, h.entryAt(frame_a, 0).?.id) catch break :script;
        }
        failed_any = failing.has_induced_failure;
        try expectViewsLive(&h);
        failing.fail_index = std.math.maxInt(usize);
        h.setCurrentStep(h.current_step);
        try testing.expect(h.views_valid);
        try expectViewsLive(&h);
    }
    try testing.expect(fail_index > 10);
}

test "a held view keeps what its document read until it is released (a traversal's changing navigable)" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/t", null, "http://x.test");
    try h.addChildInitialEntry(frame_a, top, "http://x.test/f0", null, "http://x.test");
    try h.commitDocument(frame_a, "http://x.test/f1", null, "http://x.test", .push);
    const f1 = h.apiCurrentView(frame_a).?.id;
    const f0 = h.entryAt(frame_a, 0).?.id;

    // A traversal back holds the frame's view, then moves the step: the
    // frame's document still reads f1 as current; the top's view moves.
    h.holdView(frame_a);
    h.setCurrentStep(h.stepByDelta(-1).?);
    try testing.expectEqual(f1, h.apiCurrentView(frame_a).?.id);
    try testing.expectEqual(@as(?usize, 1), h.apiIndexOf(frame_a, f1, testing.allocator));
    try testing.expectEqual(@as(u32, 1), h.historyView(frame_a).index);
    try testing.expectEqual(@as(u32, 0), h.historyView(top).index);
    // Other changes meanwhile leave it held.
    try h.commitSameDocument(top, "http://x.test/t#a", .null, .replace, null);
    try testing.expectEqual(f1, h.apiCurrentView(frame_a).?.id);

    // The target document is active: the view is the live one again.
    h.releaseView(frame_a);
    try testing.expectEqual(f0, h.apiCurrentView(frame_a).?.id);
    try expectViewsLive(&h);

    // releaseAllViews, and a removed navigable's hold, end holds too.
    h.holdView(frame_a);
    h.holdView(top);
    h.setCurrentStep(h.stepByDelta(1).?);
    try testing.expectEqual(f0, h.apiCurrentView(frame_a).?.id);
    h.releaseAllViews();
    try expectViewsLive(&h);
    h.holdView(frame_a);
    h.removeNavigable(frame_a);
    try testing.expect(!h.isViewHeld(frame_a));
    try expectViewsLive(&h);
}
