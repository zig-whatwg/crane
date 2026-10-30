//! Lane nav2 H (fragment cost): every lookup of the joint session history
//! that H answers from an index - an entry by id, a navigable's entries, its
//! entry at a step, its pending chain, the used steps - gives what a scan of
//! the entry list gives, after every kind of change: entries appended,
//! pushed, replaced in place (a cross-document replace gives the entry a new
//! id), cleared forward, listed from pending (a replace moves the entry into
//! its replaced one's place), dropped, flushed by an inline cross-document
//! commit, and removed with their navigable.
//!
//! The scans here are the definitions; the history's own answers are what is
//! under test.

const std = @import("std");
const testing = std.testing;
const joint = @import("html_core").navigation.joint_history;

const top: u64 = 1;
const frame_a: u64 = 2;
const frame_b: u64 = 3;
const nested: u64 = 4;
const navigables = [_]u64{ top, frame_a, frame_b, nested };
const parents = [_]?u64{ null, top, top, frame_a };

fn scanById(h: *joint.JointHistory, id: u64) ?*joint.Entry {
    for (h.entries.items) |*entry| {
        if (entry.id == id) return entry;
    }
    return null;
}

fn scanByKey(h: *joint.JointHistory, navigable: u64, key: *const [36]u8) ?*joint.Entry {
    for (h.entries.items) |*entry| {
        if (entry.navigable == navigable and std.mem.eql(u8, &entry.api_key, key)) return entry;
    }
    return null;
}

fn scanEntryAt(h: *joint.JointHistory, navigable: u64, step: u32) ?*joint.Entry {
    var best: ?*joint.Entry = null;
    for (h.entries.items) |*entry| {
        if (entry.navigable != navigable or entry.pending or entry.step > step) continue;
        if (best == null or entry.step >= best.?.step) best = entry;
    }
    return best;
}

fn scanLastPending(h: *joint.JointHistory, navigable: u64) ?*joint.Entry {
    var i = h.entries.items.len;
    while (i > 0) {
        i -= 1;
        const entry = &h.entries.items[i];
        if (entry.pending and entry.navigable == navigable) return entry;
    }
    return null;
}

fn expectIndexesAgree(h: *joint.JointHistory) !void {
    // Every entry is found by its id, and ids are unique.
    for (h.entries.items) |*entry| {
        try testing.expectEqual(scanById(h, entry.id), h.entryById(entry.id));
        try testing.expectEqual(entry.pending, h.isPending(entry.id));
    }
    try testing.expect(h.entryById(0) == null);
    try testing.expect(h.entryById(h.next_id) == null);

    // The used steps: every listed step, sorted, once each.
    var used: std.ArrayListUnmanaged(u32) = .empty;
    defer used.deinit(testing.allocator);
    try h.usedSteps(testing.allocator, &used);
    var scanned: std.ArrayListUnmanaged(u32) = .empty;
    defer scanned.deinit(testing.allocator);
    for (h.entries.items) |entry| {
        if (entry.pending) continue;
        if (std.mem.indexOfScalar(u32, scanned.items, entry.step) == null) try scanned.append(testing.allocator, entry.step);
    }
    std.mem.sort(u32, scanned.items, {}, std.sort.asc(u32));
    try testing.expectEqualSlices(u32, scanned.items, used.items);

    for (navigables) |navigable| {
        var count: usize = 0;
        var listed = false;
        var pending = false;
        for (h.entries.items) |entry| {
            if (entry.navigable != navigable) continue;
            count += 1;
            if (entry.pending) pending = true else listed = true;
        }
        try testing.expectEqual(count, h.entryCount(navigable));
        try testing.expectEqual(listed, h.hasNavigable(navigable));
        try testing.expectEqual(pending, h.hasPending(navigable));
        // Its entry at each used step, and past the last.
        for (used.items) |step| try testing.expectEqual(scanEntryAt(h, navigable, step), h.entryAt(navigable, step));
        try testing.expectEqual(scanEntryAt(h, navigable, std.math.maxInt(u32)), h.entryAt(navigable, std.math.maxInt(u32)));
        // Its current entry for its document: the latest pending one first.
        const current = h.currentEntry(navigable);
        if (scanLastPending(h, navigable)) |last| try testing.expectEqual(@as(?*joint.Entry, last), current);
        // The navigation API's entries are its listed entries, by step.
        var api: std.ArrayListUnmanaged(*joint.Entry) = .empty;
        defer api.deinit(testing.allocator);
        _ = try h.apiEntries(navigable, testing.allocator, &api);
        for (api.items, 0..) |entry, i| {
            try testing.expectEqual(navigable, entry.navigable);
            try testing.expect(!entry.pending);
            if (i > 0) try testing.expect(api.items[i - 1].step <= entry.step);
            try testing.expectEqual(scanByKey(h, navigable, &entry.api_key), h.entryByKey(navigable, &entry.api_key));
        }
    }
}

