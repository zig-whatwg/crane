//! An EventTarget made in a dedicated worker is made with its Browser's
//! allocator - the allocator its scope frees with (lane perf2 batch 6, before
//! EventTarget's state loses its allocator copy: the integrator's condition,
//! design b5 3.5, "EventTarget's goes ONLY if the same assertion holds for
//! every chained EventTarget, workers' included").
//!
//! A worker's realm carries its owner's Browser scope (html.worker_host,
//! `recordRealm`), and the identity is asserted where every chained
//! EventTarget is made (EventTarget's initOwn): a worker target made with
//! another allocator stops the test there. The worker makes targets of
//! several kinds - an EventTarget, an AbortSignal, MessagePorts, its own
//! global scope - adds, fires and removes listeners and event handlers on
//! them, and ends with the Browser; the leak-checking test allocator then
//! finds everything freed through the allocator that made it.

const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;

fn round() !void {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigateWithOptions("about:blank", .window, .{ .skip_load = true });
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body>", .{ .base_url = "about:blank" });
    try page.runScript(
        \\globalThis.state = 'pending';
        \\const source = `
        \\  let fired = 0;
        \\  const target = new EventTarget();
        \\  const listener = () => { fired++; };
        \\  target.addEventListener('ping', listener);
        \\  target.dispatchEvent(new Event('ping'));
        \\  target.removeEventListener('ping', listener);
        \\  target.dispatchEvent(new Event('ping'));
        \\  const controller = new AbortController();
        \\  controller.signal.onabort = () => { fired++; };
        \\  controller.abort();
        \\  const channel = new MessageChannel();
        \\  channel.port1.addEventListener('message', () => {});
        \\  channel.port2.onmessage = () => {};
        \\  self.addEventListener('error', () => {});
        \\  postMessage('ok ' + fired);
        \\`;
        \\const worker = new Worker(URL.createObjectURL(new Blob([source], { type: 'text/javascript' })));
        \\worker.onmessage = e => { state = e.data; };
        \\worker.onerror = e => { state = 'worker error ' + (e.message || ''); };
    );
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        const state = try page.evaluateScriptToString("state", testing.allocator);
        defer testing.allocator.free(state);
        if (std.mem.eql(u8, state, "pending")) continue;
        try testing.expectEqualStrings("ok 2", state);
        return;
    }
    return error.WorkerDidNotAnswer;
}

/// A whole Browser on a thread of its own: tests/html is one executable, and a
/// fresh thread has no per-thread state another test left.
fn onFreshThread() !void {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, struct {
        fn run(out: *anyerror!void) void {
            round() catch |err| {
                out.* = err;
            };
        }
    }.run, .{&result});
    thread.join();
    try result;
}

test "EventTargets a dedicated worker makes are made with their Browser's allocator and freed through it" {
    try onFreshThread();
}
