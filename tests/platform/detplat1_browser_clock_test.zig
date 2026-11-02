//! A Browser's clock and its random stream (docs/platform-protocol.md 6.2,
//! 6.3): the platform's own clocks and no stream of its own by default; on
//! the testing platform, opt in, a virtual clock that moves only when it is
//! fast-forwarded to a wake-up or a test advances it (Chromium's
//! TaskEnvironment MOCK_TIME, base/test/task_environment.h), and a stream
//! replayed from a seed - each per Browser, never per process (V8's
//! --random-seed gives every isolate the same Math.random sequence; the
//! approved test plan, section 5).
const std = @import("std");
const platform = @import("platform");
const testing = std.testing;

fn ignoreEvent(context: ?*anyopaque, event: *const platform.PlatformEvent) callconv(.c) void {
    _ = .{ context, event };
}

const no_events: platform.EventSink = .{ .context = null, .post = ignoreEvent };

test "browser clock: by default a Browser reads the platform's own clocks and never fast-forwards" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const clock = platform.browserClock(browser);
    try testing.expect(clock.isReal());

    const before = platform.monotonicNow().ns;
    const read = clock.monotonicNow().ns;
    const after = platform.monotonicNow().ns;
    try testing.expect(before <= read and read <= after);

    const wall_before = platform.wallNow().ns_since_epoch;
    const wall = clock.wallNow().ns_since_epoch;
    const wall_after = platform.wallNow().ns_since_epoch;
    try testing.expect(wall_before <= wall and wall <= wall_after);

    // A real clock never jumps: the event loop waits instead.
    try testing.expect(!clock.maybeFastForwardToWakeUp(.{ .ns = after + std.time.ns_per_s }));
}

test "browser random: by default a Browser has no stream of its own" {
    const browser = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(browser);
    var bytes: [16]u8 = @splat(0xAB);
    try testing.expect(!platform.fillBrowserRandom(browser, &bytes));
    // Untouched: the consumer uses its own entropy.
    const untouched: [16]u8 = @splat(0xAB);
    try testing.expectEqualSlices(u8, &untouched, &bytes);
}

const virtual: platform.BrowserOptions = if (std.mem.eql(u8, platform.name, "testing"))
    .{ .platform = .{ .virtual_clock = true } }
else
    .{};

test "virtual clock: starts at its stated wall time and stands still until it is moved" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const browser = try platform.createBrowserPlatform(testing.allocator, &virtual, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const clock = platform.browserClock(browser);
    try testing.expect(!clock.isReal());

    // 2026-01-01T00:00:00Z, the default start.
    const start_wall: i64 = 1_767_225_600 * std.time.ns_per_s;
    try testing.expectEqual(start_wall, clock.wallNow().ns_since_epoch);
    const start = clock.monotonicNow().ns;
    // Not 0: several timestamps use 0 for "not yet".
    try testing.expect(start > 0);

    // Real time passing does not move it (MOCK_TIME: only idle advances).
    var spin: u64 = 0;
    const real_start = platform.monotonicNow().ns;
    while (platform.monotonicNow().ns - real_start < 2 * std.time.ns_per_ms) spin += 1;
    try testing.expectEqual(start, clock.monotonicNow().ns);
    try testing.expectEqual(start_wall, clock.wallNow().ns_since_epoch);

    // A test advances it: both clocks move together.
    platform.adapter.advanceClock(browser, 250 * std.time.ns_per_ms);
    try testing.expectEqual(start + 250 * std.time.ns_per_ms, clock.monotonicNow().ns);
    try testing.expectEqual(start_wall + 250 * std.time.ns_per_ms, clock.wallNow().ns_since_epoch);
}

test "virtual clock: a fast-forward moves to the wake-up and never back" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const browser = try platform.createBrowserPlatform(testing.allocator, &virtual, no_events);
    defer platform.destroyBrowserPlatform(browser);
    const clock = platform.browserClock(browser);
    const start = clock.monotonicNow().ns;

    try testing.expect(clock.maybeFastForwardToWakeUp(.{ .ns = start + 4 * std.time.ns_per_ms }));
    try testing.expectEqual(start + 4 * std.time.ns_per_ms, clock.monotonicNow().ns);
    // A wake-up already past: nothing to wait for, and time does not go back.
    try testing.expect(clock.maybeFastForwardToWakeUp(.{ .ns = start + 1 }));
    try testing.expectEqual(start + 4 * std.time.ns_per_ms, clock.monotonicNow().ns);
}

