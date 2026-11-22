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
//! timers that came due. Pinned here: a reply reaches an idle window through
//! that wait, and never waits for the window's next timer; a timer still
//! fires at its deadline when nothing is posted; the loop waits through a
//! timer's last sub-millisecond instead of turning until it is due; a timer
//! armed by a timer's callback waits for the next turn, behind the tasks that
//! callback queued; and a burst of posts does not leave the loop spinning.
//! Counts and order, never a bound in milliseconds on a wake: how soon a
//! woken thread runs is the host's (docs/lessons/
//! testing-a-lateness-bound-in-milliseconds-measures-the-hosts-scheduler.md).
//!
//! Each test runs a whole Browser on a thread of its own, on
//! std.testing.allocator.

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const clock = @import("clock");
const helpers = @import("edges_node_holders_helpers.zig");

fn openPage() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
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

/// How far away the timer is that a reply must not wait for.
const later_timer_ms = 10_000;

fn replyReachesIdleWindow() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const loop = browser.event_loop orelse return error.NoLoop;
    // An echo worker; each ping waits for the window loop to go idle first
    // (a 3 ms timer), so the reply lands while the window waits. With each
    // ping the page arms a timer ten seconds away: the window's next timer
    // while it waits for the reply.
    try page.runScript(std.fmt.comptimePrint(
        \\globalThis.replies = 0;
        \\globalThis.waitedForATimer = 0;
        \\globalThis.done = 0;
        \\const w = new Worker('data:text/javascript,onmessage%20%3D%20e%20%3D%3E%20postMessage(e.data)');
        \\(async () => {{
        \\  await new Promise(r => {{ w.onmessage = r; w.postMessage(-1); }});
        \\  for (let i = 0; i < 40; i++) {{
        \\    await new Promise(r => setTimeout(r, 3));
        \\    const e = await new Promise(r => {{
        \\      const later = setTimeout(() => {{ waitedForATimer++; }}, {d});
        \\      w.onmessage = e => {{ clearTimeout(later); r(e); }};
        \\      w.postMessage(i);
        \\    }});
        \\    if (e.data === i) replies++;
        \\  }}
        \\  w.terminate();
        \\  done = 1;
        \\}})();
    , .{later_timer_ms}));
    const waits_before = loop.sink.probe.waits;
    // One long run: the test's own checks between turns stay out of the
    // round trips. It ends when the worker has ended and no timer is left.
    _ = try browser.runEventLoopBlocking(4 * later_timer_ms);
    try runUntil(browser, "done");
    const waits = loop.sink.probe.waits - waits_before;
    const replies = try evalNumber(browser, "replies");
    const waited_for_a_timer = try evalNumber(browser, "waitedForATimer");
    // What the loop decides, not what the host's scheduler does:
    // - every reply is handled, as a task of the window's loop;
    // - none waits for the window's next timer: the loop wakes for a post,
    //   and the timer it would otherwise have slept to is ten seconds away
    //   (forty of them would be 400 s; the run's bound is 40 s);
    // - the idle window WAITS ON ITS SINK (TaskSink.waitForWork, which a post
    //   ends: tests/runtime/task_sink_test.zig "a post wakes a loop waiting
    //   with no timeout") - at least once for each of the forty round trips.
    //   The timer backend's sleep, which no post wakes, made none.
    //
    // This test compared times: the third quartile of the leg back to the
    // window against twice the leg to the worker plus 0.25 ms. That held on
    // a quiet host (0.125 ms each way on server1) and failed in four lanes'
    // gates in one day (to the worker 0.375 ms, back 1.6 to 1.75 ms), and 33
    // runs of 50 on server1 at nice 10 on four CPUs beside four nice-0 busy
    // loops (to the worker 1 ms, back 8). Two causes, measured apart with
    // the sink's wait instrumented (lane flk2, 2026-11-16). The first was the
    // loop's own: it turned without a wait through the last sub-millisecond
    // before each round's 3 ms timer, and the scheduler ran the window
    // thread late for it (the test below, which now pins that it waits). The
    // second is nobody's: with that gone the comparison still failed 1 run
    // of 3 at that load, on the scheduler's tails alone (the medians 0.125 ms
    // each way, the window's third quartile 2.75 ms). Each leg is the time
    // the kernel takes to run a thread it has woken - the wait returned 2 to
    // 22 us after the post on the quiet host and whole milliseconds after it
    // on the loaded one - and no bound on that holds on every host.
    try testing.expectEqual(@as(f64, 40), replies);
    try testing.expectEqual(@as(f64, 0), waited_for_a_timer);
    if (waits < 40) {
        std.log.warn("the window's loop waited on its sink {d} times over forty round trips", .{waits});
        return error.LoopDidNotWaitOnItsSink;
    }
}

