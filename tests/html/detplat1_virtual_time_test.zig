//! Opt-in deterministic execution (the approved test plan, tmp/plans/
//! test-architecture-recommendation.md section 5; lane detplat1): a Browser
//! made with the testing platform's virtual clock and a random seed
//! (BrowserConfig.platform) runs its timers in virtual time - its clock
//! moves only when its event loop is idle and a timer is due (Chromium's
//! TaskEnvironment MOCK_TIME) - and replays Math.random from its seed, each
//! per Browser: two Browsers in one process keep their own clocks and
//! sequences. Real time and the engine's entropy stay the default.
const std = @import("std");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const html = @import("html");
const platform = @import("platform");

const is_testing = std.mem.eql(u8, platform.name, "testing");

fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

/// A Browser with the testing platform's options `options` (no snapshot, no
/// storage), on about:blank.
fn open(options: platform.PlatformBrowserOptions) !*Browser {
    return Browser.init(std.testing.allocator, .{ .persist_storage = false, .snapshot_path = "", .platform = options });
}

/// `script`'s completion value as a string, OWNED by the testing allocator.
fn evaluate(browser: *Browser, script: []const u8) ![]u8 {
    const page = browser.current_context orelse return error.NoPage;
    return page.evaluateScriptToString(script, std.testing.allocator);
}

/// Turn `browser`'s event loop until it has nothing left to do - which it
/// must reach: a loop still busy after a real minute fails the test (a
/// virtual clock that never lets an idle callback run spins exactly so).
fn runUntilIdle(browser: *Browser) !void {
    _ = try browser.runEventLoopBlocking(60_000);
    try std.testing.expect(!browser.event_loop.?.hasPendingWork());
}

/// A page that arms timers out of order - ties, a nested timer and one that
/// clears another included - and logs, at each callback, the time since it
/// began on both clocks and a Math.random draw.
const timer_page =
    \\globalThis.log = [];
    \\const t0 = performance.now(), d0 = Date.now();
    \\const note = (name) => log.push([name, performance.now() - t0, Date.now() - d0, Math.random()]);
    \\note('start');
    \\setTimeout(() => note('c30'), 30);
    \\setTimeout(() => note('a10'), 10);
    \\setTimeout(() => note('a10-tie'), 10);
    \\const dropped = setTimeout(() => note('never'), 15);
    \\setTimeout(() => { note('b20'); clearTimeout(dropped); setTimeout(() => note('b20+5'), 5); }, 20);
    \\setTimeout(() => clearTimeout(dropped), 12);
    \\requestIdleCallback(() => note('idle'));
    \\'armed';
;

/// `timer_page` run to its end in a Browser made with `options`: the log, as
/// JSON, OWNED.
fn runTimerPage(options: platform.PlatformBrowserOptions) ![]u8 {
    const browser = try open(options);
    defer browser.deinit();
    const armed = try evaluate(browser, timer_page);
    defer std.testing.allocator.free(armed);
    try std.testing.expectEqualStrings("armed", armed);
    try runUntilIdle(browser);
    return evaluate(browser, "JSON.stringify(log)");
}

const RunResult = struct {
    options: platform.PlatformBrowserOptions,
    log: ?[]u8 = null,
    err: ?anyerror = null,

    fn run(self: *RunResult) void {
        self.log = runTimerPage(self.options) catch |err| {
            self.err = err;
            return;
        };
    }
};

fn timersInVirtualTime() !void {
    const log = try runTimerPage(.{ .virtual_clock = true, .random_seed = 1 });
    defer std.testing.allocator.free(log);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, log, .{});
    defer parsed.deinit();
    const entries = parsed.value.array.items;
    // Arming order breaks the tie; the cleared timer never runs; the nested
    // one comes 5 ms after its parent; every delay is exact on both clocks,
    // because the clock stood still while the page worked and moved exactly
    // to each timer.
    const expected = [_]struct { []const u8, f64 }{
        .{ "start", 0 }, .{ "a10", 10 },   .{ "a10-tie", 10 },
        .{ "b20", 20 },  .{ "b20+5", 25 }, .{ "c30", 30 },
    };
    var timer_entries: usize = 0;
    var idle_entries: usize = 0;
    for (entries) |entry| {
        const name = entry.array.items[0].string;
        if (std.mem.eql(u8, name, "idle")) {
            idle_entries += 1;
            continue;
        }
        try std.testing.expect(timer_entries < expected.len);
        try std.testing.expectEqualStrings(expected[timer_entries][0], name);
        try std.testing.expectEqual(expected[timer_entries][1], number(entry.array.items[1]));
        try std.testing.expectEqual(expected[timer_entries][1], number(entry.array.items[2]));
        timer_entries += 1;
    }
    try std.testing.expectEqual(expected.len, timer_entries);
    // The idle callback ran, in an idle period on the same clock.
    try std.testing.expectEqual(@as(usize, 1), idle_entries);
}

