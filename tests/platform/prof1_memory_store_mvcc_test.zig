//! kit/memory_store as a multi-version store (docs/platform-protocol.md
//! 6.6; lane prof1, the integrator's plan 2026-11-21 8:17 PM ET): a read
//! transaction's snapshot is a commit sequence number - no copy of the
//! table - and it keeps seeing the store as of its begin while writers
//! commit; a write transaction sees its own changes over its snapshot, and
//! an abort leaves nothing; cursors walk the merged view in key order in
//! both directions, past changes made under them; versions no snapshot can
//! see are dropped; and the one-writer rule holds. A Browser with no
//! profile directory keeps its stores here.
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

fn bytes(text: []const u8) platform.Bytes {
    return platform.Bytes.from(text);
}

fn openBrowser() !*platform.BrowserPlatform {
    return platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
}

fn put(store: *platform.Store, key: []const u8, value: []const u8) !void {
    const txn = try platform.beginTransaction(store, .write);
    errdefer platform.abortTransaction(txn);
    try platform.storePut(txn, bytes(key), bytes(value));
    try platform.commitTransaction(txn);
}

fn expectValue(txn: *platform.StoreTransaction, key: []const u8, want: ?[]const u8) !void {
    const got = try platform.storeGet(txn, testing.allocator, bytes(key));
    defer if (got) |value| testing.allocator.free(value);
    if (want) |value| {
        try testing.expectEqualStrings(value, got orelse return error.TestExpectedValue);
    } else try testing.expect(got == null);
}

fn expectKeys(txn: *platform.StoreTransaction, range: platform.KeyRange, direction: platform.CursorDirection, want: []const []const u8) !void {
    const cursor = try platform.openCursor(txn, range, direction);
    defer platform.closeCursor(cursor);
    for (want) |key| {
        const kv = (try platform.cursorNext(cursor, testing.allocator)) orelse return error.TestCursorEndedEarly;
        defer testing.allocator.free(kv.key.slice());
        defer testing.allocator.free(kv.value.slice());
        try testing.expectEqualStrings(key, kv.key.slice());
    }
    try testing.expect((try platform.cursorNext(cursor, testing.allocator)) == null);
}

test "a reader keeps its snapshot while a writer commits, and sees nothing of an aborted write" {
    const browser = try openBrowser();
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("mvcc"), .{});
    defer platform.closeStore(store);
    try put(store, "a", "1");
    try put(store, "b", "1");

    const reader = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(reader);
    {
        const writer = try platform.beginTransaction(store, .write);
        // One writer at a time.
        try testing.expectError(error.Conflict, platform.beginTransaction(store, .write));
        try platform.storePut(writer, bytes("a"), bytes("2"));
        try platform.storeDelete(writer, bytes("b"));
        try platform.storePut(writer, bytes("c"), bytes("2"));
        // The writer sees its own changes over its snapshot.
        try expectValue(writer, "a", "2");
        try expectValue(writer, "b", null);
        try expectKeys(writer, .all, .forward, &.{ "a", "c" });
        try expectKeys(writer, .all, .reverse, &.{ "c", "a" });
        try platform.commitTransaction(writer);
    }
    // The reader still sees the store as of its begin.
    try expectValue(reader, "a", "1");
    try expectValue(reader, "b", "1");
    try expectValue(reader, "c", null);
    try expectKeys(reader, .all, .forward, &.{ "a", "b" });

    {
        const aborted = try platform.beginTransaction(store, .write);
        try platform.storePut(aborted, bytes("d"), bytes("never"));
        try platform.storeDeleteRange(aborted, .all);
        platform.abortTransaction(aborted);
    }
    const after = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(after);
    try expectValue(after, "a", "2");
    try expectValue(after, "d", null);
    try expectKeys(after, .all, .forward, &.{ "a", "c" });
    // Only what the latest commit holds counts toward the size.
    try testing.expectEqual(@as(u64, 4), try platform.storeSize(store));
}

test "a cursor walks its snapshot in order, over ranges, while commits insert and delete under it" {
    const browser = try openBrowser();
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("cursor"), .{});
    defer platform.closeStore(store);
    for ([_][]const u8{ "b", "d", "f", "h" }) |key| try put(store, key, key);

    const reader = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(reader);
    const cursor = try platform.openCursor(reader, .{ .lower = bytes("c"), .has_lower = true, .upper = bytes("h"), .has_upper = true, .upper_open = true }, .forward);
    defer platform.closeCursor(cursor);
    const first = (try platform.cursorNext(cursor, testing.allocator)).?;
    defer testing.allocator.free(first.key.slice());
    defer testing.allocator.free(first.value.slice());
    try testing.expectEqualStrings("d", first.key.slice());
    // Commits under the cursor: keys before and after its place, a delete.
    {
        const writer = try platform.beginTransaction(store, .write);
        try platform.storePut(writer, bytes("a"), bytes("new"));
        try platform.storePut(writer, bytes("e"), bytes("new"));
        try platform.storeDelete(writer, bytes("f"));
        try platform.commitTransaction(writer);
    }
    const second = (try platform.cursorNext(cursor, testing.allocator)).?;
    defer testing.allocator.free(second.key.slice());
    defer testing.allocator.free(second.value.slice());
    try testing.expectEqualStrings("f", second.key.slice());
    try testing.expect((try platform.cursorNext(cursor, testing.allocator)) == null);

    const now = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(now);
    try expectKeys(now, .all, .forward, &.{ "a", "b", "d", "e", "h" });
    try expectKeys(now, .{ .lower = bytes("b"), .has_lower = true, .lower_open = true, .upper = bytes("h"), .has_upper = true }, .reverse, &.{ "h", "e", "d" });
}