test "a worker's reply reaches an idle window without waiting for its next timer: the window's loop waits on its task sink" {
    try helpers.onFreshThread(replyReachesIdleWindow);
}

/// The bound the caller gives the one long run of `timerFiresAtItsDeadline`.
const timer_run_bound_ms = 10_000;

fn timerFiresAtItsDeadline() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    // Nothing is posted: only a timer's deadline can end the loop's wait
    // before the caller's bound does. Ten 20 ms timers, one after the other;
    // then three armed latest first, which are due earliest first.
    try page.runScript(
        \\globalThis.lateness = [];
        \\globalThis.order = [];
        \\globalThis.done = 0;
        \\(async () => {
        \\  for (let i = 0; i < 10; i++) {
        \\    const t0 = performance.now();
        \\    await new Promise(r => setTimeout(r, 20));
        \\    lateness.push(performance.now() - t0 - 20);
        \\  }
        \\  const t0 = performance.now();
        \\  await Promise.all([60, 20, 40].map(ms => new Promise(r => setTimeout(() => {
        \\    order.push(ms);
        \\    lateness.push(performance.now() - t0 - ms);
        \\    r();
        \\  }, ms))));
        \\  done = 1;
        \\})();
    );
    // One long run, bounded far past every deadline (the timers take 260 ms
    // in all): a wait that ended at the caller's bound instead of a timer's
    // deadline would fire that timer ten seconds late.
    _ = try browser.runEventLoopBlocking(timer_run_bound_ms);
    try runUntil(browser, "done");
    const worst = try evalNumber(browser, "Math.max(...lateness)");
    const earliest = try evalNumber(browser, "Math.min(...lateness)");
    const order = try page.evaluateScriptToString("order.join()", testing.allocator);
    defer testing.allocator.free(order);
    // Order and the mechanism, not the host's scheduler:
    // - no timer fires before its deadline (0.1 ms: the coarse clock's tick
    //   is 0.125 ms and both readings are floored onto it);
    // - the wait ends at the EARLIEST deadline, whichever timer was armed
    //   first: 20, 40, 60;
    // - a timer fires at its deadline and not at the caller's bound - the
    //   two are ten seconds apart, and half of that is the line between
    //   them.
    //
    // The last was `worst < 5` (ms), which measured how soon the host ran a
    // thread it had just woken, not the loop. It failed three gates in one
    // day, 5.9 ms late each time, on server1 under a 32-runner WPT sweep with
    // the tests at nice 10 (the pool's build shim). Measured there with the
    // loop's step 4 instrumented (lane flk1, 2026-11-15; the test at nice 10
    // on four CPUs beside four, then eight, nice-0 busy loops on the same
    // four): every timer that fired 2 ms late or more - 2 of 100 with four
    // busy loops, 17 of 100 with eight, up to 12 ms - fired straight after a
    // wait the loop had asked to last 1 ms and the kernel returned 5.6 to
    // 29 ms later, in a turn that did nothing else (60 us at most from its
    // start to the wait). The old assertion failed 3 runs of 6 with eight
    // busy loops and 0 of 82 with four or three; beside a real 32-runner
    // sweep the worst of 3,600 timers was 3.4 ms. On macOS the same 1 ms
    // wait measured 1.25 ms, and timers were up to 2 ms late with nothing
    // else running. A timer is as late as the wait before it was long, and
    // how long a 1 ms wait is belongs to the host: no bound in milliseconds
    // holds on all of them.
    try testing.expectEqualStrings("20,40,60", order);
    if (!(earliest >= -0.1 and worst < timer_run_bound_ms / 2)) {
        std.log.warn("timer lateness: earliest {d:.3} ms, worst {d:.3} ms", .{ earliest, worst });
        return error.TimerNotAtItsDeadline;
    }
}

