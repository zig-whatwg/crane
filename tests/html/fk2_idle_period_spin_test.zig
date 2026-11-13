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
//! empty periods filled) and a fetch in flight to a socket that never answers
//! (the loop's 1 ms slices). Every idle period that starts must run a
//! callback: an empty one is the spin.
//!
//! Each test runs on a thread of its own (a Browser per thread).
const std = @import("std");
const clock = @import("clock");
const helpers = @import("edges_node_holders_helpers.zig");

fn idlePeriodsRunTheirCallbacks() !void {
    // A listener nobody accepts from: the kernel completes the handshake and
    // the request waits in its buffer, so the fetch stays in flight.
    const address: std.Io.net.IpAddress = .{ .ip4 = std.Io.net.Ip4Address.loopback(0) };
    var server = try address.listen(std.testing.io, .{ .reuse_address = true });
    defer server.deinit(std.testing.io);
    const port = server.socket.address.getPort();

    const page = try helpers.Page.open();
    defer page.close();
    var script_buffer: [1024]u8 = undefined;
    const script = try std.fmt.bufPrint(&script_buffer,
        \\globalThis.idleRuns = 0;
        \\globalThis.stopIdle = false;
        \\(function again() {{ requestIdleCallback(() => {{ idleRuns++; if (!stopIdle) again(); }}); }})();
        \\globalThis.ticker = setInterval(() => {{}}, 4);
        \\fetch('http://127.0.0.1:{d}/never').catch(() => {{}});
    , .{port});
    try page.run(script);

    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const periods_before = loop.idle_period_id;
    var turns: usize = 0;
    const start = clock.monotonicMillis();
    while (clock.monotonicMillis() - start < 300) : (turns += 1) {
        _ = loop.runOnceBlocking(5);
    }
    const periods = loop.idle_period_id - periods_before;
    try page.run("stopIdle = true; clearInterval(ticker);");

    const runs_text = try page.evaluate("String(idleRuns)");
    defer std.testing.allocator.free(runs_text);
    const runs = try std.fmt.parseInt(u64, runs_text, 10);
    // The callbacks ran: idle periods still start between the ticks.
    try std.testing.expect(runs >= 10);
    // One callback per period (each asks again, and runs in the next one);
    // the last period may still be waiting for its task.
    if (periods > runs + 1) {
        std.debug.print("idle periods {d}, callbacks {d}, loop turns {d} in 300 ms: empty idle periods\n", .{ periods, runs, turns });
        return error.EmptyIdlePeriods;
    }
}

test "every idle period that starts runs an idle callback (no empty periods spinning)" {
    try helpers.onFreshThread(idlePeriodsRunTheirCallbacks);
}
