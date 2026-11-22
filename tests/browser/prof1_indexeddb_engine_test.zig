//! IndexedDB on its backing store (lane prof1, D6 step 4; the integrator's
//! plan 2026-11-21 8:17 PM ET: one engine in both modes - kit/memory_store
//! with no profile directory, kit/sqlite with one). Each risky part of the
//! move, from script: a cursor walking records written and deleted under
//! it; index cursors over duplicate keys with continuePrimaryKey and
//! advance over deleted entries; key generators raised by explicit keys,
//! exhausted past 2^53, restored by an abort; an aborted upgrade restoring
//! a store deleted and recreated under one name and an index created; unique
//! indexes checked against the transaction's own writes and the stored
//! records; getAll/count/delete over ranges through the write batch; a Blob
//! value read back; and a readonly transaction's snapshot while a worker's
//! readwrite transactions commit beside it.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

const page_url = "https://example.test/";

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

const helpers =
    \\globalThis.settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
    \\globalThis.done = t => new Promise((resolve, reject) => { t.oncomplete = () => resolve(); t.onabort = () => reject(t.error || 'abort'); });
    \\globalThis.fresh = async (name, upgrade) => {
    \\  await settled(indexedDB.deleteDatabase(name));
    \\  const request = indexedDB.open(name, 1);
    \\  request.onupgradeneeded = () => upgrade(request.result, request.transaction);
    \\  return settled(request);
    \\};
    \\
;

