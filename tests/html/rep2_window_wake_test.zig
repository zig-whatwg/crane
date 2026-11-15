//! Lane rep2: a window's event loop, idle, wakes as soon as another thread
//! posts to it.
//!
//! A worker's message reaches its Worker through the window loop's task sink
//! (runtime.TaskSink, which a post signals). The window loop's idle wait was
//! the timer backend's plain sleep in 1 ms slices (native_timer.zig
//! pollBlockingEach), which no post wakes, so a worker's reply waited up to a
//! slice before its task ran: perf_bench's workers.start-stop measured
//! 3.29 -> 4.61 ms per worker once a worker's script no longer blocked its
//! owner (lane rep2, cost pairs #2 and #3). A worker's own loop already
//! waits on its sink (worker_event_loop.zig, TaskSink.waitForWork). The
//! window loop now waits there too, with the same bound, and then fires the
//! timers that came due. Pinned here: a reply reaches an idle window at once;
//! a timer still fires on time when nothing is posted; a timer armed by a
//! timer's callback waits for the next turn, behind the tasks that callback
//! queued; and a burst of posts does not leave the loop spinning.
//!
//! Each test runs a whole Browser on a thread of its own, on
//! std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const clock = @import("clock");
const helpers = @import("edges_node_holders_helpers.zig");

fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    _ = try browser.runEventLoopBlocking(10);
    return browser;
}

fn evalNumber(browser: *browser_mod.Browser, script: []const u8) !f64 {
    const page = browser.current_context orelse return error.NoPage;
    const text = try page.evaluateScriptToString(script, testing.allocator);
    defer testing.allocator.free(text);
    return std.fmt.parseFloat(f64, text);
}

/// Run the loop until `done` (a page expression) is true, at most 5 s.
fn runUntil(browser: *browser_mod.Browser, done: []const u8) !void {
    for (0..500) |_| {
        _ = try browser.runEventLoopBlocking(10);
        if (try evalNumber(browser, done) != 0) return;
    }
    return error.NeverDone;
}

fn replyReachesIdleWindow() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // An echo worker; each ping waits for the window loop to go idle first
    // (a 3 ms timer), so the reply lands while the window waits.
    try page.runScript(
        \\globalThis.rtts = [];
        \\globalThis.legs = [];
        \\globalThis.done = 0;
        \\const keepAlive = setTimeout(() => {}, 60000);
        \\const w = new Worker('data:text/javascript,onmessage%20%3D%20e%20%3D%3E%20postMessage(%5Be.data%2C%20performance.timeOrigin%20%2B%20performance.now()%5D)');
        \\(async () => {
        \\  await new Promise(r => { w.onmessage = r; w.postMessage(-1); });
        \\  for (let i = 0; i < 40; i++) {
        \\    await new Promise(r => setTimeout(r, 3));
        \\    const t0 = performance.now();
        \\    const sent = performance.timeOrigin + t0;
        \\    const e = await new Promise(r => { w.onmessage = r; w.postMessage(sent); });
        \\    const now = performance.now();
        \\    rtts.push(now - t0);
        \\    legs.push([e.data[1] - sent, performance.timeOrigin + now - e.data[1]]);
        \\  }
        \\  clearTimeout(keepAlive);
        \\  done = 1;
        \\})();
    );
    // One long run: the test's own checks between turns stay out of the
    // round trips (the keep-alive timer holds the loop until the end).
    _ = try browser.runEventLoopBlocking(5000);
    try runUntil(browser, "done");
    // The third quartiles. The leg back to the window is the window loop's
    // wake plus one message's way across threads; the leg to the worker is
    // the same way into a loop that already waits on its sink, so the two
    // match once the window waits on its sink too (chat2: 0.625 ms each; the
    // window leg was 9.1 ms against 0.5 ms to the worker with the timer
    // backend's sleep, the round trip 9.75 ms).
    const p75 = try evalNumber(browser, "rtts.slice().sort((a, b) => a - b)[Math.floor(rtts.length * 3 / 4)]");
    const to_worker = try evalNumber(browser, "legs.map(l => l[0]).sort((a, b) => a - b)[30]");
    const to_window = try evalNumber(browser, "legs.map(l => l[1]).sort((a, b) => a - b)[30]");
    // Compared with each other, not with a fixed time: a loaded host slows
    // both legs alike (1.6 ms each with the whole tests-html suite running).
    if (!(to_window <= to_worker * 2 + 0.25)) {
        std.log.warn("round trip p75 {d:.3} ms (to the worker {d:.3}, back to the window {d:.3})", .{ p75, to_worker, to_window });
        return error.ReplyLate;
    }
}

