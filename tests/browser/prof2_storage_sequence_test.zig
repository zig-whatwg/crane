//! A Browser's profile stores are written off the thread that changed them
//! (lane prof2): on the Browser's storage sequence, as Chromium writes DOM
//! storage, cookies, the disk cache and IndexedDB on sequences of their own.
//! From a page: an IndexedDB transaction's complete event fires only once
//! the sequence wrote its commit (Chromium posts complete after its backing
//! store's commit); a commit the sequence fails to write aborts the
//! transaction with an UnknownError; a deleteDatabase request succeeds only
//! once the records are gone; the Browser's end writes everything still
//! pending - localStorage, cookies, an IndexedDB commit in flight - before
//! it ends; a worker's transactions and the page's commit side by side; and
//! a Browser with no profile directory has no sequence and no thread.
//!
//! To hold the sequence a test posts it a job that waits on a gate (the
//! sequence's own API); to make a write fail it holds the store's one
//! writer (kit/sqlite answers a second writer with Conflict) - no hook
//! exists only for the test.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const storage = @import("storage");
const platform = @import("platform");

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
    try ctx.loadHTML("<!DOCTYPE html><title>sequence</title>", .{ .base_url = page_url });
    return browser;
}

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(source, testing.allocator);
}

const helpers =
    \\globalThis.settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    \\globalThis.done = t => new Promise((resolve, reject) => { t.oncomplete = () => resolve(); t.onabort = () => reject(t.error || 'abort'); });
    \\
;

/// Start `body` - an async function's body - in the page; its result lands
/// in globalThis.answer ('pending' until then).
fn launch(browser: *Browser, comptime body: []const u8) !void {
    const source = helpers ++ "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + (e && e.name || e); }); 'ok'";
    testing.allocator.free(try evaluate(browser, source));
}

/// Turn the Browser's loop until the page's answer is in.
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

/// Turn the Browser's loop for about `turns` x 10 ms and expect the page's
/// answer still pending: what it awaits waits for the held sequence.
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

/// A job that holds the Browser's storage sequence until its gate is set:
/// everything handed to the sequence after it waits.
const Held = struct {
    job: storage.sequence.Job = .{ .run = run, .drop = drop },
    gate: storage.sequence.Done = .{},
    ran: std.atomic.Value(bool) = .init(false),

    fn run(job: *storage.sequence.Job) void {
        const self: *Held = @fieldParentPtr("job", job);
        self.ran.store(true, .release);
        self.gate.wait();
    }

    fn drop(job: *storage.sequence.Job) void {
        _ = job;
    }

    /// Set the gate from another thread after `ms`: for a Browser's end,
    /// which waits for the sequence on this one.
    fn releaseLater(self: *Held, ms: u64) !std.Thread {
        return std.Thread.spawn(.{}, struct {
            fn later(held: *Held, delay: u64) void {
                std.Io.sleep(testing.io, .fromMilliseconds(@intCast(delay)), .awake) catch {};
                held.gate.set();
            }
        }.later, .{ self, ms });
    }
};

fn sequenceOf(browser: *Browser) ?*storage.StorageSequence {
    return browser.scope.existing(storage.StorageSequence);
}

/// The Browser's platform state, whose stores are under its profile.
fn platformOf(browser: *Browser) !*platform.BrowserPlatform {
    const server = browser.scope.existing(storage.indexeddb.IDBServer) orelse return error.NoServer;
    const backing = server.backingStore() orelse return error.NoBackingStore;
    return backing.browser;
}

const make_database =
    \\await settled(indexedDB.deleteDatabase('db'));
    \\const request = indexedDB.open('db', 1);
    \\request.onupgradeneeded = () => { request.result.createObjectStore('s'); request.result.createObjectStore('page'); request.result.createObjectStore('worker'); };
    \\globalThis.db = await settled(request);
    \\return 'made';
;

