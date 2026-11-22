//! Cookies persist in a Browser's profile directory (the user's ruling D6,
//! 2026-11-21; lane prof1, D6 step 3), as Chrome's
//! SQLitePersistentCookieStore and Firefox's cookies.sqlite keep them: a
//! persistent cookie (Expires or Max-Age) set in one Browser is sent and
//! seen in the next Browser on the directory - committed in batches and
//! flushed at the first Browser's end - while a session cookie is not
//! written at all, a cookie deleted (an expired one set over it) stays
//! deleted, and a cookie that expired while no Browser ran is gone when the
//! next one loads the jar. A Browser with no profile directory keeps its
//! jar in memory.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const page_url = "https://example.test/";

fn profilePath(tmp: *std.testing.TmpDir) ![]u8 {
    const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
    defer testing.allocator.free(base);
    return std.fs.path.join(testing.allocator, &.{ base, "profile" });
}

fn openPage(profile: ?[]const u8) !*Browser {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "", .profile_dir = profile });
    errdefer browser.deinit();
    const ctx = browser.current_context orelse return error.NoContext;
    try ctx.loadHTML("<!DOCTYPE html><title>cookies</title>", .{ .base_url = page_url });
    return browser;
}

fn expectScript(browser: *Browser, script: []const u8, want: []const u8) !void {
    const ctx = browser.current_context orelse return error.NoContext;
    const got = try ctx.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(want, got);
}

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

/// The page's cookies, sorted, as one string (document.cookie's order is
/// path length then creation time; sorting keeps the check about which).
const sorted_cookies = "document.cookie.split('; ').filter(Boolean).sort().join(';')";

fn persistentCookiesReachTheNextBrowser() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        try expectScript(
            first,
            \\document.cookie = "kept=1; Max-Age=3600; Path=/";
            \\document.cookie = "expires=2; Expires=Fri, 01 Jan 2100 00:00:00 GMT; Path=/";
            \\document.cookie = "session=3; Path=/";
            \\document.cookie = "deleted=4; Max-Age=3600; Path=/";
            \\document.cookie = "deleted=; Max-Age=0; Path=/";
            \\document.cookie = "replaced=old; Max-Age=3600; Path=/";
            \\document.cookie = "replaced=new; Max-Age=3600; Path=/";
            \\// A persistent cookie turned into a session one: its record goes.
            \\document.cookie = "demoted=p; Max-Age=3600; Path=/";
            \\document.cookie = "demoted=s; Path=/";
        ++ "\n" ++ sorted_cookies,
            "demoted=s;expires=2;kept=1;replaced=new;session=3",
        );
    }
    const second = try openPage(profile);
    defer second.deinit();
    try expectScript(second, sorted_cookies, "expires=2;kept=1;replaced=new");
}

test "persistent cookies set in one Browser on a profile directory are there in the next; session cookies are not written" {
    try onThread(persistentCookiesReachTheNextBrowser);
}

fn expiredWhileClosedIsGone() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        // Expires a second from now: still live at the first Browser's end.
        try expectScript(first,
            \\document.cookie = "short=1; Max-Age=1; Path=/";
            \\document.cookie = "long=2; Max-Age=3600; Path=/";
        ++ "\n" ++ sorted_cookies, "long=2;short=1");
    }
    std.Io.sleep(testing.io, .fromMilliseconds(1500), .awake) catch {};
    // The next Browser sweeps the expired record at load.
    const second = try openPage(profile);
    defer second.deinit();
    try expectScript(second, sorted_cookies, "long=2");
}

test "a cookie that expired while no Browser ran on the profile is swept when the next one loads the jar" {
    try onThread(expiredWhileClosedIsGone);
}

fn noProfileNoCookieFile() !void {
    {
        const first = try openPage(null);
        defer first.deinit();
        try expectScript(first, "document.cookie = 'k=v; Max-Age=3600'; document.cookie", "k=v");
    }
    const second = try openPage(null);
    defer second.deinit();
    try expectScript(second, "document.cookie", "");
}

test "a Browser with no profile directory keeps its cookies in memory, as before" {
    try onThread(noProfileNoCookieFile);
}
