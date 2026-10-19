//! Two Browsers on two threads open one IndexedDB database name under one
//! origin (lane idbshare1): IndexedDB storage is each Browser's own (its
//! IDBServer, a BrowserScope supplement), so each sees only its own
//! versions and records. Within one Browser a page and its dedicated worker
//! - on a thread of its own - share one database.
//!
//! Each Browser allocates from a DebugAllocator of its own (AGENTS.md: a
//! shared std.testing.allocator makes two Browsers take turns), which still
//! fails the test on a leak - the server's included.
const std = @import("std");
const Browser = @import("browser").Browser;

const page_url = "http://ids.test/page.html";

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(source, browser.allocator);
}

fn waitForAnswer(browser: *Browser) ![]u8 {
    for (0..2000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        browser.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

/// Run `body` (an async function's body, its result a string) in the page.
fn runInPage(browser: *Browser, body: []const u8) ![]u8 {
    const launch = try std.fmt.allocPrint(browser.allocator, "globalThis.answer = 'pending'; (async () => {{{s}}})().then(r => {{ answer = String(r); }}, e => {{ answer = 'threw:' + e; }}); 'ok'", .{body});
    defer browser.allocator.free(launch);
    const started = try evaluate(browser, launch);
    browser.allocator.free(started);
    return waitForAnswer(browser);
}

fn startBrowser(allocator: std.mem.Allocator) !*Browser {
    const browser = try Browser.init(allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
    return browser;
}

const helpers =
    \\const settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    \\
;

/// Open "shared" one version higher than it is, add this Browser's store
/// and record, and report every store name and the version.
fn upgradeOnce(browser: *Browser, tag: []const u8) ![]u8 {
    const body = try std.fmt.allocPrint(browser.allocator, "{s}" ++
        \\const infos = await indexedDB.databases();
        \\const current = (infos.find(i => i.name === 'shared') || {{version: 0}}).version;
        \\const request = indexedDB.open('shared', current + 1);
        \\request.onupgradeneeded = () => request.result.createObjectStore('{s}-' + current).put('{s}', 'k');
        \\const db = await settled(request);
        \\const names = Array.from(db.objectStoreNames).join(',');
        \\const version = db.version;
        \\db.close();
        \\return version + ':' + names;
    , .{ helpers, tag, tag });
    defer browser.allocator.free(body);
    return runInPage(browser, body);
}

const rounds = 20;

const Side = struct {
    tag: []const u8,
    start: *std.atomic.Value(bool),
    failed: ?anyerror = null,
    last: [256]u8 = undefined,
    last_len: usize = 0,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failed = err;
        };
    }

    fn steps(self: *Side) !void {
        var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
        defer if (debug_allocator.deinit() == .leak) {
            self.failed = error.Leaked;
        };
        const browser = try startBrowser(debug_allocator.allocator());
        defer browser.deinit();
        while (!self.start.load(.acquire)) std.atomic.spinLoopHint();
        for (0..rounds) |_| {
            const answer = try upgradeOnce(browser, self.tag);
            defer browser.allocator.free(answer);
            if (std.mem.startsWith(u8, answer, "threw:")) return error.ScriptThrew;
            self.last_len = @min(answer.len, self.last.len);
            @memcpy(self.last[0..self.last_len], answer[0..self.last_len]);
        }
    }
};

test "two Browsers on two threads opening one IndexedDB name each see only their own database" {
    var start = std.atomic.Value(bool).init(false);
    var sides = [_]Side{ .{ .tag = "first", .start = &start }, .{ .tag = "second", .start = &start } };
    var threads: [2]std.Thread = undefined;
    for (&sides, &threads) |*side, *thread| thread.* = try std.Thread.spawn(.{}, Side.run, .{side});
    start.store(true, .release);
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failed) |err| return err;
    for (sides) |side| {
        const answer = side.last[0..side.last_len];
        // Version `rounds`, and only this Browser's stores.
        var parts = std.mem.splitScalar(u8, answer, ':');
        try std.testing.expectEqual(@as(u64, rounds), try std.fmt.parseInt(u64, parts.next().?, 10));
        var names = std.mem.splitScalar(u8, parts.next().?, ',');
        var count: usize = 0;
        while (names.next()) |name| : (count += 1) try std.testing.expect(std.mem.startsWith(u8, name, side.tag));
        try std.testing.expectEqual(@as(usize, rounds), count);
    }
}

/// Run `body` with one Browser of its own, on a thread of its own.
fn withBrowserOnThread(comptime body: fn (*Browser) anyerror!void) !void {
    const Run = struct {
        failed: ?anyerror = null,
        fn main(self: *@This()) void {
            self.steps() catch |err| {
                self.failed = err;
            };
        }
        fn steps(self: *@This()) !void {
            var debug_allocator: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
            defer if (debug_allocator.deinit() == .leak) {
                self.failed = error.Leaked;
            };
            const browser = try startBrowser(debug_allocator.allocator());
            defer browser.deinit();
            try body(browser);
        }
    };
    var run: Run = .{};
    const thread = try std.Thread.spawn(.{}, Run.main, .{&run});
    thread.join();
    if (run.failed) |err| return err;
}

test "a page and its same-origin iframe share one IndexedDB database within a Browser" {
    try withBrowserOnThread(struct {
        fn body(browser: *Browser) !void {
            const answer = try runInPage(browser, helpers ++
                \\await settled(indexedDB.deleteDatabase('page-and-frame'));
                \\const request = indexedDB.open('page-and-frame', 2);
                \\request.onupgradeneeded = () => request.result.createObjectStore('records').put('from-page', 'k');
                \\const db = await settled(request);
                \\const frame = document.createElement('iframe');
                \\frame.srcdoc = '<!doctype html><title>frame</title>';
                \\const loaded = new Promise(resolve => { frame.onload = resolve; });
                \\document.body.appendChild(frame);
                \\await loaded;
                \\const frameDb = await settled(frame.contentWindow.indexedDB.open('page-and-frame'));
                \\const value = await settled(frameDb.transaction('records').objectStore('records').get('k'));
                \\const version = frameDb.version;
                \\frameDb.close();
                \\db.close();
                \\frame.remove();
                \\return version + ':' + value;
            );
            defer browser.allocator.free(answer);
            try std.testing.expectEqualStrings("2:from-page", answer);
        }
    }.body);
}

test "a page and its dedicated worker share one IndexedDB database within a Browser" {
    try withBrowserOnThread(struct {
        fn body(browser: *Browser) !void {
            const answer = try runInPage(browser, helpers ++
                \\await settled(indexedDB.deleteDatabase('page-and-worker'));
                \\const request = indexedDB.open('page-and-worker', 1);
                \\request.onupgradeneeded = () => request.result.createObjectStore('records').put('from-page', 'k');
                \\const db = await settled(request);
                \\db.close();
                \\const source = "const r = indexedDB.open('page-and-worker'); r.onsuccess = () => { const g = r.result.transaction('records').objectStore('records').get('k'); g.onsuccess = () => { r.result.close(); postMessage(r.result.version + ':' + g.result); }; }; r.onerror = () => postMessage('error ' + r.error.name);";
                \\const worker = new Worker(URL.createObjectURL(new Blob([source], {type: 'text/javascript'})));
                \\const result = await new Promise(resolve => { worker.onmessage = e => resolve(e.data); });
                \\worker.terminate();
                \\return result;
            );
            defer browser.allocator.free(answer);
            try std.testing.expectEqualStrings("1:from-page", answer);
        }
    }.body);
}