fn completeWaitsForTheWrite() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const browser = try openPage(profile);
        defer browser.deinit();
        const sequence = sequenceOf(browser) orelse return error.NoSequence;
        try testing.expect(sequence.isRunning());
        try expectInPage(browser, make_database, "made");
        var held: Held = .{};
        // Set before the Browser ends, whatever happens below (its end
        // waits for the sequence).
        defer held.gate.set();
        sequence.post(&held.job);
        try launch(browser,
            \\const t = db.transaction('s', 'readwrite');
            \\t.objectStore('s').put('value', 'key');
            \\await done(t);
            \\return 'complete';
        );
        // The commit is on the held sequence: no complete event.
        try expectStillPending(browser, 30);
        held.gate.set();
        const answer = try awaitAnswer(browser);
        defer testing.allocator.free(answer);
        try testing.expectEqualStrings("complete", answer);
        try expectInPage(browser, "db.close(); return 'closed';", "closed");
    }
    // Written, as the complete event said.
    const next = try openPage(profile);
    defer next.deinit();
    try expectInPage(next,
        \\const db = await settled(indexedDB.open('db'));
        \\const value = await settled(db.transaction('s').objectStore('s').get('key'));
        \\db.close();
        \\return value;
    , "value");
}

test "with a profile directory, an IndexedDB transaction completes only once the storage sequence wrote its commit" {
    try onThread(completeWaitsForTheWrite);
}

fn failedWriteAborts() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openPage(profile);
    defer browser.deinit();
    try expectInPage(browser, make_database, "made");
    // The store's one writer, held here: the sequence's write of the next
    // commit is refused (Conflict).
    const store = try platform.openStore(try platformOf(browser), platform.Str.from(storage.indexeddb.backing_store.store_name), .{});
    defer platform.closeStore(store);
    const writer = try platform.beginTransaction(store, .write);
    var holding = true;
    defer if (holding) platform.abortTransaction(writer);
    try expectInPage(browser,
        \\const t = db.transaction('s', 'readwrite');
        \\t.objectStore('s').put('lost', 'key');
        \\let fired = '';
        \\t.addEventListener('complete', () => fired += 'complete');
        \\t.addEventListener('abort', () => fired += 'abort');
        \\try { await done(t); } catch (e) { return fired + ':' + (t.error && t.error.name); }
        \\return 'not aborted';
    , "abort:UnknownError");
    platform.abortTransaction(writer);
    holding = false;
    // Nothing of it was written, and the next commit is.
    try expectInPage(browser,
        \\const lost = await settled(db.transaction('s').objectStore('s').get('key'));
        \\const t = db.transaction('s', 'readwrite');
        \\t.objectStore('s').put('kept', 'key');
        \\await done(t);
        \\const kept = await settled(db.transaction('s').objectStore('s').get('key'));
        \\return String(lost) + ',' + kept;
    , "undefined,kept");
}

test "a commit the storage sequence fails to write aborts the transaction with an UnknownError" {
    try onThread(failedWriteAborts);
}

fn deletionWaitsForTheWrite() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    const browser = try openPage(profile);
    defer browser.deinit();
    const sequence = sequenceOf(browser) orelse return error.NoSequence;
    try expectInPage(browser, make_database, "made");
    try expectInPage(browser, "db.close(); return 'closed';", "closed");
    var held: Held = .{};
    defer held.gate.set();
    sequence.post(&held.job);
    try launch(browser,
        \\await settled(indexedDB.deleteDatabase('db'));
        \\return 'deleted';
    );
    try expectStillPending(browser, 30);
    held.gate.set();
    const answer = try awaitAnswer(browser);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings("deleted", answer);
    try expectInPage(browser, "return (await indexedDB.databases()).length;", "0");
}

test "with a profile directory, deleteDatabase succeeds only once the storage sequence deleted the records" {
    try onThread(deletionWaitsForTheWrite);
}