test "a worker's reply reaches an idle window at once: the window's loop waits on its task sink" {
    try helpers.onFreshThread(replyReachesIdleWindow);
}

fn timerFiresOnTime() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // Nothing is posted: the loop's wait ends at the timer's deadline.
    try page.runScript(
        \\globalThis.lateness = [];
        \\globalThis.done = 0;
        \\(async () => {
        \\  for (let i = 0; i < 10; i++) {
        \\    const t0 = performance.now();
        \\    await new Promise(r => setTimeout(r, 20));
        \\    lateness.push(performance.now() - t0 - 20);
        \\  }
        \\  done = 1;
        \\})();
    );
    try runUntil(browser, "done");
    const worst = try evalNumber(browser, "Math.max(...lateness)");
    const earliest = try evalNumber(browser, "Math.min(...lateness)");
    if (!(earliest >= -0.1 and worst < 5)) {
        std.log.warn("timer lateness: earliest {d:.3} ms, worst {d:.3} ms", .{ earliest, worst });
        return error.TimerNotOnTime;
    }
}

test "a timer still fires on time while nothing is posted to the window" {
    try helpers.onFreshThread(timerFiresOnTime);
}

fn timerArmedByATimerWaitsForTheNextTurn() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // AbortSignal.timeout's steps run in the timer's own callback (step 4).
    // The first one's abort listener queues a task - Permissions query step 8
    // queues its own - and arms a second 0 ms timeout, which is due at once.
    // The task was queued first, and runs first: the step that fired the
    // first timer fires nothing its callback armed
    // (permissions/event-model.https.html: test_driver.set_permission's 0 ms
    // timer, armed in a timer's callback, changed the permission before the
    // query's task made the status that listens for it, and the change event
    // never came).
    try page.runScript(
        \\globalThis.order = [];
        \\globalThis.done = 0;
        \\globalThis.first = AbortSignal.timeout(0);
        \\first.onabort = () => {
        \\  const note = () => order.push('task');
        \\  navigator.permissions.query({ name: 'geolocation' }).then(note, note);
        \\  globalThis.second = AbortSignal.timeout(0);
        \\  second.onabort = () => { order.push('timer'); done = 1; };
        \\};
    );
    try runUntil(browser, "done");
    _ = try browser.runEventLoopBlocking(10);
    const order = try page.evaluateScriptToString("order.join()", testing.allocator);
    defer testing.allocator.free(order);
    try testing.expectEqualStrings("task,timer", order);
}

test "a timer armed by a timer's callback fires on the next turn, after the tasks that callback queued" {
    try helpers.onFreshThread(timerArmedByATimerWaitsForTheNextTurn);
}

fn cpuMs() f64 {
    const usage = std.posix.getrusage(std.posix.rusage.SELF);
    const user: f64 = @as(f64, @floatFromInt(usage.utime.sec)) * 1000 + @as(f64, @floatFromInt(usage.utime.usec)) / 1000;
    const system: f64 = @as(f64, @floatFromInt(usage.stime.sec)) * 1000 + @as(f64, @floatFromInt(usage.stime.usec)) / 1000;
    return user + system;
}

fn burstLeavesLoopIdle() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // The worker posts 2,000 messages at once, then nothing.
    try page.runScript(
        \\globalThis.received = 0;
        \\const w = new Worker('data:text/javascript,for%20(let%20i%20%3D%200%3B%20i%20%3C%202000%3B%20i%2B%2B)%20postMessage(i)');
        \\w.onmessage = () => { received++; };
        \\globalThis.keep = w;
    );
    try runUntil(browser, "received === 2000 ? 1 : 0");
    // Then the window idles: its loop must wait, not spin on the sink.
    const cpu0 = cpuMs();
    const wall0 = clock.monotonicMillis();
    _ = try browser.runEventLoopBlocking(300);
    const wall_ms: f64 = @floatFromInt(clock.monotonicMillis() - wall0);
    const cpu = cpuMs() - cpu0;
    // Idle-level: well under a fifth of one core over the wait (every thread
    // of the process counted).
    if (!(wall_ms >= 250 and cpu < wall_ms / 5)) {
        std.log.warn("idle after the burst: {d:.1} ms CPU over {d:.1} ms", .{ cpu, wall_ms });
        return error.LoopNotIdle;
    }
}

test "a burst of posts from a worker does not leave the window's loop spinning once it has drained" {
    try helpers.onFreshThread(burstLeavesLoopIdle);
}
