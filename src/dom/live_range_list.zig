//! A document's live ranges (DOM 5.5 "live range": its node document's list,
//! which the mutation algorithms update) and its NodeIterators (DOM 6.1, the
//! "NodeIterator pre-removing steps"): lists of objects the engine collects,
//! walked by steps that call into the engine.
//!
//! A walk's step calls into the engine - a live range's "set its start"
//! redraws the edge that keeps its start node (engine.traceChild), a
//! NodeIterator's new reference likewise - and an engine call that allocates
//! can start a collection. V8 runs every pending second pass in the prologue
//! of a collection ("Ensure that all pending phantom callbacks are invoked",
//! Heap::CollectGarbage, src/heap/heap.cc), so the teardowns of the ranges
//! script let go of since the previous collection run there: inside the
//! walk, each removing its range from the list being walked. A walk that held
//! a slice of the list read the slot a removal vacated, which
//! `orderedRemove` fills with undefined - SIGSEGV at 0xaaaaaaaaaaaaaaaa in
//! the live-range pre-remove steps (lane rangeuaf: Codex row 73's
//! sl2-cost-selection.html; 21,843 of 37,733 ranges left during one walk).
//!
//! So a walk never holds a slice. It reads one entry at a time through a
//! cursor, and `remove` moves the cursor of every walk in progress past which
//! the removed entry sat: Gecko's nsTObserverArray (xpcom/ds/nsTObserverArray.h,
//! `nsAutoTObserverArray::RemoveElementAt` -> `AdjustIterators(aIndex, -1)`,
//! a forward iterator's `mPosition` being the index of the next element),
//! which Gecko keeps its mutation observers - nsRange among them - in for the
//! same reason. Every entry still on the list is visited once, whatever left
//! before or after the cursor, and none twice; an entry added during a walk
//! is visited too (Gecko's ForwardIterator; nothing adds one during these
//! walks). Blink's Document::DidMoveTreeToNewDocument copies its ranges_
//! before a step that edits it; a copy here would hold entries a teardown
//! frees.
//!
//! A walk does not keep the entry it is on: a teardown during that entry's
//! own step would free it under the step. That is the engine's to prevent
//! (lane rangeuaf, part 2), not the list's.

const std = @import("std");

/// The list of `T`s (an object pointer) that its owner adds to, removes from
/// and walks; `remove` may run during a walk - one in progress on this list,
/// and any walk nested in it.
pub fn LiveList(comptime T: type) type {
    return struct {
        const Self = @This();

        /// In the order they were added: a document's live ranges in the
        /// order they joined it.
        entries: std.ArrayListUnmanaged(T) = .empty,
        /// The walks in progress on this list, innermost first. Each lives
        /// on its walker's stack, between `beginWalk` and `endWalk`.
        walks: ?*Walk = null,

        pub const empty: Self = .{};

        /// One pass over the list. `next` is the index of the entry the next
        /// call to `nextEntry` returns, as nsTObserverArray's mPosition.
        pub const Walk = struct {
            list: *Self,
            next: usize,
            outer: ?*Walk,

            /// The next entry still on the list, or null at its end.
            pub fn nextEntry(self: *Walk) ?T {
                const items = self.list.entries.items;
                if (self.next >= items.len) return null;
                const entry = items[self.next];
                self.next += 1;
                return entry;
            }
        };

        /// Every walk has ended (the owner's teardown).
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            std.debug.assert(self.walks == null);
            self.entries.deinit(allocator);
            self.* = .empty;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.entries.items.len == 0;
        }

        pub fn count(self: *const Self) usize {
            return self.entries.items.len;
        }

        /// Add `entry` at the end. A walk in progress visits it.
        pub fn add(self: *Self, allocator: std.mem.Allocator, entry: T) std.mem.Allocator.Error!void {
            try self.entries.append(allocator, entry);
        }

        /// Remove `entry`, if it is on the list - its owner's teardown, or a
        /// live range moving to another document. Every walk in progress
        /// still visits each entry it had not reached, once.
        pub fn remove(self: *Self, entry: T) void {
            const index = std.mem.indexOfScalar(T, self.entries.items, entry) orelse return;
            _ = self.entries.orderedRemove(index);
            // AdjustIterators(index, -1): an entry before a walk's next one
            // has gone, so its next one moved down a slot.
            var walk = self.walks;
            while (walk) |w| : (walk = w.outer) {
                if (index < w.next) w.next -= 1;
            }
        }

        pub fn contains(self: *const Self, entry: T) bool {
            return std.mem.indexOfScalar(T, self.entries.items, entry) != null;
        }

        /// Start a walk; `walk` stays where it is until `endWalk(walk)`.
        ///
        /// ```zig
        /// var walk: List.Walk = undefined;
        /// list.beginWalk(&walk);
        /// defer list.endWalk(&walk);
        /// while (walk.nextEntry()) |entry| { ... }
        /// ```
        pub fn beginWalk(self: *Self, walk: *Walk) void {
            walk.* = .{ .list = self, .next = 0, .outer = self.walks };
            self.walks = walk;
        }

        /// End `walk`, the innermost walk in progress (walks nest).
        pub fn endWalk(self: *Self, walk: *Walk) void {
            std.debug.assert(self.walks == walk);
            self.walks = walk.outer;
        }
    };
}