fn number(value: std.json.Value) f64 {
    return switch (value) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        else => std.math.nan(f64),
    };
}

test "virtual clock: timers run in their order, each exactly its delay later, on performance.now() and Date.now()" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onThread(timersInVirtualTime);
}

fn sameSeedReplays() !void {
    const first = try runTimerPage(.{ .virtual_clock = true, .random_seed = 0x5eed });
    defer std.testing.allocator.free(first);
    const replay = try runTimerPage(.{ .virtual_clock = true, .random_seed = 0x5eed });
    defer std.testing.allocator.free(replay);
    const other = try runTimerPage(.{ .virtual_clock = true, .random_seed = 0x5eee });
    defer std.testing.allocator.free(other);
    // The whole log - names, both clocks, every Math.random draw - replays.
    try std.testing.expectEqualStrings(first, replay);
    // Another seed: the same timers at the same times, other draws.
    try std.testing.expect(!std.mem.eql(u8, first, other));
}

test "seeded Browser: the same seed replays the same Math.random sequence and the same timer order" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onThread(sameSeedReplays);
}

fn twoBrowsersIndependent() !void {
    // Two Browsers at once, each on a thread of its own, in one process.
    var a: RunResult = .{ .options = .{ .virtual_clock = true, .random_seed = 11 } };
    var b: RunResult = .{ .options = .{ .virtual_clock = true, .random_seed = 22, .virtual_clock_wall_start_ms = 86_400_000 } };
    {
        const ta = try std.Thread.spawn(.{}, RunResult.run, .{&a});
        const tb = try std.Thread.spawn(.{}, RunResult.run, .{&b});
        ta.join();
        tb.join();
    }
    defer if (a.log) |log| std.testing.allocator.free(log);
    defer if (b.log) |log| std.testing.allocator.free(log);
    if (a.err) |err| return err;
    if (b.err) |err| return err;
    // Each replays what it does alone: neither Browser's clock or stream
    // reached the other.
    const a_alone = try runTimerPage(a.options);
    defer std.testing.allocator.free(a_alone);
    const b_alone = try runTimerPage(b.options);
    defer std.testing.allocator.free(b_alone);
    try std.testing.expectEqualStrings(a_alone, a.log.?);
    try std.testing.expectEqualStrings(b_alone, b.log.?);
    try std.testing.expect(!std.mem.eql(u8, a.log.?, b.log.?));

    // Their wall clocks are their own: each reads its own start.
    const one = try open(.{ .virtual_clock = true });
    defer one.deinit();
    const other = try open(.{ .virtual_clock = true, .virtual_clock_wall_start_ms = 86_400_000 });
    defer other.deinit();
    const one_now = try evaluate(one, "String(Date.now())");
    defer std.testing.allocator.free(one_now);
    const other_now = try evaluate(other, "String(Date.now())");
    defer std.testing.allocator.free(other_now);
    try std.testing.expectEqualStrings("1767225600000", one_now);
    try std.testing.expectEqualStrings("86400000", other_now);
    // The time origin is on the same clocks: performance.timeOrigin is the
    // wall start, and performance.now() counts from it.
    const origin = try evaluate(one, "String(performance.timeOrigin) + ' ' + performance.now()");
    defer std.testing.allocator.free(origin);
    try std.testing.expectEqualStrings("1767225600000 0", origin);
}

test "two Browsers in one process keep independent virtual clocks and seeds" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onThread(twoBrowsersIndependent);
}

/// A chain of `count` timers, each `delay_ms` after the last; its virtual
/// (or real) duration on performance.now(), and the real time it took (ms).
fn runChain(options: platform.PlatformBrowserOptions, count: u32, delay_ms: u32) !struct { page_ms: f64, real_ms: f64 } {
    const browser = try open(options);
    defer browser.deinit();
    var source_buffer: [512]u8 = undefined;
    const source = try std.fmt.bufPrint(&source_buffer,
        \\globalThis.done = false;
        \\const t0 = performance.now();
        \\let left = {d};
        \\const step = () => {{ if (--left === 0) {{ globalThis.elapsed = performance.now() - t0; done = true; }} else setTimeout(step, {d}); }};
        \\setTimeout(step, {d});
        \\'chained';
    , .{ count, delay_ms, delay_ms });
    const real_start = platform.monotonicNow().ns;
    const chained = try evaluate(browser, source);
    defer std.testing.allocator.free(chained);
    try runUntilIdle(browser);
    const real_ns = platform.monotonicNow().ns - real_start;
    const elapsed = try evaluate(browser, "done ? String(elapsed) : 'unfinished'");
    defer std.testing.allocator.free(elapsed);
    return .{ .page_ms = try std.fmt.parseFloat(f64, elapsed), .real_ms = @as(f64, @floatFromInt(real_ns)) / std.time.ns_per_ms };
}

