//! Transferable streams (WHATWG Streams 4.2.6, 5.2.5, 6.2.5, 8.2) through
//! the carriers of a transfer list - structuredClone, a MessagePort, a
//! Window's postMessage, a dedicated worker - in a Browser with its event
//! loop, its teardown checked by std.testing.allocator (lane net2).
//!
//! Before lane net2 every carrier shipped only MessagePort ends, so a stream
//! in a transfer list was a DataCloneError (streams/transferable/*.html, all
//! three browsers passing). The transferred stream is a cross-realm
//! transform: a hidden MessagePort pair, whose lifetime is the port's pending
//! activity and traced edges - so the tests also drop every reference and
//! collect, and end a worker with chunks in flight.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

const page_url = "http://net2.test/page.html";

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const result = try browser.evaluateScript(source);
    result.release();
}

fn truthy(browser: *browser_mod.Browser, source: []const u8) !bool {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

/// Turn the page's loop until `source` is true.
fn waitFor(browser: *browser_mod.Browser, source: []const u8) !void {
    for (0..2000) |_| {
        if (try truthy(browser, source)) return;
        _ = try browser.runEventLoopBlocking(5);
    }
    return error.TimedOut;
}

fn expectString(browser: *browser_mod.Browser, source: []const u8, expected: []const u8) !void {
    const page = browser.current_context orelse return error.NoPage;
    const got = try page.evaluateScriptToString(source, testing.allocator);
    defer testing.allocator.free(got);
    try testing.expectEqualStrings(expected, got);
}

fn collect(browser: *browser_mod.Browser) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    for (0..3) |_| try engine.runInRealm(browser.getRealm().?, Collect.steps, browser.getAgent().?);
}

/// A Browser on an empty page, its body run on a fresh thread (the test may
/// assume only what the process start makes).
fn withPage(comptime body: fn (*browser_mod.Browser) anyerror!void) !void {
    const Run = struct {
        fn exercise() !void {
            const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
            defer browser.deinit();
            try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
            const page = browser.current_context orelse return error.NoPage;
            try page.loadHTML("<!doctype html><body>", .{ .base_url = page_url });
            try body(browser);
        }

        fn thread(result: *anyerror!void) void {
            result.* = exercise();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&result});
    thread.join();
    try result;
}

test "structuredClone transfers a ReadableStream: chunks and close arrive, the original is locked" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try run(browser,
                \\globalThis.result = 'pending';
                \\const original = new ReadableStream({ start(c) { c.enqueue('a'); c.enqueue('b'); c.close(); } });
                \\const received = structuredClone(original, { transfer: [original] });
                \\(async () => {
                \\  const reader = received.getReader();
                \\  const out = [original.locked, received instanceof ReadableStream, received !== original];
                \\  for (;;) { const { value, done } = await reader.read(); if (done) break; out.push(value); }
                \\  result = out.join();
                \\})().catch(e => { result = 'error ' + e; });
            );
            try waitFor(browser, "result !== 'pending'");
            try expectString(browser, "result", "true,true,true,a,b");
        }
    }.body);
}

test "a locked stream, and a stream twice in one transfer list, are DataCloneErrors" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try expectString(browser,
                \\const names = [];
                \\const locked = new ReadableStream();
                \\locked.getReader();
                \\try { structuredClone(locked, { transfer: [locked] }); names.push('none'); } catch (e) { names.push(e.name); }
                \\const twice = new WritableStream();
                \\try { structuredClone(twice, { transfer: [twice, twice] }); names.push('none'); } catch (e) { names.push(e.name); }
                \\const ts = new TransformStream();
                \\ts.writable.getWriter();
                \\try { structuredClone(ts, { transfer: [ts] }); names.push('none'); } catch (e) { names.push(e.name); }
                \\names.push(ts.readable.locked);
                \\const sent = new ReadableStream();
                \\structuredClone(sent, { transfer: [sent] });
                \\try { structuredClone(sent, { transfer: [sent] }); names.push('none'); } catch (e) { names.push(e.name); }
                \\names.join()
            , "DataCloneError,DataCloneError,DataCloneError,false,DataCloneError");
        }
    }.body);
}

