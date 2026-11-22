//! IndexedDB persists in a Browser's profile directory (the user's ruling
//! D6, 2026-11-21; lane prof1, D6 step 4): a database made and filled in
//! one Browser on a profile directory is there, at its version, in the next
//! Browser on it - its object stores and their key paths and key
//! generators, its records in key order across every key type, its
//! indexes, unique and multiEntry included - and indexedDB.databases()
//! lists it before any open. A transaction that aborted left nothing; a
//! deleted database stays deleted; a store deleted by an upgrade is gone. A
//! Browser with no profile directory keeps IndexedDB in memory.
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
    try ctx.loadHTML("<!DOCTYPE html><title>idb</title>", .{ .base_url = page_url });
    return browser;
}

fn evaluate(browser: *Browser, source: []const u8) ![]u8 {
    const ctx = browser.current_context orelse return error.NoContext;
    return ctx.evaluateScriptToString(source, testing.allocator);
}

/// Run `body` - an async function's body whose result is a string - in the
/// page, and answer its result once it settles.
fn runInPage(browser: *Browser, body: []const u8) ![]u8 {
    const launch = try std.fmt.allocPrint(testing.allocator, helpers ++ "globalThis.answer = 'pending'; (async () => {{{s}}})().then(r => {{ answer = String(r); }}, e => {{ answer = 'threw:' + e; }}); 'ok'", .{body});
    defer testing.allocator.free(launch);
    testing.allocator.free(try evaluate(browser, launch));
    for (0..2000) |_| {
        const answer = try evaluate(browser, "globalThis.answer");
        if (!std.mem.eql(u8, answer, "pending")) return answer;
        testing.allocator.free(answer);
        _ = try browser.runEventLoopBlocking(10);
    }
    return error.TimedOut;
}

const helpers =
    \\globalThis.settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    \\globalThis.done = t => new Promise((resolve, reject) => { t.oncomplete = () => resolve(); t.onabort = () => reject(t.error || 'abort'); });
    \\
;

fn expectInPage(browser: *Browser, body: []const u8, want: []const u8) !void {
    const got = try runInPage(browser, body);
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

const fill =
    \\const request = indexedDB.open('db', 3);
    \\request.onupgradeneeded = () => {
    \\  const db = request.result;
    \\  const people = db.createObjectStore('people', { keyPath: 'id' });
    \\  people.createIndex('by_name', 'name');
    \\  people.createIndex('by_mail', 'mail', { unique: true });
    \\  people.createIndex('by_tag', 'tags', { multiEntry: true });
    \\  db.createObjectStore('counter', { autoIncrement: true });
    \\  db.createObjectStore('keys');
    \\  db.createObjectStore('doomed');
    \\};
    \\const db = await settled(request);
    \\let t = db.transaction(['people', 'counter', 'keys'], 'readwrite');
    \\const people = t.objectStore('people');
    \\people.put({ id: 2, name: 'bo', mail: 'b@x', tags: ['a', 'b'] });
    \\people.put({ id: 1, name: 'al', mail: 'a@x', tags: ['b'] });
    \\people.put({ id: 3, name: 'al', mail: 'c@x', tags: [] });
    \\t.objectStore('counter').add('first');
    \\t.objectStore('counter').add('second');
    \\const keys = t.objectStore('keys');
    \\// One of each key type, out of order: array > binary > string > date > number.
    \\keys.put('array', [1, 'x']);
    \\keys.put('binary', new Uint8Array([0, 255]));
    \\keys.put('string-b', 'b');
    \\keys.put('string-a\u00e9', 'a\u00e9');
    \\keys.put('date', new Date(5));
    \\keys.put('number-neg', -1.5);
    \\keys.put('number', 7);
    \\await done(t);
    \\// An aborted transaction leaves nothing.
    \\t = db.transaction('people', 'readwrite');
    \\t.objectStore('people').put({ id: 9, name: 'zz', mail: 'z@x', tags: [] });
    \\t.abort();
    \\try { await done(t); } catch (e) {}
    \\// A delete and an update, committed.
    \\t = db.transaction('people', 'readwrite');
    \\t.objectStore('people').delete(2);
    \\t.objectStore('people').put({ id: 3, name: 'cy', mail: 'c@x', tags: ['c'] });
    \\await done(t);
    \\db.close();
    \\// An upgrade that deletes a store.
    \\const up = indexedDB.open('db', 4);
    \\up.onupgradeneeded = () => up.result.deleteObjectStore('doomed');
    \\(await settled(up)).close();
    \\// A database made and deleted.
    \\(await settled(indexedDB.open('gone', 1))).close();
    \\await settled(indexedDB.deleteDatabase('gone'));
    \\return 'filled';
;

const read_back =
    \\const listed = (await indexedDB.databases()).map(i => i.name + '@' + i.version).sort().join(',');
    \\const db = await settled(indexedDB.open('db'));
    \\const t = db.transaction(['people', 'counter', 'keys'], 'readwrite');
    \\const people = t.objectStore('people');
    \\const all = (await settled(people.getAll())).map(p => p.id + p.name).join(',');
    \\const byName = (await settled(people.index('by_name').getAllKeys())).join(',');
    \\const byTag = (await settled(people.index('by_tag').getAllKeys(IDBKeyRange.only('b')))).join(',');
    \\let unique = 'ok';
    \\try { await settled(people.add({ id: 5, name: 'dup', mail: 'a@x', tags: [] })); unique = 'not unique'; } catch (e) { unique = e.name; }
    \\const keyTypes = (await settled(t.objectStore('keys').getAll())).join(',');
    \\const counter = t.objectStore('counter');
    \\const next = await settled(counter.add('third'));
    \\const counted = (await settled(counter.getAllKeys())).join(',');
    \\const stores = Array.from(db.objectStoreNames).join(',');
    \\t.abort();
    \\db.close();
    \\return [listed, db.version, stores, all, byName, byTag, unique, keyTypes, next, counted].join('|');
;

fn databasesSurviveTheBrowser() !void {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    const profile = try profilePath(&tmp);
    defer testing.allocator.free(profile);
    {
        const first = try openPage(profile);
        defer first.deinit();
        try expectInPage(first, fill, "filled");
    }
    const second = try openPage(profile);
    defer second.deinit();
    try expectInPage(second, read_back, "db@4|4|counter,keys,people|1al,3cy|1,3|1|ConstraintError|number-neg,number,date,string-a\u{e9},string-b,binary,array|3|1,2,3");
}

test "an IndexedDB database made in one Browser on a profile directory is there, whole and in key order, in the next" {
    try onThread(databasesSurviveTheBrowser);
}

fn noProfileInMemory() !void {
    {
        const first = try openPage(null);
        defer first.deinit();
        try expectInPage(first, "(await settled(indexedDB.open('m', 1))).close(); return (await indexedDB.databases()).length;", "1");
    }
    const second = try openPage(null);
    defer second.deinit();
    try expectInPage(second, "return (await indexedDB.databases()).length;", "0");
}

test "a Browser with no profile directory keeps IndexedDB in memory, as before" {
    try onThread(noProfileInMemory);
}