test "virtual clock: the start wall time is an option" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const options: platform.BrowserOptions = .{ .platform = .{ .virtual_clock = true, .virtual_clock_wall_start_ms = 86_400_000 } };
    const browser = try platform.createBrowserPlatform(testing.allocator, &options, no_events);
    defer platform.destroyBrowserPlatform(browser);
    try testing.expectEqual(@as(i64, 86_400 * std.time.ns_per_s), platform.browserClock(browser).wallNow().ns_since_epoch);
}

test "virtual clock: two Browsers in one process keep independent clocks" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const a = try platform.createBrowserPlatform(testing.allocator, &virtual, no_events);
    defer platform.destroyBrowserPlatform(a);
    const b = try platform.createBrowserPlatform(testing.allocator, &virtual, no_events);
    defer platform.destroyBrowserPlatform(b);
    const real = try platform.createBrowserPlatform(testing.allocator, &.{}, no_events);
    defer platform.destroyBrowserPlatform(real);

    const a_start = platform.browserClock(a).monotonicNow().ns;
    const b_start = platform.browserClock(b).monotonicNow().ns;
    platform.adapter.advanceClock(a, 7 * std.time.ns_per_s);
    try testing.expect(platform.browserClock(b).maybeFastForwardToWakeUp(.{ .ns = b_start + 3 * std.time.ns_per_ms }));

    try testing.expectEqual(a_start + 7 * std.time.ns_per_s, platform.browserClock(a).monotonicNow().ns);
    try testing.expectEqual(b_start + 3 * std.time.ns_per_ms, platform.browserClock(b).monotonicNow().ns);
    // The real-clock Browser beside them is untouched.
    try testing.expect(platform.browserClock(real).isReal());
    // advanceClock on a real-clock Browser does nothing (no clock of its own).
    platform.adapter.advanceClock(real, std.time.ns_per_s);
    try testing.expect(platform.browserClock(real).isReal());
}

fn seeded(seed: u64) platform.BrowserOptions {
    return if (comptime std.mem.eql(u8, platform.name, "testing")) .{ .platform = .{ .random_seed = seed } } else .{};
}

fn draw(browser: *platform.BrowserPlatform) ![32]u8 {
    var bytes: [32]u8 = undefined;
    try testing.expect(platform.fillBrowserRandom(browser, &bytes));
    return bytes;
}

test "seeded random: the same seed replays the same stream, another seed differs" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const a = try platform.createBrowserPlatform(testing.allocator, &seeded(0x5eed), no_events);
    defer platform.destroyBrowserPlatform(a);
    const replay = try platform.createBrowserPlatform(testing.allocator, &seeded(0x5eed), no_events);
    defer platform.destroyBrowserPlatform(replay);
    const other = try platform.createBrowserPlatform(testing.allocator, &seeded(0x5eee), no_events);
    defer platform.destroyBrowserPlatform(other);

    const first = try draw(a);
    const second = try draw(a);
    // A stream, not a constant.
    try testing.expect(!std.mem.eql(u8, &first, &second));
    // The replaying Browser draws the same, whatever `a` drew meanwhile.
    try testing.expectEqualSlices(u8, &first, &(try draw(replay)));
    try testing.expectEqualSlices(u8, &second, &(try draw(replay)));
    try testing.expect(!std.mem.eql(u8, &first, &(try draw(other))));
}

test "seeded random: odd lengths are filled from the same stream" {
    if (comptime !std.mem.eql(u8, platform.name, "testing")) return error.SkipZigTest;
    const a = try platform.createBrowserPlatform(testing.allocator, &seeded(42), no_events);
    defer platform.destroyBrowserPlatform(a);
    const b = try platform.createBrowserPlatform(testing.allocator, &seeded(42), no_events);
    defer platform.destroyBrowserPlatform(b);
    var three: [3]u8 = undefined;
    var eleven: [11]u8 = undefined;
    try testing.expect(platform.fillBrowserRandom(a, &three));
    try testing.expect(platform.fillBrowserRandom(a, &eleven));
    var three_b: [3]u8 = undefined;
    var eleven_b: [11]u8 = undefined;
    try testing.expect(platform.fillBrowserRandom(b, &three_b));
    try testing.expect(platform.fillBrowserRandom(b, &eleven_b));
    try testing.expectEqualSlices(u8, &three, &three_b);
    try testing.expectEqualSlices(u8, &eleven, &eleven_b);
}