test "a WritableStream sent through a MessagePort writes and closes the original sink; its port stays hidden" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try run(browser,
                \\globalThis.result = 'pending';
                \\const chunks = [];
                \\const original = new WritableStream({
                \\  write(chunk) { chunks.push(chunk); },
                \\  close() { result = chunks.join() + ' closed ports=' + ports; },
                \\});
                \\let ports = -1;
                \\const channel = new MessageChannel();
                \\channel.port2.onmessage = async event => {
                \\  ports = event.ports.length;
                \\  const writer = event.data.getWriter();
                \\  await writer.write('x');
                \\  await writer.write('y');
                \\  await writer.close();
                \\};
                \\channel.port1.postMessage(original, [original]);
            );
            try waitFor(browser, "result !== 'pending'");
            try expectString(browser, "result", "x,y closed ports=0");
        }
    }.body);
}

test "a TransformStream sent by window.postMessage connects both transferred sides" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try run(browser,
                \\globalThis.result = 'pending';
                \\const original = new TransformStream({ transform(chunk, c) { c.enqueue(chunk.toUpperCase()); } });
                \\addEventListener('message', async event => {
                \\  const ts = event.data;
                \\  const writer = ts.writable.getWriter();
                \\  const reader = ts.readable.getReader();
                \\  writer.write('up');
                \\  const { value } = await reader.read();
                \\  writer.close();
                \\  const { done } = await reader.read();
                \\  result = [ts instanceof TransformStream, lockedAtPost, value, done].join();
                \\}, { once: true });
                \\postMessage(original, '*', [original]);
                \\// Both sides are locked by their transfer pipes until those end.
                \\const lockedAtPost = original.readable.locked && original.writable.locked;
            );
            try waitFor(browser, "result !== 'pending'");
            try expectString(browser, "result", "true,true,UP,true");
        }
    }.body);
}

test "a stream sent to a worker and back reads through both realms; ending the worker leaves the page's stream pending" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try run(browser,
                \\globalThis.result = 'pending';
                \\const code = 'onmessage = event => postMessage(event.data, [event.data]);';
                \\const worker = new Worker(URL.createObjectURL(new Blob([code], { type: 'text/javascript' })));
                \\let controller;
                \\const original = new ReadableStream({ start(c) { controller = c; } });
                \\worker.onmessage = async event => {
                \\  const reader = event.data.getReader();
                \\  const out = [];
                \\  for (let i = 0; i < 3; ++i) {
                \\    controller.enqueue(i);
                \\    out.push((await reader.read()).value);
                \\  }
                \\  worker.terminate();
                \\  for (let i = 3; i < 6; ++i) controller.enqueue(i);
                \\  reader.read().then(() => { result = 'read after terminate'; }, () => { result = 'rejected after terminate'; });
                \\  setTimeout(() => { if (result === 'pending') result = out.join(); }, 50);
                \\};
                \\worker.postMessage(original, [original]);
            );
            try waitFor(browser, "result !== 'pending'");
            try expectString(browser, "result", "0,1,2");
        }
    }.body);
}

test "a transferred stream nobody holds is collected with its ports once it closes" {
    try withPage(struct {
        fn body(browser: *browser_mod.Browser) !void {
            try run(browser,
                \\globalThis.done = false;
                \\globalThis.refs = [];
                \\(() => {
                \\  const original = new ReadableStream({ start(c) { c.enqueue(1); c.close(); } });
                \\  const received = structuredClone(original, { transfer: [original] });
                \\  refs.push(new WeakRef(original), new WeakRef(received));
                \\  const reader = received.getReader();
                \\  reader.read().then(() => reader.read()).then(() => { done = true; });
                \\})();
            );
            try waitFor(browser, "done");
            // The pipe ends and both ports are disentangled by the close:
            // nothing keeps either stream. (A deref keeps its target to the
            // end of the job, so each check is followed by a collection.)
            for (0..50) |_| {
                _ = try browser.runEventLoopBlocking(2);
                try collect(browser);
                if (try truthy(browser, "refs.every(ref => ref.deref() === undefined)")) return;
            }
            return error.NotCollected;
        }
    }.body);
}
