//! A setlike object's set entries iterate live, as a JavaScript Set does
//! (WebIDL 3.7.12.2, "create a set iterator": the set's size and order
//! "might have changed while execution ... was paused"). An iterator is only
//! the sequence of the entry it yielded last (`after`), so these are the
//! cases of custom-elements/state/ElementInternals-states.html's "Updating a
//! CustomStateSet while iterating it should work" and of ECMAScript's Set
//! iterator: a deleted unvisited entry is skipped, a deleted visited entry
//! shifts nothing, appends are visited, and so are appends after empty().

const std = @import("std");
const testing = std.testing;
const webidl = @import("webidl");

const Strings = webidl.setlike.Strings;

fn next(set: *const Strings, cursor: *u64) ?[]const u8 {
    const entry = set.after(cursor.*) orelse return null;
    cursor.* = entry.sequence;
    return entry.value;
}

test "append keeps one copy of each value, in insertion order" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    var text = "--foo".*;
    try set.append(&text);
    try set.append("--bar");
    try set.append("--foo");
    text[2] = 'X'; // the set keeps its own copy
    try testing.expectEqual(@as(usize, 2), set.size());
    try testing.expect(set.contains("--foo"));
    try testing.expect(set.contains("--bar"));
    try testing.expect(!set.contains("--Xoo"));
    var values = set.values();
    try testing.expectEqualStrings("--foo", values.next().?);
    try testing.expectEqualStrings("--bar", values.next().?);
    try testing.expect(values.next() == null);
}

test "a deleted entry the iterator has not reached is skipped" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    try set.append("--one");
    try set.append("--two");
    try set.append("--three");
    var cursor: u64 = 0;
    try testing.expect(set.remove("--one"));
    try testing.expectEqualStrings("--two", next(&set, &cursor).?);
    // Emptied: the iterator is done.
    set.empty();
    try testing.expect(next(&set, &cursor) == null);
}

test "deleting an entry already visited moves nothing" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    try set.append("--one");
    try set.append("--two");
    try set.append("--three");
    var cursor: u64 = 0;
    try testing.expectEqualStrings("--one", next(&set, &cursor).?);
    try testing.expect(set.remove("--one"));
    try testing.expectEqualStrings("--two", next(&set, &cursor).?);
    try testing.expectEqualStrings("--three", next(&set, &cursor).?);
    try testing.expect(next(&set, &cursor) == null);
}

test "appends during iteration are visited; a re-added value goes to the end" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    try set.append("--a");
    try set.append("--b");
    var cursor: u64 = 0;
    try testing.expectEqualStrings("--a", next(&set, &cursor).?);
    try testing.expect(set.remove("--a"));
    try set.append("--a");
    try testing.expectEqualStrings("--b", next(&set, &cursor).?);
    try testing.expectEqualStrings("--a", next(&set, &cursor).?);
    try testing.expect(next(&set, &cursor) == null);
}

test "after empty(), what is appended next is visited" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    try set.append("--a");
    try set.append("--b");
    var cursor: u64 = 0;
    try testing.expectEqualStrings("--a", next(&set, &cursor).?);
    set.empty();
    try testing.expectEqual(@as(usize, 0), set.size());
    try set.append("--c");
    try testing.expectEqualStrings("--c", next(&set, &cursor).?);
    try testing.expect(next(&set, &cursor) == null);
}

test "remove answers whether the value was there" {
    var set = Strings.init(testing.allocator);
    defer set.deinit();
    try testing.expect(!set.remove("--a"));
    try set.append("--a");
    try testing.expect(set.remove("--a"));
    try testing.expect(!set.contains("--a"));
}

test "a scalar set compares by value" {
    var set = webidl.setlike.SetEntries(u32).init(testing.allocator);
    defer set.deinit();
    try set.append(3);
    try set.append(3);
    try set.append(1);
    try testing.expectEqual(@as(usize, 2), set.size());
    try testing.expectEqual(@as(u32, 3), set.after(0).?.value);
}
