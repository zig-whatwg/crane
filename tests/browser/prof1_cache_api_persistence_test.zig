//! The Cache API persists in a Browser's profile directory (the user's
//! ruling D6, 2026-11-21; lane prof1, D6 step 5): caches opened and filled
//! in one Browser on the directory are there, in their order, with their
//! entries, in the next one; a cache deleted while a Cache object still
//! held it is gone; and a Browser with no profile directory keeps Cache
//! Storage in memory.
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
    try ctx.loadHTML("<!DOCTYPE html><title>caches</title>", .{ .base_url = page_url });
    return browser;
}

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(source, testing.allocator);
}

fn expectInPage(browser: *Browser, comptime body: []const u8, want: []const u8) !void {
    const launch = "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + e; }); 'ok'";
    testing.allocator.free(try evaluate(browser, launch));
    for (0..2000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        defer testing.allocator.free(answer);
        if (!std.mem.eql(u8, answer, "pending")) return testing.expectEqualStrings(want, answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
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

fn cachesSurvive() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        try expectInPage(first,
            \\const a = await caches.open('a');
            \\await a.put('/one', new Response('1', { headers: { 'X-Kept': 'yes' } }));
            \\await a.put('/two', new Response('2'));
            \\await (await caches.open('b')).put('/three', new Response('3'));
            \\// Deleted while this Cache object still holds it.
            \\globalThis.held = await caches.open('held');
            \\await held.put('/gone', new Response('gone'));
            \\await caches.delete('held');
            \\return (await caches.keys()).join(',');
        , "a,b");
    }
    const second = try openPage(profile);
    defer second.deinit();
    try expectInPage(second,
        \\const names = (await caches.keys()).join(',');
        \\const a = await caches.open('a');
        \\const keys = (await a.keys()).map(r => new URL(r.url).pathname).join(',');
        \\const one = await a.match('/one');
        \\const three = await (await caches.match('/three')).text();
        \\const gone = await caches.match('/gone');
        \\return [names, keys, await one.text(), one.headers.get('X-Kept'), three, String(gone)].join('|');
    , "a,b|/one,/two|1|yes|3|undefined");
}

test "Cache Storage filled in one Browser on a profile directory is there in the next; a cache deleted while held is gone" {
    try onThread(cachesSurvive);
}

fn noProfileInMemory() !void {
    {
        const first = try openPage(null);
        defer first.deinit();
        try expectInPage(first, "await (await caches.open('m')).put('/x', new Response('x')); return (await caches.keys()).length;", "1");
    }
    const second = try openPage(null);
    defer second.deinit();
    try expectInPage(second, "return (await caches.keys()).length;", "0");
}

test "a Browser with no profile directory keeps Cache Storage in memory, as before" {
    try onThread(noProfileInMemory);
}
