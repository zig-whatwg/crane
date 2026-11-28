//! Lane mcp2, batch 4b item 6: EventLoop CPU throttling unit & Browser tests.
//!
//! Verifies:
//! - Default rate is 1.0 (unthrottled); `setCpuThrottlingRate` clamps <= 1.0
//!   and NaN to 1.0 and clears residual debt.
//! - Multi-task work is slowed proportionally by `rate`, while bursts of tiny
//!   sub-millisecond tasks accumulate debt instead of multiplying OS sleep
//!   granularity.
//! - A real Browser's JS `setTimeout` chain reflects throttling and restores
//!   normal speed when reset to 1.0.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;

fn realNs() i64 {
    return @intCast(platform.monotonicNow().ns);
}

fn spinNs(duration_ns: i64) void {
    const start = realNs();
    while (realNs() - start < duration_ns) {}
}

test "EventLoop setCpuThrottlingRate defaults to 1.0 and clamps <= 1.0 and NaN" {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;

    try testing.expectEqual(@as(f64, 1.0), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(4.0);
    try testing.expectEqual(@as(f64, 4.0), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(2.5);
    try testing.expectEqual(@as(f64, 2.5), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(0.5);
    try testing.expectEqual(@as(f64, 1.0), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(3.0);
    loop.setCpuThrottlingRate(-1.0);
    try testing.expectEqual(@as(f64, 1.0), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(3.0);
    loop.setCpuThrottlingRate(0.0);
    try testing.expectEqual(@as(f64, 1.0), loop.cpuThrottlingRate());
    loop.setCpuThrottlingRate(3.0);
    loop.setCpuThrottlingRate(std.math.nan(f64));
    try testing.expectEqual(@as(f64, 1.0), loop.cpuThrottlingRate());
}

test "EventLoop CPU throttling slows queued tasks proportionally and accumulates sub-ms debt" {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    const loop = browser.event_loop orelse return error.NoEventLoop;

    const SpinTask = struct {
        spin_ns: i64,
        ran: usize = 0,
        fn run(ctx: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            spinNs(self.spin_ns);
            self.ran += 1;
        }
    };

    // Baseline: 5 tasks x 5 ms = 25 ms work at rate 1.0.
    var work: SpinTask = .{ .spin_ns = 5 * std.time.ns_per_ms };
    for (0..5) |_| loop.eventLoop().queueTask(.{ .callback = &SpinTask.run, .context = &work });
    const t0 = realNs();
    _ = loop.runOnceBlocking(0);
    const base_ns = realNs() - t0;
    try testing.expectEqual(@as(usize, 5), work.ran);
    try testing.expect(base_ns >= 20 * std.time.ns_per_ms);

    // Throttled 4x: 25 ms work + 75 ms throttle sleep = ~100 ms.
    loop.setCpuThrottlingRate(4.0);
    work.ran = 0;
    for (0..5) |_| loop.eventLoop().queueTask(.{ .callback = &SpinTask.run, .context = &work });
    const t1 = realNs();
    _ = loop.runOnceBlocking(0);
    const throttled_ns = realNs() - t1;
    try testing.expectEqual(@as(usize, 5), work.ran);
    try testing.expect(throttled_ns >= 85 * std.time.ns_per_ms);
    try testing.expect(throttled_ns >= base_ns * 2);

    // Burst of 50 tiny 200 us tasks (10 ms total work) at 4x: ~40 ms total,
    // confirming debt accumulation avoids sleeping once per microsecond task.
    var tiny: SpinTask = .{ .spin_ns = 200 * std.time.ns_per_us };
    for (0..50) |_| loop.eventLoop().queueTask(.{ .callback = &SpinTask.run, .context = &tiny });
    const t2 = realNs();
    _ = loop.runOnceBlocking(0);
    const tiny_ns = realNs() - t2;
    try testing.expectEqual(@as(usize, 50), tiny.ran);
    try testing.expect(tiny_ns >= 28 * std.time.ns_per_ms);

    // Reset to 1.0: debt cleared and speed restored.
    loop.setCpuThrottlingRate(1.0);
    work.ran = 0;
    for (0..5) |_| loop.eventLoop().queueTask(.{ .callback = &SpinTask.run, .context = &work });
    const t3 = realNs();
    _ = loop.runOnceBlocking(0);
    const reset_ns = realNs() - t3;
    try testing.expectEqual(@as(usize, 5), work.ran);
    try testing.expect(reset_ns * 2 <= throttled_ns + 15 * std.time.ns_per_ms);
}

test "Browser JS setTimeout chain slows under EventLoop CPU throttling and restores at rate 1.0" {
    const browser = try Browser.init(testing.allocator, .{ .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("data:text/html,<title>T</title>", .window);
    const loop = browser.event_loop orelse return error.NoEventLoop;

    const run_chain =
        \\window.__done = false;
        \\window.__elapsed = 0;
        \\(() => {
        \\  const start = performance.now();
        \\  let n = 0;
        \\  function step() {
        \\    const t = performance.now();
        \\    while (performance.now() - t < 8) {}
        \\    if (++n < 5) {
        \\      setTimeout(step, 0);
        \\    } else {
        \\      // Measure in a follow-up macrotask so the 5th step's throttle
        \\      // sleep has also elapsed (5 * 32 ms = ~160 ms at 4x vs ~40 ms at 1x).
        \\      setTimeout(() => {
        \\        window.__elapsed = performance.now() - start;
        \\        window.__done = true;
        \\      }, 0);
        \\    }
        \\  }
        \\  setTimeout(step, 0);
        \\})();
    ;

    const ctx = browser.current_context orelse return error.NoContext;
    const Wait = struct {
        c: @TypeOf(ctx),
        fn met(ptr: ?*anyopaque) bool {
            const self: *@This() = @ptrCast(@alignCast(ptr.?));
            const res = self.c.evaluateScriptToString("window.__done === true", testing.allocator) catch return false;
            defer testing.allocator.free(res);
            return std.mem.eql(u8, res, "true");
        }
    };
    var wait: Wait = .{ .c = ctx };

    // Warm up V8/timers (especially under TSan) so baseline does not include
    // cold script compilation latency.
    const rw = try ctx.evaluateScriptToString(run_chain, testing.allocator);
    testing.allocator.free(rw);
    _ = try browser.spinEventLoopUntil(.{ .context = &wait, .met = Wait.met }, 5_000);

    // Unthrottled baseline: ~40 ms.
    const r0 = try ctx.evaluateScriptToString(run_chain, testing.allocator);
    testing.allocator.free(r0);
    _ = try browser.spinEventLoopUntil(.{ .context = &wait, .met = Wait.met }, 5_000);
    const base_str = try ctx.evaluateScriptToString("String(window.__elapsed)", testing.allocator);
    defer testing.allocator.free(base_str);
    const base_ms = try std.fmt.parseFloat(f64, base_str);
    try testing.expect(base_ms >= 30.0);

    // 4x throttled: ~160 ms.
    loop.setCpuThrottlingRate(4.0);
    const r1 = try ctx.evaluateScriptToString(run_chain, testing.allocator);
    testing.allocator.free(r1);
    _ = try browser.spinEventLoopUntil(.{ .context = &wait, .met = Wait.met }, 5_000);
    const thr_str = try ctx.evaluateScriptToString("String(window.__elapsed)", testing.allocator);
    defer testing.allocator.free(thr_str);
    const thr_ms = try std.fmt.parseFloat(f64, thr_str);
    try testing.expect(thr_ms >= 130.0);
    try testing.expect(thr_ms >= base_ms * 2.0);

    // Restored to 1.0. A loaded host can only lengthen a chain (a TSan verify
    // on server1 at load 29 read 41.9 ms unthrottled, 170.6 ms at 4x and 193.8
    // ms restored, lane mcp3 2026-11-27), so the restored chain gets up to
    // three tries: a throttle left on would slow every one of them.
    loop.setCpuThrottlingRate(1.0);
    var rst_ms: f64 = std.math.inf(f64);
    var tries: u32 = 0;
    while (tries < 3 and !(rst_ms < thr_ms * 0.75)) : (tries += 1) {
        const r2 = try ctx.evaluateScriptToString(run_chain, testing.allocator);
        testing.allocator.free(r2);
        _ = try browser.spinEventLoopUntil(.{ .context = &wait, .met = Wait.met }, 5_000);
        const rst_str = try ctx.evaluateScriptToString("String(window.__elapsed)", testing.allocator);
        defer testing.allocator.free(rst_str);
        rst_ms = @min(rst_ms, try std.fmt.parseFloat(f64, rst_str));
    }
    if (!(rst_ms < thr_ms * 0.75)) std.debug.print("chain: unthrottled {d:.1} ms, 4x {d:.1} ms, restored (best of {d}) {d:.1} ms\n", .{ base_ms, thr_ms, tries, rst_ms });
    try testing.expect(rst_ms < thr_ms * 0.75);
}

// Lane mcp3, batch B (audit report C, M5): the throttle's debt is no longer
// one blocking sleep of up to 10 s on the Browser's thread. It is a wait in
// which other threads' posts - a DevTools session's message, the host's
// stop - are served, the rest of the debt carried to the next task: Chrome's
// ThreadCPUThrottler suspends the renderer's main thread in slices while
// V8 still serves the inspector's interrupting tasks
// (third_party/blink/renderer/platform/scheduler/common/thread_cpu_throttler.cc;
// core/inspector/inspector_task_runner.cc).

/// A task that turns the throttle to `rate` and runs `spin_ns` of work: the
/// loop then owes (rate - 1) x spin_ns.
const ThrottledWork = struct {
    rate: f64,
    spin_ns: i64,
    done_at: std.atomic.Value(i64) = .init(0),

    /// The rate, set by a task of its own: the loop decides whether a posted
    /// task is throttled before it runs it (runOnePosted), so the work must
    /// come in the next one.
    fn setRate(ctx: ?*anyopaque, b: *Browser) void {
        const self: *ThrottledWork = @ptrCast(@alignCast(ctx.?));
        if (b.event_loop) |loop| loop.setCpuThrottlingRate(self.rate);
    }

    fn run(ctx: ?*anyopaque, b: *Browser) void {
        _ = b;
        const self: *ThrottledWork = @ptrCast(@alignCast(ctx.?));
        spinNs(self.spin_ns);
        self.done_at.store(realNs(), .release);
    }

    /// Post the rate, then the work.
    fn post(self: *ThrottledWork, host: *browser_mod.BrowserHost) bool {
        return host.post(self, setRate, drop) and host.post(self, run, drop);
    }

    fn drop(ctx: ?*anyopaque) void {
        _ = ctx;
    }

    /// Wait (on this thread) until the work has run, then a little more, so
    /// the Browser's thread is paying the debt.
    fn waitDone(self: *ThrottledWork) !void {
        const deadline = realNs() + 5 * std.time.ns_per_s;
        while (self.done_at.load(.acquire) == 0) {
            if (realNs() > deadline) return error.WorkNeverRan;
            platform.sleepThread(std.time.ns_per_ms);
        }
        platform.sleepThread(50 * std.time.ns_per_ms);
    }
};

test "CPU throttling: a session message posted while the loop pays a 3.8 s debt runs at once, not after the debt" {
    const host = try browser_mod.BrowserHost.start(testing.allocator, .{ .snapshot_path = "" });
    defer host.stop();
    // 200 ms of work at 20x: 3.8 s owed.
    var work: ThrottledWork = .{ .rate = 20.0, .spin_ns = 200 * std.time.ns_per_ms };
    try testing.expect(work.post(host));
    try work.waitDone();

    const Message = struct {
        ran_at: std.atomic.Value(i64) = .init(0),
        fn run(ctx: ?*anyopaque, b: *Browser) void {
            _ = b;
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            self.ran_at.store(realNs(), .release);
        }
        fn drop(ctx: ?*anyopaque) void {
            _ = ctx;
        }
    };
    var message: Message = .{};
    const posted_at = realNs();
    try testing.expect(host.postSessionMessage(&message, Message.run, Message.drop));
    const deadline = posted_at + 5 * std.time.ns_per_s;
    while (message.ran_at.load(.acquire) == 0 and realNs() < deadline) platform.sleepThread(std.time.ns_per_ms);
    const latency_ms = @divTrunc(message.ran_at.load(.acquire) - posted_at, std.time.ns_per_ms);
    if (message.ran_at.load(.acquire) == 0 or latency_ms > 1_000) {
        std.debug.print("session message ran {d} ms after it was posted (debt 3,800 ms)\n", .{latency_ms});
        return error.SessionMessageWaitedForTheDebt;
    }
}

test "CPU throttling: stopping the host while the loop pays a 3.8 s debt returns at once" {
    const host = try browser_mod.BrowserHost.start(testing.allocator, .{ .snapshot_path = "" });
    var work: ThrottledWork = .{ .rate = 20.0, .spin_ns = 200 * std.time.ns_per_ms };
    try testing.expect(work.post(host));
    work.waitDone() catch |err| {
        host.stop();
        return err;
    };
    const t0 = realNs();
    host.stop();
    const stop_ms = @divTrunc(realNs() - t0, std.time.ns_per_ms);
    if (stop_ms > 1_000) {
        std.debug.print("host.stop() took {d} ms during a 3,800 ms debt\n", .{stop_ms});
        return error.StopWaitedForTheDebt;
    }
}