fn timerHeavyIsFast() !void {
    // 2,000 timers of 10 ms: 20 s of page time.
    const virtual = try runChain(.{ .virtual_clock = true }, 2_000, 10);
    try std.testing.expectEqual(@as(f64, 20_000), virtual.page_ms);
    // Real time, for the comparison: 25 timers of 10 ms, 250 ms at least.
    const real = try runChain(.{}, 25, 10);
    try std.testing.expect(real.page_ms >= 250 and real.real_ms >= 250);
    const virtual_rate = virtual.page_ms / virtual.real_ms;
    const real_rate = real.page_ms / real.real_ms;
    std.debug.print("detplat1: virtual time ran {d:.0} ms of timers in {d:.1} ms real ({d:.0}x); real time ran {d:.0} ms in {d:.1} ms ({d:.2}x)\n", .{ virtual.page_ms, virtual.real_ms, virtual_rate, real.page_ms, real.real_ms, real_rate });
    // Far faster: the chain never waits in real time, so it is bounded only
    // by its 2,000 callbacks - 83 times real time on a quiet host (240 ms for
    // the 20 s), 12 times under the whole suite's load (1.6 s). The bound is
    // a quarter of the page's time, so load cannot flip it: a speed the test
    // races is not a pass (docs/lessons/testing-a-result-that-flips-with-
    // speed-is-a-race-over-a-missing-check.md), while a loop that slept for
    // its timers would take the full 20 s.
    try std.testing.expect(virtual.real_ms * 4 < virtual.page_ms);
}

test "virtual clock: a timer-heavy page runs far faster than real time (measured)" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onThread(timerHeavyIsFast);
}

fn advancedByTheTest() !void {
    const browser = try open(.{ .virtual_clock = true });
    defer browser.deinit();
    const state = browser.scope.existing(html.platform_state.PlatformState) orelse return error.NoPlatformState;
    const browser_platform = state.browser orelse return error.NoPlatformState;
    const armed = try evaluate(browser, "globalThis.t0 = performance.now(); globalThis.fired = false; setTimeout(() => fired = true, 5000); 'armed'");
    defer std.testing.allocator.free(armed);
    // Real time passes; the page's does not, and nothing is due.
    _ = try browser.runEventLoopBlocking(0);
    const still = try evaluate(browser, "String(performance.now() - t0)");
    defer std.testing.allocator.free(still);
    try std.testing.expectEqualStrings("0", still);
    // The test moves the clock: the page reads it, and the timer is due.
    platform.adapter.advanceClock(browser_platform, 1_250 * std.time.ns_per_ms);
    const moved = try evaluate(browser, "String(performance.now() - t0)");
    defer std.testing.allocator.free(moved);
    try std.testing.expectEqualStrings("1250", moved);
    try runUntilIdle(browser);
    const fired = try evaluate(browser, "String(fired) + ' ' + (performance.now() - t0)");
    defer std.testing.allocator.free(fired);
    try std.testing.expectEqualStrings("true 5000", fired);
}

test "virtual clock: a test advances it, and the page reads the time it was given" {
    if (comptime !is_testing) return error.SkipZigTest;
    try onThread(advancedByTheTest);
}

fn realTimeByDefault() !void {
    const browser = try open(.{});
    defer browser.deinit();
    const before = platform.wallMillis();
    const now = try evaluate(browser, "String(Date.now())");
    defer std.testing.allocator.free(now);
    const after = platform.wallMillis();
    const date_now = try std.fmt.parseInt(i64, now, 10);
    try std.testing.expect(before <= date_now and date_now <= after);
    // A 30 ms timer takes 30 ms of real time.
    const chain = try runChain(.{}, 1, 30);
    try std.testing.expect(chain.page_ms >= 30 and chain.real_ms >= 30);
    // And two unseeded Browsers draw different Math.random sequences.
    const a = try runTimerPage(.{});
    defer std.testing.allocator.free(a);
    const b = try runTimerPage(.{});
    defer std.testing.allocator.free(b);
    try std.testing.expect(!std.mem.eql(u8, a, b));
}

test "real time and the engine's entropy stay the default" {
    try onThread(realTimeByDefault);
}
