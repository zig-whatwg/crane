//! Lane flaky2: an idle period starts only when it can last (Blink's
//! IdleHelper never starts one shorter than kMinimumIdlePeriodDuration, 1 ms,
//! and retries after the next wake-up). Crane started one whenever the last
//! had ended, with computeDeadline's next-timer bound read in whole
//! milliseconds: a timer due in under a millisecond made a period that was
//! over when it began. Its "invoke idle callbacks" task found now >= deadline,
//! ran nothing and asked again - a new empty period every turn until the
//! timer fired, about 100 a millisecond (found by lane flaky3 with a fetch in
//! flight).
//!
//! The page here keeps an idle callback waiting (each callback asks again),
//! a 4 ms interval (whose last millisecond before each tick is the window the
//! empty periods filled) and a fetch in flight to a socket that never answers.
//! It drives a virtual clock explicitly in 100 us sub-millisecond steps over
//! 200 ms (50 interval ticks): because the fetch stays in flight, EventLoop's
//! own auto-fast-forward stays off, so every interval tick leaves a 0.9 ms
//! sub-millisecond remainder where nextTimerDueNs rounds down to 0 ms, while
//! wall-clock OS preemption (which legitimately expires a real-time 1-3 ms
//! idle period between startIdlePeriod and InvokeIdleCallbacks on a loaded
//! host or under ThreadSanitizer) can never cause a spurious empty period.
//!
//! Each test runs on a thread of its own (a Browser per thread).
const std = @import("std");
const browser_mod = @import("browser");
const helpers = @import("edges_node_holders_helpers.zig");

fn idlePeriodsRunTheirCallbacks() !void {
    // A listener nobody accepts from: the kernel completes the handshake and
    // the request waits in its buffer, so the fetch stays in flight.
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
    var server = try address.listen(std.testing.io, .{ .reuse_address = true });
    defer server.deinit(std.testing.io);
    const port = server.socket.address.getPort();

    const browser = try browser_mod.Browser.init(std.testing.allocator, .{
        .snapshot_path = "",
        .platform = .{ .virtual_clock = true },
    });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });

    var script_buffer: [1024]u8 = undefined;
    const script = try std.fmt.bufPrint(&script_buffer,
        \\globalThis.idleRuns = 0;
        \\globalThis.stopIdle = false;
        \\(function again() {{ requestIdleCallback(() => {{ idleRuns++; if (!stopIdle) again(); }}); }})();
        \\globalThis.ticker = setInterval(() => {{}}, 4);
        \\fetch('http://127.0.0.1:{d}/never').catch(() => {{}});
    , .{port});
    try page.runScript(script);

    const loop = browser.event_loop orelse return error.NoEventLoop;
    const periods_before = loop.idle_period_id;
    const step_ns: i64 = 100 * std.time.ns_per_us;
    var virtual_now: i64 = loop.nowNs();
    var turns: usize = 0;
    for (0..2000) |_| {
        virtual_now += step_ns;
        _ = loop.browser_clock.maybeFastForwardToWakeUp(.{ .ns = @intCast(virtual_now) });
        turns += 1;
        _ = loop.runOnceBlocking(0);
    }
    const periods = loop.idle_period_id - periods_before;
    try page.runScript("stopIdle = true; clearInterval(ticker);");

    const runs_text = try page.evaluateScriptToString("String(idleRuns)", std.testing.allocator);
    defer std.testing.allocator.free(runs_text);
    const runs = try std.fmt.parseInt(u64, runs_text, 10);
    // The callbacks ran: idle periods still start between the ticks.
    try std.testing.expect(runs >= 10);
    // One callback per period (each asks again, and runs in the next one);
    // the last period may still be waiting for its task.
    if (periods > runs + 1) {
        std.debug.print("idle periods {d}, callbacks {d}, loop turns {d} over 200 ms virtual time: empty idle periods\n", .{ periods, runs, turns });
        return error.EmptyIdlePeriods;
    }
}

test "every idle period that starts runs an idle callback (no empty periods spinning)" {
    try helpers.onFreshThread(idlePeriodsRunTheirCallbacks);
}
