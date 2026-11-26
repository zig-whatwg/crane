//! WebIDL 2.5.11 & 3.7.11: a maplike object's map entries iterate live, as a
//! JavaScript Map does (3.7.11.2: the map's size and order "might have changed
//! while execution ... was paused"). An iterator keeps only the sequence of
//! the entry it yielded last (`after`):
//! - updating an existing key preserves its position and sequence;
//! - deleting an unvisited entry skips it;
//! - deleting a visited entry shifts nothing;
//! - deleting and re-adding a key moves it to the end so it is visited;
//! - clear() keeps the sequence counter so entries set afterwards are visited.

const std = @import("std");
const testing = std.testing;
const webidl = @import("webidl");

fn nextEntry(map: anytype, cursor: *u64) ?@TypeOf(map.after(0).?) {
    const entry = map.after(cursor.*) orelse return null;
    cursor.* = entry.sequence;
    return entry;
}

test "MapEntries string->string owns copies and preserves order on update" {
    var map = webidl.maplike.MapEntries([]const u8, []const u8).init(testing.allocator);
    defer map.deinit();

    var k1 = "KeyA".*;
    var v1 = "a".*;
    try map.set(&k1, &v1);
    try map.set("KeyB", "b");
    k1[3] = 'Z';
    v1[0] = 'Z';

    try testing.expectEqual(@as(usize, 2), map.size());
    try testing.expect(map.contains("KeyA"));
    try testing.expectEqualStrings("a", map.get("KeyA").?);
    try testing.expect(!map.contains("KeyZ"));

    // Updating an existing key preserves its position and sequence.
    const seq_before = map.after(0).?.sequence;
    try map.set("KeyA", "alpha");
    try testing.expectEqual(@as(usize, 2), map.size());
    try testing.expectEqualStrings("alpha", map.get("KeyA").?);

    var cursor: u64 = 0;
    const first = nextEntry(&map, &cursor).?;
    try testing.expectEqual(seq_before, first.sequence);
    try testing.expectEqualStrings("KeyA", first.key);
    try testing.expectEqualStrings("alpha", first.value);
    const second = nextEntry(&map, &cursor).?;
    try testing.expectEqualStrings("KeyB", second.key);
    try testing.expectEqualStrings("b", second.value);
    try testing.expect(nextEntry(&map, &cursor) == null);
}

test "MapEntries live iteration across delete, re-add, update, and clear" {
    var map = webidl.maplike.MapEntries([]const u8, u64).init(testing.allocator);
    defer map.deinit();

    try map.set("click", 1);
    try map.set("keydown", 2);
    try map.set("keyup", 3);

    var cursor: u64 = 0;
    // Visit "click"
    const e1 = nextEntry(&map, &cursor).?;
    try testing.expectEqualStrings("click", e1.key);
    try testing.expectEqual(@as(u64, 1), e1.value);

    // Update visited "click" -> must NOT be re-yielded
    try map.set("click", 10);
    // Delete unvisited "keydown" -> skipped
    try testing.expect(map.remove("keydown"));
    try testing.expect(!map.remove("keydown"));

    // Visit "keyup"
    const e2 = nextEntry(&map, &cursor).?;
    try testing.expectEqualStrings("keyup", e2.key);
    try testing.expectEqual(@as(u64, 3), e2.value);

    // Delete visited "click" and re-add -> goes to end and IS visited
    try testing.expect(map.remove("click"));
    try map.set("click", 99);
    const e3 = nextEntry(&map, &cursor).?;
    try testing.expectEqualStrings("click", e3.key);
    try testing.expectEqual(@as(u64, 99), e3.value);

    // Clear and add new entry -> visited by the same suspended cursor
    map.clear();
    try testing.expectEqual(@as(usize, 0), map.size());
    try map.set("pointerdown", 7);
    const e4 = nextEntry(&map, &cursor).?;
    try testing.expectEqualStrings("pointerdown", e4.key);
    try testing.expectEqual(@as(u64, 7), e4.value);
    try testing.expect(nextEntry(&map, &cursor) == null);
}

test "MapEntries numeric keys (unsigned short) compare by value" {
    var map = webidl.maplike.MapEntries(u16, u32).init(testing.allocator);
    defer map.deinit();

    try map.set(0x004c, 100);
    try map.set(0x00e0, 200);
    try map.set(0x004c, 150);

    try testing.expectEqual(@as(usize, 2), map.size());
    try testing.expectEqual(@as(?u32, 150), map.get(0x004c));
    try testing.expectEqual(@as(?u32, 200), map.get(0x00e0));
    try testing.expectEqual(@as(?u32, null), map.get(0x0001));
    try testing.expect(map.remove(0x004c));
    try testing.expectEqual(@as(usize, 1), map.size());
}

test "View generalizes PlatformObjects and supports empty readonly views" {
    try testing.expectEqual(webidl.maplike.View([]const u8, *anyopaque), webidl.maplike.PlatformObjects);

    var empty_map = webidl.maplike.View(u16, *anyopaque).initEmpty();
    try testing.expectEqual(@as(usize, 0), empty_map.size());
    try testing.expectEqual(@as(?*anyopaque, null), empty_map.get(42));
    try testing.expect(!empty_map.contains(42));
    try testing.expect(empty_map.after(0) == null);
    try testing.expect(!empty_map.remove(42));
    empty_map.clear();

    var empty_set = webidl.setlike.PlatformObjects.initEmpty();
    try testing.expectEqual(@as(usize, 0), empty_set.size());
    try testing.expect(empty_set.after(0) == null);
    try testing.expect(!empty_set.remove(&empty_set));
    empty_set.empty();
}
