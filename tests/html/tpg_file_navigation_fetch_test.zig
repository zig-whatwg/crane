//! A navigation to a file: URL goes through Fetch (lane tpg): scheme fetch
//! "file" answers it with the file, its extension's MIME type and its
//! Last-Modified - what Chrome's file loader sends (Chrome 157, CDP probe:
//! the file: document's responseReceived headers) - and the new document's
//! lastModified is that time, as it was when the navigation read the file
//! apart.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");

/// Run `body` on a thread of its own: each test starts its own Browser, and a
/// test directory is one process (AGENTS.md "A test directory is one
/// executable").
fn onFreshThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        failure: ?anyerror = null,
        fn thread(self: *@This()) void {
            body() catch |err| {
                self.failure = err;
            };
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&run});
    thread.join();
    if (run.failure) |err| {
        std.debug.print("failed with {s}\n", .{@errorName(err)});
        return err;
    }
}

fn expectEval(page: *browser_mod.Context, source: []const u8, expected: []const u8) !void {
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    if (!std.mem.eql(u8, got, expected)) std.debug.print("{s}\n  expected: {s}\n  got:      {s}\n", .{ source, expected, got });
    try testing.expectEqualStrings(expected, got);
}

/// Run the page's tasks until `condition` (a script) is true, bounded at 5 s.
fn until(browser: *browser_mod.Browser, condition: []const u8) !void {
    var waited: usize = 0;
    while (waited < 5_000) : (waited += 10) {
        const page = browser.current_context orelse return error.NoPage;
        const result = try page.evaluateScriptToString(condition, testing.allocator);
        defer testing.allocator.free(result);
        if (std.mem.eql(u8, result, "true")) return;
        _ = try browser.runEventLoopBlocking(10);
    }
    std.debug.print("never true: {s}\n", .{condition});
    return error.ConditionNeverMet;
}

fn fileDocumentLastModified() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "old.html", .data = "<!doctype html><title>old</title>" });
    // 2001-02-03 12:00:00 UTC: the same calendar day in every time zone.
    try tmp.dir.setTimestamps(testing.io, "old.html", .{ .modify_timestamp = .{ .new = .{ .nanoseconds = 981201600 * std.time.ns_per_s } } });
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    const url = try std.fmt.allocPrint(testing.allocator, "file://{s}/old.html", .{base});
    defer testing.allocator.free(url);

    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    try browser.navigateInPlace(url);
    try until(browser, "document.URL.startsWith('file:') && document.readyState === 'complete'");
    const page = browser.current_context orelse return error.NoPage;
    try expectEval(page, "document.title", "old");
    // HTML "lastModified": the document's source file's last modification
    // date and time, in the user's local time zone, "MM/DD/YYYY hh:mm:ss".
    try expectEval(page, "document.lastModified.slice(0, 10)", "02/03/2001");
}

test "a file: document's lastModified is its file's modification time, through Fetch's Last-Modified" {
    try onFreshThread(fileDocumentLastModified);
}