// =============================================================================
// Tests: entries removed while a walk is in progress
// =============================================================================

const testing = std.testing;
const List = LiveList(*const u8);

/// Ten distinct entries.
const pool = [10]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

fn filled(n: usize) !List {
    var list: List = .empty;
    for (pool[0..n]) |*e| try list.add(testing.allocator, e);
    return list;
}

fn at(i: usize) *const u8 {
    return &pool[i];
}

/// Walk the list; at each entry visited, `step` may remove entries. Returns
/// the entries visited, in order.
fn walkRemoving(list: *List, visited: *std.ArrayListUnmanaged(u8), comptime step: fn (list: *List, current: *const u8) void) !void {
    var walk: List.Walk = undefined;
    list.beginWalk(&walk);
    defer list.endWalk(&walk);
    while (walk.nextEntry()) |current| {
        try visited.append(testing.allocator, current.*);
        step(list, current);
    }
}

fn expectVisited(visited: []const u8, expected: []const u8) !void {
    try testing.expectEqualSlices(u8, expected, visited);
}

test "a walk with no removal visits every entry once, in order" {
    var list = try filled(5);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    try walkRemoving(&list, &visited, struct {
        fn step(_: *List, _: *const u8) void {}
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 3, 4 });
}

test "removing the current entry visits the one after it next" {
    var list = try filled(5);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* == 2) l.remove(current);
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 3, 4 });
    try testing.expectEqual(@as(usize, 4), list.count());
    try testing.expect(!list.contains(at(2)));
}

test "removing entries before the cursor skips nothing and repeats nothing" {
    var list = try filled(8);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    // At 5: the previous entry (adjacent) and the first two go - the shape
    // of a collection's teardowns, which free ranges already walked.
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* != 5) return;
            l.remove(at(4));
            l.remove(at(0));
            l.remove(at(1));
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 3, 4, 5, 6, 7 });
    try testing.expectEqual(@as(usize, 5), list.count());
}

test "removing entries after the cursor: the walk never reaches them" {
    var list = try filled(8);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    // At 2: the next entry (adjacent) and the last go.
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* != 2) return;
            l.remove(at(3));
            l.remove(at(7));
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 4, 5, 6 });
}

test "removing entries on both sides of the cursor and the current one" {
    var list = try filled(10);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    // At 4: entries already visited (0, 1, 3), the current one, the next one
    // (adjacent) and a later one (8) go, in no particular order. Each entry
    // still on the list is visited exactly once.
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* != 4) return;
            for ([_]usize{ 0, 3, 4, 5, 8, 1 }) |i| l.remove(at(i));
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 3, 4, 6, 7, 9 });
    try testing.expectEqual(@as(usize, 4), list.count());
}

test "removing every entry ends the walk" {
    var list = try filled(6);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* != 1) return;
            for (pool[0..6]) |*e| l.remove(e);
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1 });
    try testing.expect(list.isEmpty());
}

test "an entry added during a walk is visited; removing one not on the list changes nothing" {
    var list = try filled(3);
    defer list.deinit(testing.allocator);
    var visited: std.ArrayListUnmanaged(u8) = .empty;
    defer visited.deinit(testing.allocator);
    try walkRemoving(&list, &visited, struct {
        fn step(l: *List, current: *const u8) void {
            if (current.* != 1) return;
            l.remove(at(9));
            l.add(testing.allocator, at(9)) catch unreachable;
        }
    }.step);
    try expectVisited(visited.items, &.{ 0, 1, 2, 9 });
}

test "a nested walk and the walk around it both stay whole when entries go" {
    var list = try filled(6);
    defer list.deinit(testing.allocator);
    var outer_seen: std.ArrayListUnmanaged(u8) = .empty;
    defer outer_seen.deinit(testing.allocator);
    var inner_seen: std.ArrayListUnmanaged(u8) = .empty;
    defer inner_seen.deinit(testing.allocator);

    var outer: List.Walk = undefined;
    list.beginWalk(&outer);
    defer list.endWalk(&outer);
    while (outer.nextEntry()) |current| {
        try outer_seen.append(testing.allocator, current.*);
        if (current.* != 2) continue;
        // A step of entry 2 walks the list again; at 4 of that inner walk,
        // 1, 2 (the outer walk's current) and 5 go.
        var inner: List.Walk = undefined;
        list.beginWalk(&inner);
        defer list.endWalk(&inner);
        while (inner.nextEntry()) |e| {
            try inner_seen.append(testing.allocator, e.*);
            if (e.* == 4) {
                list.remove(at(1));
                list.remove(at(2));
                list.remove(at(5));
            }
        }
    }
    try expectVisited(inner_seen.items, &.{ 0, 1, 2, 3, 4 });
    try expectVisited(outer_seen.items, &.{ 0, 1, 2, 3, 4 });
    try testing.expectEqual(@as(usize, 3), list.count());
}