fn endDrainsPendingWrites() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const browser = try openPage(profile);
        const sequence = sequenceOf(browser) orelse {
            browser.deinit();
            return error.NoSequence;
        };
        expectInPage(browser, make_database, "made") catch |err| {
            browser.deinit();
            return err;
        };
        // The localStorage area is loaded first: its first read waits for
        // the sequence (a barrier, as Chrome's renderer reads an area with a
        // sync GetAll), which the held job below would block for good.
        expectInPage(browser, "localStorage.getItem('kept'); return 'loaded';", "loaded") catch |err| {
            browser.deinit();
            return err;
        };
        var held: Held = .{};
        sequence.post(&held.job);
        const posted = sequence.postedCount();
        // localStorage and a cookie wait in their batches (Chrome's 5 s and
        // 30 s delays); the IndexedDB commit waits on the held sequence, its
        // transaction committing.
        launch(browser,
            \\localStorage.setItem('kept', 'one');
            \\document.cookie = 'kept=two; max-age=3600';
            \\const t = db.transaction('s', 'readwrite');
            \\t.objectStore('s').put('three', 'key');
            \\await done(t);
            \\return 'complete';
        ) catch |err| {
            held.gate.set();
            browser.deinit();
            return err;
        };
        // Until the commit is handed over: the one post in this window.
        var turns: usize = 0;
        while (sequence.postedCount() == posted and turns < 2000) : (turns += 1) {
            _ = browser.runEventLoopBlocking(10) catch false;
        }
        if (sequence.postedCount() == posted) {
            held.gate.set();
            browser.deinit();
            return error.CommitNeverHandedOver;
        }
        // The Browser ends while the sequence is still held: its end waits
        // for the commit in flight and hands over the batches, and the
        // sequence's stop writes all of it once the gate opens.
        const releaser = try held.releaseLater(200);
        browser.deinit();
        releaser.join();
        try testing.expect(held.ran.load(.acquire));
    }
    const next = try openPage(profile);
    defer next.deinit();
    try expectInPage(next,
        \\const db = await settled(indexedDB.open('db'));
        \\const value = await settled(db.transaction('s').objectStore('s').get('key'));
        \\db.close();
        \\return [localStorage.getItem('kept'), document.cookie, value].join('|');
    , "one|kept=two|three");
}

test "the Browser's end writes every pending profile write - localStorage, cookies, an IndexedDB commit in flight - before it ends" {
    try onThread(endDrainsPendingWrites);
}

fn workerAndPageSideBySide() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const browser = try openPage(profile);
        defer browser.deinit();
        try expectInPage(browser, make_database, "made");
        try expectInPage(browser,
            \\const source = `
            \\  const settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
            \\  (async () => {
            \\    const db = await settled(indexedDB.open('db'));
            \\    for (let i = 0; i < 20; i++) {
            \\      const t = db.transaction('worker', 'readwrite');
            \\      t.objectStore('worker').put(i, i);
            \\      await new Promise((resolve, reject) => { t.oncomplete = resolve; t.onabort = () => reject(t.error); });
            \\    }
            \\    db.close();
            \\    postMessage('done');
            \\  })().catch(e => postMessage('failed:' + e));`;
            \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
            \\const finished = new Promise(resolve => worker.onmessage = e => resolve(e.data));
            \\for (let i = 0; i < 20; i++) {
            \\  const t = db.transaction('page', 'readwrite');
            \\  t.objectStore('page').put(i, i);
            \\  await done(t);
            \\}
            \\const worker_result = await finished;
            \\db.close();
            \\return worker_result;
        , "done");
    }
    const next = try openPage(profile);
    defer next.deinit();
    try expectInPage(next,
        \\const db = await settled(indexedDB.open('db'));
        \\const t = db.transaction(['page', 'worker']);
        \\const counts = [await settled(t.objectStore('page').count()), await settled(t.objectStore('worker').count())];
        \\db.close();
        \\return counts.join(',');
    , "20,20");
}

test "a worker's IndexedDB transactions and the page's commit on the storage sequence side by side" {
    try onThread(workerAndPageSideBySide);
}

fn noProfileNoSequence() !void {
    const browser = try openPage(null);
    defer browser.deinit();
    // No sequence, no thread: IndexedDB commits on the committing thread
    // (kit/memory_store), as before.
    try testing.expect(sequenceOf(browser) == null);
    const server = browser.scope.existing(storage.indexeddb.IDBServer) orelse return error.NoServer;
    try testing.expect(server.backingStore().?.sequence == null);
    try expectInPage(browser,
        \\const request = indexedDB.open('m', 1);
        \\request.onupgradeneeded = () => request.result.createObjectStore('s');
        \\const db = await settled(request);
        \\const t = db.transaction('s', 'readwrite');
        \\t.objectStore('s').put(1, 1);
        \\await done(t);
        \\db.close();
        \\return 'complete';
    , "complete");
    try testing.expect(sequenceOf(browser) == null);
}

test "a Browser with no profile directory has no storage sequence and no thread for it" {
    try onThread(noProfileNoSequence);
}