test "a write transaction's range delete covers its own changes and the snapshot's keys" {
    const browser = try openBrowser();
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("ranges"), .{});
    defer platform.closeStore(store);
    for ([_][]const u8{ "k1", "k2", "k3", "z" }) |key| try put(store, key, "v");
    const writer = try platform.beginTransaction(store, .write);
    try platform.storePut(writer, bytes("k25"), bytes("mine"));
    try platform.storeDeleteRange(writer, .{ .lower = bytes("k2"), .has_lower = true, .upper = bytes("k3"), .has_upper = true });
    try platform.storePut(writer, bytes("k2"), bytes("again"));
    try expectKeys(writer, .all, .forward, &.{ "k1", "k2", "z" });
    try platform.commitTransaction(writer);
    const reader = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(reader);
    try expectKeys(reader, .all, .forward, &.{ "k1", "k2", "z" });
    try expectValue(reader, "k2", "again");
}

test "versions no snapshot can see are dropped once the reader that saw them ends" {
    const browser = try openBrowser();
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("versions"), .{});
    defer platform.closeStore(store);
    try put(store, "k", "0");
    const reader = try platform.beginTransaction(store, .read);
    var buffer: [8]u8 = undefined;
    for (1..50) |i| try put(store, "k", try std.fmt.bufPrint(&buffer, "{d}", .{i}));
    try expectValue(reader, "k", "0");
    platform.abortTransaction(reader);
    // The next commit to the key keeps only what a live snapshot can see;
    // std.testing.allocator fails the test on anything left at the end.
    try put(store, "k", "last");
    const after = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(after);
    try expectValue(after, "k", "last");
}

const Invariant = struct {
    store: *platform.Store,
    failures: std.atomic.Value(u32) = .init(0),
    stop: std.atomic.Value(bool) = .init(false),

    /// Moves one unit from "a" to "b" per commit: a + b stays 100.
    fn writer(self: *Invariant) void {
        for (0..200) |i| {
            const txn = platform.beginTransaction(self.store, .write) catch {
                _ = self.failures.fetchAdd(1, .monotonic);
                continue;
            };
            var a_buf: [8]u8 = undefined;
            var b_buf: [8]u8 = undefined;
            const a = std.fmt.bufPrint(&a_buf, "{d}", .{100 - (i % 100)}) catch unreachable;
            const b = std.fmt.bufPrint(&b_buf, "{d}", .{i % 100}) catch unreachable;
            platform.storePut(txn, bytes("a"), bytes(a)) catch {};
            platform.storePut(txn, bytes("b"), bytes(b)) catch {};
            platform.commitTransaction(txn) catch {
                _ = self.failures.fetchAdd(1, .monotonic);
            };
        }
        self.stop.store(true, .release);
    }

    fn reader(self: *Invariant) void {
        while (!self.stop.load(.acquire)) {
            const txn = platform.beginTransaction(self.store, .read) catch continue;
            defer platform.abortTransaction(txn);
            const a = platform.storeGet(txn, std.heap.page_allocator, bytes("a")) catch null;
            defer if (a) |value| std.heap.page_allocator.free(value);
            const b = platform.storeGet(txn, std.heap.page_allocator, bytes("b")) catch null;
            defer if (b) |value| std.heap.page_allocator.free(value);
            const sum = (std.fmt.parseInt(u32, a orelse "0", 10) catch 0) + (std.fmt.parseInt(u32, b orelse "0", 10) catch 0);
            if (sum != 100) _ = self.failures.fetchAdd(1, .monotonic);
        }
    }
};

test "readers on other threads see whole commits only" {
    const browser = try openBrowser();
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("threads"), .{});
    defer platform.closeStore(store);
    try put(store, "a", "100");
    try put(store, "b", "0");
    var state: Invariant = .{ .store = store };
    const readers = [_]std.Thread{
        try std.Thread.spawn(.{}, Invariant.reader, .{&state}),
        try std.Thread.spawn(.{}, Invariant.reader, .{&state}),
    };
    const writer = try std.Thread.spawn(.{}, Invariant.writer, .{&state});
    writer.join();
    for (readers) |thread| thread.join();
    try testing.expectEqual(@as(u32, 0), state.failures.load(.monotonic));
}
