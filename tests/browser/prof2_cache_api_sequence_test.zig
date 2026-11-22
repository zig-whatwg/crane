//! The Cache API on the Browser's storage sequence (lane prof2): with a
//! profile directory every Cache Storage operation - reads too - runs on the
//! sequence in the order called, and its promise settles from a task posted
//! back to the realm, as Chromium runs every operation through its
//! CacheStorageScheduler on the cache storage's own sequence. From a page:
//! open() settles only once the sequence ran it; operations called without
//! awaiting run in their order (has() after an unawaited open() and
//! delete() sees each); what a page put is there for the next Browser; a
//! worker's calls answer on the worker's own loop, and a worker that ends
//! with a call still waiting releases it on its own thread.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const storage = @import("storage");

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

fn launch(browser: *Browser, comptime body: []const u8) !void {
    const source = "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + (e && e.name || e); }); 'ok'";
    testing.allocator.free(try evaluate(browser, source));
}

fn awaitAnswer(browser: *Browser) ![]u8 {
    for (0..4000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        testing.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

fn expectInPage(browser: *Browser, comptime body: []const u8, want: []const u8) !void {
    try launch(browser, body);
    const answer = try awaitAnswer(browser);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings(want, answer);
}

fn expectStillPending(browser: *Browser, turns: usize) !void {
    for (0..turns) |_| _ = try browser.runEventLoopBlocking(10);
    const answer = try evaluate(browser, "globalThis.answer");
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("pending", answer);
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

/// A job that holds the Browser's storage sequence until its gate is set.
const Held = struct {
    job: storage.sequence.Job = .{ .run = run, .drop = drop },
    gate: storage.sequence.Done = .{},

    fn run(job: *storage.sequence.Job) void {
        const self: *Held = @fieldParentPtr("job", job);
        self.gate.wait();
    }

    fn drop(job: *storage.sequence.Job) void {
        _ = job;
    }
};

fn sequenceOf(browser: *Browser) ?*storage.StorageSequence {
    return browser.scope.existing(storage.StorageSequence);
}

fn openWaitsForTheSequence() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const browser = try openPage(profile);
        defer browser.deinit();
        const sequence = sequenceOf(browser) orelse return error.NoSequence;
        var held: Held = .{};
        defer held.gate.set();
        sequence.post(&held.job);
        try launch(browser,
            \\const cache = await caches.open('c');
            \\await cache.put('/x', new Response('body'));
            \\return (await (await cache.match('/x')).text());
        );
        // open() is on the held sequence: its promise waits.
        try expectStillPending(browser, 30);
        held.gate.set();
        const answer = try awaitAnswer(browser);
        defer testing.allocator.free(answer);
        try testing.expectEqualStrings("body", answer);
    }
    const next = try openPage(profile);
    defer next.deinit();
    try expectInPage(next, "return (await (await caches.match('/x')).text()) + '|' + (await caches.keys()).join(',');", "body|c");
}

test "with a profile directory, a Cache Storage promise settles once the storage sequence ran its work" {
    try onThread(openWaitsForTheSequence);
}

fn callsRunInTheirOrder() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openPage(profile);
    defer browser.deinit();
    try expectInPage(browser,
        \\const opened = caches.open('a');
        \\const hasAfterOpen = caches.has('a');
        \\const deleted = caches.delete('a');
        \\const hasAfterDelete = caches.has('a');
        \\const results = await Promise.all([opened, hasAfterOpen, deleted, hasAfterDelete]);
        \\return [typeof results[0], results[1], results[2], results[3]].join(',');
    , "object,true,true,false");
}

test "Cache Storage calls made without awaiting run on the storage sequence in the order they were called" {
    try onThread(callsRunInTheirOrder);
}

fn workerCalls() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openPage(profile);
    defer browser.deinit();
    const sequence = sequenceOf(browser) orelse return error.NoSequence;
    // A worker's calls answer on its own loop.
    try expectInPage(browser,
        \\const source = `(async () => {
        \\  const cache = await caches.open('w');
        \\  await cache.put('/w', new Response('from worker'));
        \\  postMessage(await (await cache.match('/w')).text());
        \\})().catch(e => postMessage('failed:' + e));`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
        \\const answer = await new Promise(resolve => worker.onmessage = e => resolve(e.data));
        \\worker.terminate();
        \\return answer + '|' + (await (await caches.match('/w')).text());
    , "from worker|from worker");
    // A worker that ends with a call waiting on the held sequence: its end
    // releases the call on its own thread; the job still runs, its answer
    // finds nobody, and the page goes on.
    var held: Held = .{};
    defer held.gate.set();
    sequence.post(&held.job);
    try expectInPage(browser,
        \\const source = `caches.keys().then(k => postMessage('answered'), e => postMessage('failed')); postMessage('called');`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
        \\const first = await new Promise(resolve => worker.onmessage = e => resolve(e.data));
        \\worker.terminate();
        \\return first;
    , "called");
    for (0..10) |_| _ = try browser.runEventLoopBlocking(10);
    held.gate.set();
    try expectInPage(browser, "return (await caches.keys()).join(',');", "w");
}

test "a worker's Cache Storage calls answer on its loop, and a worker ending with a call waiting releases it" {
    try onThread(workerCalls);
}