test "a timer fires at its deadline - never before it, earliest first, and not at the caller's bound - while nothing is posted to the window" {
    try helpers.onFreshThread(timerFiresAtItsDeadline);
}

fn loopWaitsThroughATimersLastMillisecond() !void {
    const browser = try openPage();
    defer browser.deinit();
    const page = browser.current_context orelse return error.NoPage;
    const loop = browser.event_loop orelse return error.NoLoop;
    const timers = loop.timer_manager orelse return error.NoTimers;
    // Forty 3 ms timers, one after the other, and nothing else to do.
    try page.runScript(
        \\globalThis.done = 0;
        \\(async () => {
        \\  for (let i = 0; i < 40; i++) await new Promise(r => setTimeout(r, 3));
        \\  done = 1;
        \\})();
    );
    const polls_before = timers.probe.polls;
    // One long run: it ends when the last timer has fired and nothing is
    // left pending.
    _ = try browser.runEventLoopBlocking(timer_run_bound_ms);
    const polls = timers.probe.polls - polls_before;
    try runUntil(browser, "done");
    // A count, not a time. Every turn of the loop polls its timers once, and
    // a second time after a wait (event_loop.zig step 4). A loop that WAITS
    // for a 3 ms timer makes at most three waits of a millisecond and one
    // shorter wait to the deadline itself: four turns, eight polls, for each
    // timer, and a turn or two more for the callback's task. `poll_bound`
    // allows ten turns a timer.
    //
    // The loop used to count the time to the next timer in whole
    // milliseconds, rounded down, and take "under a millisecond" for
    // "nothing to wait for": it waited 2 of a timer's 3 ms and turned without
    // a wait through the rest - 510 turns and 0.85 ms of the window thread's
    // CPU for each timer on server1 (25,194 turns over forty timers against
    // 4,791 with the wait), 3,300 polls for this test on macOS.
    //
    // That is not only heat: a thread that has just burned a millisecond is
    // the one a busy host's scheduler runs last. Measured on server1 (lane
    // flk2, 2026-11-16; at nice 10 on four CPUs beside four nice-0 busy
    // loops). Two plain threads passed a task back and forth over two sinks.
    // The one that turned without a wait before each round, as the loop did,
    // had its wait returned 7.0 ms (median) after the post that ended it;
    // the other's returned after 1.0 ms. When the first waited to the exact
    // moment instead, its wait returned 1 to 11 us after the post. In the
    // window's loop the same: a worker's reply to a message that a timer's
    // callback had sent ended the window's wait 7.9 ms late (0.02 to 0.5 ms
    // with the loop waiting for the timer), which is what failed the first
    // test of this file in four lanes' gates in one day.
    const poll_bound = 40 * 10 * 2;
    if (polls > poll_bound) {
        std.log.warn("{d} timer polls for forty 3 ms timers (at most {d} when the loop waits for each)", .{ polls, poll_bound });
        return error.LoopTurnsWithoutWaiting;
    }
}

test "the window's loop waits through a timer's last sub-millisecond: it does not turn without a wait until the timer is due" {
    try helpers.onFreshThread(loopWaitsThroughATimersLastMillisecond);
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