/// One random change, the pending kinds included: everything
/// nav2_history_views_test's changes do, plus synchronous navigations (made
/// pending), their finalize (listed in FIFO order), and a traversal's drop.
fn randomChange(h: *joint.JointHistory, random: std.Random, pending: *std.ArrayListUnmanaged(joint.SameDocumentNavigation), owners: *std.ArrayListUnmanaged(u64)) !void {
    const pick = random.uintLessThan(usize, navigables.len);
    const navigable = navigables[pick];
    const origin: []const u8 = if (random.boolean()) "http://x.test" else "http://y.test";
    var url_buffer: [64]u8 = undefined;
    const url = try std.fmt.bufPrint(&url_buffer, "{s}/{d}", .{ origin, random.int(u16) });
    const handling: joint.HistoryHandling = if (random.uintLessThan(u8, 3) == 0) .replace else .push;
    switch (random.uintLessThan(u8, 12)) {
        0 => if (parents[pick]) |parent| {
            if (h.hasNavigable(parent)) try h.addChildInitialEntry(navigable, parent, "about:blank", null, origin);
        } else try h.addInitialEntry(navigable, url, null, origin),
        // A cross-document commit lists every pending entry first.
        1 => if (h.hasNavigable(navigable)) {
            try h.commitDocument(navigable, url, null, origin, handling);
            pending.clearRetainingCapacity();
            owners.clearRetainingCapacity();
        },
        2 => if (h.hasNavigable(navigable)) h.commitSameDocument(navigable, url, .null, handling, null) catch |err| switch (err) {
            error.NoCurrentEntry => {},
            else => return err,
        },
        3, 4 => if (h.hasNavigable(navigable)) {
            const nav = h.navigateSameDocument(navigable, url, .null, handling, null) catch |err| switch (err) {
                error.NoCurrentEntry => return,
                else => return err,
            };
            try pending.append(testing.allocator, nav);
            try owners.append(testing.allocator, navigable);
        },
        5, 6 => if (pending.items.len > 0) {
            const i = random.uintLessThan(usize, pending.items.len);
            const nav = pending.orderedRemove(i);
            const owner = owners.orderedRemove(i);
            _ = h.finalizeSameDocument(owner, nav.entry, nav.replaces);
        },
        7 => {
            h.dropPending(navigable);
        },
        8 => {
            var steps: std.ArrayListUnmanaged(u32) = .empty;
            defer steps.deinit(testing.allocator);
            try h.usedSteps(testing.allocator, &steps);
            if (steps.items.len > 0) h.setCurrentStep(steps.items[random.uintLessThan(usize, steps.items.len)]);
        },
        9 => h.clearForward(),
        10 => if (h.entries.items.len > 0) {
            const entry = h.entries.items[random.uintLessThan(usize, h.entries.items.len)];
            try h.keepActiveEntry(entry.navigable, entry.id);
        },
        else => if (navigable != top) {
            h.removeNavigable(navigable);
            h.setCurrentStep(h.usedStepAtOrBefore(h.current_step) orelse h.current_step);
        },
    }
}

test "the history's indexed lookups agree with a scan of its entries after every kind of change" {
    var seed: u64 = 1;
    while (seed <= 60) : (seed += 1) {
        var prng = std.Random.DefaultPrng.init(seed);
        var h = joint.JointHistory.init(testing.allocator);
        defer h.deinit();
        var pending: std.ArrayListUnmanaged(joint.SameDocumentNavigation) = .empty;
        defer pending.deinit(testing.allocator);
        var owners: std.ArrayListUnmanaged(u64) = .empty;
        defer owners.deinit(testing.allocator);
        try h.addInitialEntry(top, "http://x.test/0", null, "http://x.test");
        try expectIndexesAgree(&h);
        for (0..80) |_| {
            try randomChange(&h, prng.random(), &pending, &owners);
            try expectIndexesAgree(&h);
        }
    }
}

test "clearing a long forward history removes every entry past the current step in one pass, keeping the others in order" {
    var h = joint.JointHistory.init(testing.allocator);
    defer h.deinit();
    try h.addInitialEntry(top, "http://x.test/0", null, "http://x.test");
    try h.addChildInitialEntry(frame_a, top, "about:blank", null, "http://x.test");
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        var url_buffer: [64]u8 = undefined;
        const nav = if (i % 2 == 0) frame_a else top;
        try h.commitSameDocument(nav, try std.fmt.bufPrint(&url_buffer, "http://x.test/0#{d}", .{i}), .null, .push, null);
    }
    try testing.expectEqual(@as(u32, 201), h.lengthAndIndex().length);
    h.setCurrentStep(50);
    const kept_ids = blk: {
        var ids: std.ArrayListUnmanaged(u64) = .empty;
        for (h.entries.items) |entry| {
            if (entry.step <= 50) try ids.append(testing.allocator, entry.id);
        }
        break :blk ids;
    };
    var kept = kept_ids;
    defer kept.deinit(testing.allocator);
    h.clearForward();
    try testing.expectEqual(kept.items.len, h.entries.items.len);
    for (h.entries.items, kept.items) |entry, id| try testing.expectEqual(id, entry.id);
    try testing.expectEqual(@as(u32, 51), h.lengthAndIndex().length);
    try expectIndexesAgree(&h);
    // A push after it is the next step, with its navigable's entries found.
    try h.commitSameDocument(frame_a, "http://x.test/0#after", .null, .push, null);
    try testing.expectEqualStrings("http://x.test/0#after", h.entryAt(frame_a, 51).?.url);
    try expectIndexesAgree(&h);
}