fn expectInPage(browser: *Browser, comptime body: []const u8, want: []const u8) !void {
    const launch = helpers ++ "globalThis.answer = 'pending'; (async () => {" ++ body ++ "})().then(r => { answer = String(r); }, e => { answer = 'threw:' + (e && e.name || e); }); 'ok'";
    testing.allocator.free(try evaluate(browser, launch));
    for (0..4000) |_| {
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

fn inPage(comptime body: []const u8, comptime want: []const u8) fn () anyerror!void {
    return struct {
        fn run() anyerror!void {
            const browser = try openPage(null);
            defer browser.deinit();
            try expectInPage(browser, body, want);
        }
    }.run;
}

test "a cursor sees the records written and deleted under it, in key order" {
    try onThread(inPage(
        \\const db = await fresh('cursor-mutation', d => d.createObjectStore('s'));
        \\const t = db.transaction('s', 'readwrite');
        \\const s = t.objectStore('s');
        \\for (const k of [1, 3, 5, 7]) s.put('v' + k, k);
        \\const seen = [];
        \\await new Promise((resolve, reject) => {
        \\  const r = s.openCursor();
        \\  r.onerror = () => reject(r.error);
        \\  r.onsuccess = () => {
        \\    const c = r.result;
        \\    if (!c) return resolve();
        \\    seen.push(c.key + '=' + c.value);
        \\    if (c.key === 1) { s.put('v4', 4); s.delete(5); }
        \\    if (c.key === 3) c.update('v3!');
        \\    c.continue();
        \\  };
        \\});
        \\const after = (await settled(s.getAll())).join(',');
        \\await done(t);
        \\db.close();
        \\return seen.join(' ') + '|' + after;
    , "1=v1 3=v3 4=v4 7=v7|v1,v3!,v4,v7"));
}

test "index cursors over duplicate keys: unique directions, continuePrimaryKey, advance over deleted entries" {
    try onThread(inPage(
        \\const db = await fresh('dupes', d => d.createObjectStore('s').createIndex('i', 'k'));
        \\const t = db.transaction('s', 'readwrite');
        \\const s = t.objectStore('s');
        \\const index = s.index('i');
        \\const rows = [[1, 'a'], [2, 'b'], [3, 'a'], [4, 'b'], [5, 'c'], [6, 'a']];
        \\for (const [pk, k] of rows) s.put({ k }, pk);
        \\const walk = (direction, step) => new Promise((resolve, reject) => {
        \\  const out = [];
        \\  const r = index.openCursor(null, direction);
        \\  r.onerror = () => reject(r.error);
        \\  r.onsuccess = () => {
        \\    const c = r.result;
        \\    if (!c) return resolve(out.join(' '));
        \\    out.push(c.key + c.primaryKey);
        \\    step(c, out);
        \\  };
        \\});
        \\const next = await walk('next', c => c.continue());
        \\const nextunique = await walk('nextunique', c => c.continue());
        \\const prevunique = await walk('prevunique', c => c.continue());
        \\const jump = await walk('next', (c, out) => out.length === 1 ? c.continuePrimaryKey('b', 4) : c.continue());
        \\s.delete(4);
        \\s.delete(5);
        \\const advanced = await walk('next', (c, out) => out.length === 1 ? c.advance(3) : c.continue());
        \\await done(t);
        \\db.close();
        \\return [next, nextunique, prevunique, jump, advanced].join('|');
    , "a1 a3 a6 b2 b4 c5|a1 b2 c5|c5 b2 a1|a1 b4 c5|a1 b2"));
}

test "key generators: an explicit key raises them, 2^53 exhausts them, an abort restores them" {
    try onThread(inPage(
        \\const db = await fresh('generators', d => d.createObjectStore('s', { autoIncrement: true }));
        \\let t = db.transaction('s', 'readwrite');
        \\let s = t.objectStore('s');
        \\const first = await settled(s.add('a'));
        \\await settled(s.add('b', 10.5));
        \\const raised = await settled(s.add('c'));
        \\await done(t);
        \\t = db.transaction('s', 'readwrite');
        \\s = t.objectStore('s');
        \\await settled(s.add('d'));
        \\t.abort();
        \\try { await done(t); } catch (e) {}
        \\t = db.transaction('s', 'readwrite');
        \\s = t.objectStore('s');
        \\const restored = await settled(s.add('e'));
        \\await settled(s.put('max', 2 ** 53));
        \\let exhausted = 'no';
        \\try { await settled(s.add('over')); } catch (e) { exhausted = e.name; }
        \\try { await done(t); } catch (e) {}
        \\db.close();
        \\return [first, raised, restored, exhausted].join(',');
    , "1,11,12,ConstraintError"));
}

test "an aborted upgrade restores a store deleted and recreated under one name, and drops an index it created" {
    try onThread(inPage(
        \\let db = await fresh('upgrade-abort', d => d.createObjectStore('s', { keyPath: 'id' }).put({ id: 1, v: 'kept' }));
        \\db.close();
        \\const request = indexedDB.open('upgrade-abort', 2);
        \\request.onupgradeneeded = () => {
        \\  const d = request.result;
        \\  d.deleteObjectStore('s');
        \\  const again = d.createObjectStore('s', { autoIncrement: true });
        \\  again.put('new');
        \\  again.createIndex('i', 'x');
        \\  request.transaction.abort();
        \\};
        \\let failed = 'no';
        \\try { await settled(request); } catch (e) { failed = e.name; }
        \\db = await settled(indexedDB.open('upgrade-abort'));
        \\const t = db.transaction('s');
        \\const s = t.objectStore('s');
        \\const all = (await settled(s.getAll())).map(r => r.id + r.v).join(',');
        \\const shape = [db.version, s.keyPath, s.autoIncrement, s.indexNames.length].join(',');
        \\db.close();
        \\return [failed, all, shape].join('|');
    , "AbortError|1kept|1,id,false,0"));
}

test "a unique index is checked against the transaction's own writes and the stored records" {
    try onThread(inPage(
        \\const db = await fresh('unique', d => d.createObjectStore('s').createIndex('u', 'mail', { unique: true }));
        \\let t = db.transaction('s', 'readwrite');
        \\let s = t.objectStore('s');
        \\s.put({ mail: 'a' }, 1);
        \\await done(t);
        \\t = db.transaction('s', 'readwrite');
        \\s = t.objectStore('s');
        \\const results = [];
        \\// A ConstraintError's error event is canceled, so the transaction goes
        \\// on (IndexedDB "fire an error event": an uncanceled one aborts it).
        \\const attempt = async (value, key) => {
        \\  const r = s.put(value, key);
        \\  try { await new Promise((resolve, reject) => { r.onsuccess = resolve; r.onerror = (e) => { e.preventDefault(); reject(r.error); }; }); results.push('ok'); }
        \\  catch (e) { results.push(e.name); }
        \\};
        \\await attempt({ mail: 'a' }, 2);
        \\await attempt({ mail: 'b' }, 3);
        \\await attempt({ mail: 'b' }, 4);
        \\await attempt({ mail: 'b' }, 3);
        \\await attempt({ mail: 'a' }, 1);
        \\return results.join(',');
    , "ConstraintError,ok,ConstraintError,ok,ok"));
}

test "getAll, count and delete over ranges see the transaction's batch over the stored records" {
    try onThread(inPage(
        \\const db = await fresh('ranges', d => d.createObjectStore('s'));
        \\let t = db.transaction('s', 'readwrite');
        \\let s = t.objectStore('s');
        \\for (let k = 1; k <= 6; k++) s.put('v' + k, k);
        \\await done(t);
        \\t = db.transaction('s', 'readwrite');
        \\s = t.objectStore('s');
        \\s.delete(IDBKeyRange.bound(2, 4));
        \\s.put('v3again', 3);
        \\s.put('v9', 9);
        \\const keys = (await settled(s.getAllKeys())).join(',');
        \\const counted = await settled(s.count(IDBKeyRange.lowerBound(3)));
        \\const firstTwo = (await settled(s.getAll(null, 2))).join(',');
        \\const reversed = (await settled(s.getAllKeys(IDBKeyRange.upperBound(6), 0))).join(',');
        \\await done(t);
        \\db.close();
        \\return [keys, counted, firstTwo, reversed].join('|');
    , "1,3,5,6,9|4|v1,v3again|1,3,5,6"));
}

test "a Blob value is read back whole" {
    try onThread(inPage(
        \\const db = await fresh('blobs', d => d.createObjectStore('s'));
        \\let t = db.transaction('s', 'readwrite');
        \\t.objectStore('s').put(new Blob(['hello ', 'blob'], { type: 'text/plain' }), 'b');
        \\await done(t);
        \\t = db.transaction('s');
        \\const blob = await settled(t.objectStore('s').get('b'));
        \\db.close();
        \\return blob.type + ':' + await blob.text();
    , "text/plain:hello blob"));
}

test "a readonly transaction keeps its snapshot while a worker's readwrite transactions commit beside it" {
    try onThread(inPage(
        \\const db = await fresh('workers', d => d.createObjectStore('s').put(100, 'a') || d.createObjectStore('t'));
        \\db.close();
        \\const source = `
        \\  const settled = r => new Promise((resolve, reject) => { r.onsuccess = () => resolve(r.result); r.onerror = () => reject(r.error); });
        \\  (async () => {
        \\    const db = await settled(indexedDB.open('workers'));
        \\    for (let i = 1; i <= 50; i++) {
        \\      const t = db.transaction('s', 'readwrite');
        \\      t.objectStore('s').put(100 - i, 'a');
        \\      t.objectStore('s').put(i, 'b');
        \\      await new Promise(resolve => t.oncomplete = resolve);
        \\    }
        \\    db.close();
        \\    postMessage('done');
        \\  })();`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
        \\const finished = new Promise(resolve => worker.onmessage = resolve);
        \\const reader = await settled(indexedDB.open('workers'));
        \\let broken = 0, reads = 0, workerDone = false;
        \\finished.then(() => workerDone = true);
        \\while (!workerDone && reads < 400) {
        \\  const t = reader.transaction('s');
        \\  const s = t.objectStore('s');
        \\  const [a, b] = await Promise.all([settled(s.get('a')), settled(s.get('b'))]);
        \\  if ((a || 0) + (b || 0) !== 100) broken++;
        \\  reads++;
        \\}
        \\await finished;
        \\const t = reader.transaction('s');
        \\const last = await settled(t.objectStore('s').get('a'));
        \\reader.close();
        \\return broken + ',' + last;
    , "0,50"));
}
