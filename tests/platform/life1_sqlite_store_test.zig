//! kit/sqlite through the platform protocol (docs/platform-protocol.md 6.6;
//! the user's ruling 2026-11-21: SQLite on every platform with a profile
//! directory): a Browser given a profile directory keeps its stores there,
//! so a second Browser on the same directory, after the first ended, reads
//! what the first committed; keys order as unsigned bytes in both cursor
//! directions and over ranges; a read transaction keeps its snapshot; one
//! writer at a time; deleteStore removes a store; and the directory is the
//! live Browser's alone (error.Busy for a second). A Browser with no profile
//! directory keeps kit/memory_store, unchanged.
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

/// A profile directory under a test's temporary directory. OWNED path.
fn profilePath(tmp: *std.testing.TmpDir) ![]u8 {
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    return std.fs.path.join(testing.allocator, &.{ base, "profile" });
}

fn openBrowser(profile: []const u8) !*platform.BrowserPlatform {
    return platform.createBrowserPlatform(testing.allocator, &.{ .profile_dir = platform.Str.from(profile) }, no_events);
}

fn put(store: *platform.Store, key: []const u8, value: []const u8) !void {
    const txn = try platform.beginTransaction(store, .write);
    errdefer platform.abortTransaction(txn);
    try platform.storePut(txn, bytes(key), bytes(value));
    try platform.commitTransaction(txn);
}

fn get(store: *platform.Store, key: []const u8) !?[]u8 {
    const txn = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(txn);
    return platform.storeGet(txn, testing.allocator, bytes(key));
}

test "what a Browser commits under its profile directory is read by the next Browser on it" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const browser = try openBrowser(profile);
        defer platform.destroyBrowserPlatform(browser);
        const store = try platform.openStore(browser, platform.Str.from("local_storage"), .{});
        defer platform.closeStore(store);
        try put(store, "a", "first");
        try put(store, "b", "");
        // An aborted write leaves nothing.
        const txn = try platform.beginTransaction(store, .write);
        try platform.storePut(txn, bytes("c"), bytes("never"));
        platform.abortTransaction(txn);
    }
    const browser = try openBrowser(profile);
    defer platform.destroyBrowserPlatform(browser);
    // Not created: the store is there from the first Browser.
    const store = try platform.openStore(browser, platform.Str.from("local_storage"), .{ .create = false });
    defer platform.closeStore(store);
    const a = (try get(store, "a")) orelse return error.TestExpectedValue;
    defer testing.allocator.free(a);
    try testing.expectEqualStrings("first", a);
    const b = (try get(store, "b")) orelse return error.TestExpectedValue;
    defer testing.allocator.free(b);
    try testing.expectEqualStrings("", b);
    try testing.expect((try get(store, "c")) == null);
    try testing.expect(try platform.storeSize(store) > 0);
    // A store no Browser made is NotFound without create.
    try testing.expectError(error.NotFound, platform.openStore(browser, platform.Str.from("never_made"), .{ .create = false }));
}

test "keys order as unsigned bytes, forward and reverse, over ranges" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openBrowser(profile);
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("ordered"), .{});
    defer platform.closeStore(store);
    // Inserted out of order; 0xff sorts after 'z', the empty key first, a
    // prefix before its extensions.
    for ([_][]const u8{ "b", "\xff", "", "ab", "a", "z" }) |key| try put(store, key, key);

    const txn = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(txn);
    const expectKeys = struct {
        fn run(t: *platform.StoreTransaction, range: platform.KeyRange, direction: platform.CursorDirection, want: []const []const u8) !void {
            const cursor = try platform.openCursor(t, range, direction);
            defer platform.closeCursor(cursor);
            for (want) |key| {
                const kv = (try platform.cursorNext(cursor, testing.allocator)) orelse return error.TestCursorEndedEarly;
                defer testing.allocator.free(kv.key.slice());
                defer testing.allocator.free(kv.value.slice());
                try testing.expectEqualSlices(u8, key, kv.key.slice());
            }
            try testing.expect((try platform.cursorNext(cursor, testing.allocator)) == null);
        }
    }.run;
    try expectKeys(txn, .{}, .forward, &.{ "", "a", "ab", "b", "z", "\xff" });
    try expectKeys(txn, .{}, .reverse, &.{ "\xff", "z", "b", "ab", "a", "" });
    // [a, b): a closed lower bound, an open upper one.
    try expectKeys(txn, .{ .lower = bytes("a"), .has_lower = true, .upper = bytes("b"), .has_upper = true, .upper_open = true }, .forward, &.{ "a", "ab" });
    // (a, ...]: an open lower bound.
    try expectKeys(txn, .{ .lower = bytes("a"), .has_lower = true, .lower_open = true }, .forward, &.{ "ab", "b", "z", "\xff" });
}

test "a read keeps its snapshot, one writer at a time, and a range delete" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openBrowser(profile);
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("snapshots"), .{});
    defer platform.closeStore(store);
    try put(store, "k", "before");

    const reader = try platform.beginTransaction(store, .read);
    defer platform.abortTransaction(reader);
    const writer = try platform.beginTransaction(store, .write);
    // One writer: a second is refused at once.
    try testing.expectError(error.Conflict, platform.beginTransaction(store, .write));
    try platform.storePut(writer, bytes("k"), bytes("after"));
    try platform.commitTransaction(writer);
    // The reader still sees its snapshot.
    const seen = (try platform.storeGet(reader, testing.allocator, bytes("k"))) orelse return error.TestExpectedValue;
    defer testing.allocator.free(seen);
    try testing.expectEqualStrings("before", seen);
    // A new reader sees the commit.
    const now = (try get(store, "k")) orelse return error.TestExpectedValue;
    defer testing.allocator.free(now);
    try testing.expectEqualStrings("after", now);

    try put(store, "k2", "x");
    const deleting = try platform.beginTransaction(store, .write);
    try platform.storeDeleteRange(deleting, .{ .lower = bytes("k"), .has_lower = true });
    try platform.commitTransaction(deleting);
    try testing.expect((try get(store, "k")) == null);
    try testing.expect((try get(store, "k2")) == null);
}

test "deleteStore removes a store, and a profile directory is the live Browser's alone" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openBrowser(profile);
    {
        defer platform.destroyBrowserPlatform(browser);
        const store = try platform.openStore(browser, platform.Str.from("doomed"), .{});
        try put(store, "a", "b");
        platform.closeStore(store);
        try platform.deleteStore(browser, platform.Str.from("doomed"));
        try testing.expectError(error.NotFound, platform.openStore(browser, platform.Str.from("doomed"), .{ .create = false }));
        // A second live Browser on the directory is refused.
        try testing.expectError(error.Busy, openBrowser(profile));
    }
    // Free once the first ended.
    const again = try openBrowser(profile);
    platform.destroyBrowserPlatform(again);
}

test "a Browser with no profile directory keeps its stores in memory" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const store = try platform.openStore(browser, platform.Str.from("memory"), .{});
    defer platform.closeStore(store);
    try put(store, "a", "b");
    const value = (try get(store, "a")) orelse return error.TestExpectedValue;
    defer testing.allocator.free(value);
    try testing.expectEqualStrings("b", value);
}
