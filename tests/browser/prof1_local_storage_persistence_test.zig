//! localStorage persists in a Browser's profile directory (the user's ruling
//! D6, 2026-11-21: Puppeteer's --user-data-dir fully supported; lane prof1,
//! D6 step 2): what a page stores in one Browser on a profile directory is
//! there for the same origin's page in the next Browser on it - committed in
//! batches after a delay, as Chrome's StorageAreaImpl commits, and flushed at
//! the Browser's end (LocalStorageImpl::ShutDown), so writes still pending
//! when the first Browser ends reach the second. removeItem and clear()
//! persist too. sessionStorage does not survive a restart (no browser
//! restores it outside session restore), a second live Browser on the
//! directory is refused, and a Browser with no profile directory keeps
//! today's in-memory storage.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const page_url = "https://example.test/";

/// A profile directory under `tmp`. OWNED path.
fn profilePath(tmp: *std.testing.TmpDir) ![]u8 {
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    return std.fs.path.join(testing.allocator, &.{ base, "profile" });
}

/// A Browser on `profile` (or none) with a page of https://example.test
/// loaded in its first tab.
fn openPage(profile: ?[]const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
    errdefer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    try ctx.loadHTML("<!DOCTYPE html><title>storage</title>", .{ .base_url = page_url });
    return browser;
}

fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(script, testing.allocator);
}

fn expectScript(browser: *Browser, script: []const u8, want: []const u8) !void {
    const got = try evaluate(browser, script);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(want, got);
}

/// Each case on its own thread: each Browser's window agent, as the
/// directory's other tests run theirs (AGENTS.md "A test directory is one
/// executable").
fn onThread(comptime case: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            case() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| return err;
}

fn writesPendingAtTheEndReachTheNextBrowser() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        // Every write here is still in its commit batch (Chrome's 5 s
        // default delay has not passed): only the end's flush commits it.
        try expectScript(first,
            \\localStorage.setItem("kept", "one");
            \\localStorage.setItem("replaced", "before");
            \\localStorage.setItem("replaced", "after");
            \\localStorage.setItem("removed", "x");
            \\localStorage.removeItem("removed");
            \\localStorage.setItem("", "empty key");
            \\localStorage.setItem("unicode", "é中😀");
            \\sessionStorage.setItem("session", "gone at restart");
            \\localStorage.length + ""
        , "4");
        // A second live Browser on the directory is refused.
        try testing.expectError(error.ProfileInUse, Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile }));
    }
    // The stores are under the profile directory.
    try tmp.dir.access(testing.io, "profile/stores", .{});

    const second = try openPage(profile);
    defer second.deinit();
    try expectScript(second,
        \\[localStorage.length,
        \\ localStorage.getItem("kept"),
        \\ localStorage.getItem("replaced"),
        \\ localStorage.getItem("removed"),
        \\ localStorage.getItem(""),
        \\ localStorage.getItem("unicode") === "é中😀",
        \\ sessionStorage.getItem("session"),
        \\ sessionStorage.length].join("|")
    , "4|one|after||empty key|true||0");
}

test "localStorage written in one Browser on a profile directory, still pending at its end, is read by the next Browser on it; sessionStorage is not" {
    try onThread(writesPendingAtTheEndReachTheNextBrowser);
}

fn clearPersists() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        try expectScript(first, "localStorage.setItem('a', '1'); localStorage.setItem('b', '2'); 'ok'", "ok");
    }
    {
        // The second Browser loads a and b, clears them and writes c: its
        // commit clears the area's keys first (CommitBatch.clear_all_first).
        const second = try openPage(profile);
        defer second.deinit();
        try expectScript(second, "localStorage.getItem('a') + localStorage.getItem('b')", "12");
        try expectScript(second, "localStorage.clear(); localStorage.setItem('c', '3'); localStorage.length + ''", "1");
    }
    const third = try openPage(profile);
    defer third.deinit();
    try expectScript(third, "[localStorage.length, localStorage.getItem('a'), localStorage.getItem('c')].join('|')", "1||3");
}

test "localStorage.clear() and the writes after it persist to the next Browser on the profile" {
    try onThread(clearPersists);
}

fn originsStayApart() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
        defer first.deinit();
        const ctx = first.current_context orelse return error.NoContext;
        try ctx.loadHTML("<!DOCTYPE html>", .{ .base_url = "https://other.test/" });
        try expectScript(first, "localStorage.setItem('k', 'other'); 'ok'", "ok");
        try ctx.loadHTML("<!DOCTYPE html>", .{ .base_url = page_url });
        try expectScript(first, "localStorage.setItem('k', 'example'); 'ok'", "ok");
    }
    const second = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
    defer second.deinit();
    const ctx = second.current_context orelse return error.NoContext;
    try ctx.loadHTML("<!DOCTYPE html>", .{ .base_url = "https://other.test/" });
    try expectScript(second, "localStorage.getItem('k') + '|' + localStorage.length", "other|1");
    try ctx.loadHTML("<!DOCTYPE html>", .{ .base_url = page_url });
    try expectScript(second, "localStorage.getItem('k') + '|' + localStorage.length", "example|1");
}

test "each origin's localStorage persists under its own storage key" {
    try onThread(originsStayApart);
}

fn noProfileNoPersistence() !void {
    {
        const first = try openPage(null);
        defer first.deinit();
        try expectScript(first, "localStorage.setItem('k', 'v'); localStorage.getItem('k')", "v");
    }
    // A Browser with no profile directory keeps its storage in memory: the
    // next one starts empty.
    const second = try openPage(null);
    defer second.deinit();
    try expectScript(second, "String(localStorage.getItem('k'))", "null");
}

test "a Browser with no profile directory keeps localStorage in memory, as before" {
    try onThread(noProfileNoPersistence);
}
