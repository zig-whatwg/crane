//! Lane idle1: a page that goes idle gives the allocator's free memory back
//! to the OS.
//!
//! The OS allocators keep what a page frees. On glibc a freed block that
//! lies between two live ones stays resident for the life of the process:
//! no malloc threshold reaches inside a heap, only malloc_trim does (lane
//! mem2 measured 221-228 MB of it on perf_bench's streams page, of which
//! malloc_trim(0) returned 188-195 MB). A browser returns such memory away
//! from the allocation path, when the page is idle (Chrome's
//! MemoryReclaimer, Firefox's idle purge task, WebKit's
//! releaseSystemMallocMemory). Crane's window event loop does the same
//! (src/browser/event_loop.zig, the turn's last step;
//! src/browser/memory_release.zig).
//!
//! The rule's two halves are pinned without a Browser beside the code
//! (memory_release.zig: IdleWatch - 200 ms, once per idle stretch; Gate -
//! the process's hold-off). Here, a whole Browser: its loop asks once it has
//! been idle, asks again after it has worked again, does not ask while it
//! keeps working, and - on glibc - the freed memory leaves the process.
//!
//! Each test runs a whole Browser on a thread of its own, and gives its loop
//! a gate of its own (EventLoop.memory_gate): the process's gate holds the
//! next release off for 5 to 30 seconds after any Browser's, which a test
//! repeated in one process, or run beside another Browser, would meet.

const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const platform = @import("platform");
const clock = @import("clock");
const browser_mod = @import("browser");
const memory_release = browser_mod.memory_release;
const helpers = @import("edges_node_holders_helpers.zig");

const mib = 1024 * 1024;

/// Where freed malloc memory can be seen leaving the process: glibc, whose
/// malloc_trim the platform calls. Not under ThreadSanitizer, whose own
/// allocator serves malloc there, and not on macOS, whose allocator has no
/// public call that returns its free memory (macOS 26 and later:
/// malloc_zone_pressure_relief answers 0; docs/lessons, lane idle1).
const resident_falls = builtin.os.tag == .linux and builtin.abi.isGnu() and !builtin.sanitize_thread;

/// Blocks of 64 KiB - below any mmap threshold glibc can have (its floor is
/// 128 KiB), so each is cut from a heap - written, so their pages are
/// resident; then all but every 64th freed. The kept blocks pin the heap:
/// nothing is at its top, and no threshold returns the rest.
const Fragmented = struct {
    const block_size = 64 * 1024;
    const count = 4000;
    const keep_every = 64;
    const freed_bytes = (count - (count + keep_every - 1) / keep_every) * block_size;

    kept: [count]?[*]u8 = @splat(null),

    fn make(self: *Fragmented) !void {
        for (&self.kept) |*slot| {
            const block: [*]u8 = @ptrCast(std.c.malloc(block_size) orelse return error.OutOfMemory);
            @memset(block[0..block_size], 0x5a);
            slot.* = block;
        }
    }

    fn freeMost(self: *Fragmented) void {
        for (&self.kept, 0..) |*slot, i| {
            if (i % keep_every == 0) continue;
            std.c.free(slot.*);
            slot.* = null;
        }
    }

    fn deinit(self: *Fragmented) void {
        for (&self.kept) |*slot| {
            if (slot.*) |block| std.c.free(block);
            slot.* = null;
        }
    }
};

/// Turn the loop until the page expression `done` is "1", at most 20 s.
fn turnUntil(page: helpers.Page, done: []const u8) !void {
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const start = clock.monotonicMillis();
    while (true) {
        const text = try page.evaluate(done);
        defer testing.allocator.free(text);
        if (std.mem.eql(u8, text, "1")) return;
        if (clock.monotonicMillis() - start > 20_000) return error.NeverDone;
        _ = loop.runOnceBlocking(5);
    }
}

fn noReleaseBetweenAPostAndItsReply() !void {
    var gate: memory_release.Gate = .{};
    const page = try openWithGate(&gate);
    defer page.close();
    // An echo worker, as tests/html/rep2_window_wake_test.zig's: after its
    // first reply, 40 round trips, each begun by a 3 ms timer - the window
    // waits, idle, for every reply. `longest` is the longest the window went
    // without work: from a round trip's timer to its reply.
    try page.run(
        \\globalThis.phase = 0;
        \\globalThis.longest = 0;
        \\globalThis.keepAlive = setTimeout(() => {}, 60000);
        \\globalThis.w = new Worker('data:text/javascript,onmessage%20%3D%20e%20%3D%3E%20postMessage(e.data)');
        \\(async () => {
        \\  await new Promise(r => { w.onmessage = r; w.postMessage(-1); });
        \\  phase = 1;
        \\  await new Promise(r => { globalThis.resume = r; });
        \\  for (let i = 0; i < 40; i++) {
        \\    const t0 = performance.now();
        \\    await new Promise(r => setTimeout(r, 3));
        \\    await new Promise(r => { w.onmessage = r; w.postMessage(i); });
        \\    longest = Math.max(longest, performance.now() - t0);
        \\  }
        \\  phase = 2;
        \\})();
    );
    // The worker starts on its own thread; the window may be idle long
    // enough meanwhile to ask once. That is before the round trips.
    try turnUntil(page, "String(phase)");
    const before = gate.count();
    // A gate that would not refuse: if the loop asked during the round
    // trips, it would be counted.
    var fresh: memory_release.Gate = .{};
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = &fresh;
    try page.run("resume();");
    try turnUntil(page, "String(phase - 1)");
    try page.run("w.terminate(); clearTimeout(keepAlive);");

    const longest_text = try page.evaluate("String(Math.ceil(longest))");
    defer testing.allocator.free(longest_text);
    const longest_ms = try std.fmt.parseInt(u64, longest_text, 10);
    // A release takes the loop's thread for as long as the allocator works,
    // and a reply posted meanwhile waits for it. The loop asks only after
    // 200 ms with nothing to run, so no release can fall between a post and
    // its reply while a round trip is shorter than that. (A host that
    // stalled this thread for 150 ms or more shows nothing either way.)
    if (longest_ms < 150) try testing.expectEqual(@as(u64, 0), fresh.count());
    try testing.expect(before <= 1);
}

test "no release falls between a window's post to a worker and the reply: the loop asks only after 200 ms with nothing to run" {
    try helpers.onFreshThread(noReleaseBetweenAPostAndItsReply);
}

fn residentBytes() !u64 {
    const reading = platform.residentMemory() orelse return error.NoResidentMemoryReading;
    return reading.resident_bytes;
}

/// Turn the loop for `ms` of real time, as a host with nothing to do does.
fn idleFor(page: helpers.Page, ms: i64) !void {
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const start = clock.monotonicMillis();
    while (clock.monotonicMillis() - start < ms) _ = loop.runOnceBlocking(5);
}

/// Turn the loop until `gate` has run `releases` releases, at most 10 s.
fn idleUntilReleased(page: helpers.Page, gate: *const memory_release.Gate, releases: u64) !void {
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const start = clock.monotonicMillis();
    while (gate.count() < releases) {
        if (clock.monotonicMillis() - start > 10_000) return error.NeverReleased;
        _ = loop.runOnceBlocking(5);
    }
}

/// A page whose loop asks through `gate` instead of the process's.
fn openWithGate(gate: *memory_release.Gate) !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = gate;
    return page;
}

fn idleLoopAsksAndAsksAgainAfterWork() !void {
    var gate: memory_release.Gate = .{};
    const page = try openWithGate(&gate);
    defer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;

    // The page was made and left alone: its loop asks, once it has been idle
    // for the delay - not at once.
    const made = clock.monotonicMillis();
    try idleUntilReleased(page, &gate, 1);
    // (Whole milliseconds, each rounded down: 199.)
    try testing.expect(clock.monotonicMillis() - made >= 199);
    try testing.expect(!loop.memory_idle.armed);

    // The page works again (a timer's callback), then nothing: a second
    // idle stretch. The first gate holds its next release off for 30 seconds
    // (nothing came back), so the loop gets a fresh one - and asks it.
    var second: memory_release.Gate = .{};
    loop.memory_gate = &second;
    try page.run("globalThis.worked = 0; setTimeout(() => { worked = 1; }, 0);");
    try idleUntilReleased(page, &second, 1);
    const worked = try page.evaluate("String(worked)");
    defer testing.allocator.free(worked);
    try testing.expectEqualStrings("1", worked);
    try testing.expectEqual(@as(u64, 1), gate.count());
}

test "an idle event loop asks for the allocator's free memory, and again after it has worked again" {
    try helpers.onFreshThread(idleLoopAsksAndAsksAgainAfterWork);
}

fn workingLoopDoesNotAsk() !void {
    var gate: memory_release.Gate = .{};
    const page = try openWithGate(&gate);
    defer page.close();
    // A callback every 20 ms: the loop is never without work for 200 ms.
    try page.run("globalThis.ticks = 0; globalThis.ticker = setInterval(() => { ticks++; }, 20);");
    try idleFor(page, 600);
    try page.run("clearInterval(ticker);");
    const ticks_text = try page.evaluate("String(ticks)");
    defer testing.allocator.free(ticks_text);
    try testing.expect(try std.fmt.parseInt(u32, ticks_text, 10) >= 5);
    try testing.expectEqual(@as(u64, 0), gate.count());
}

test "an event loop that keeps working does not ask for the allocator's free memory" {
    try helpers.onFreshThread(workingLoopDoesNotAsk);
}

fn residentMemoryFallsWhenThePageGoesIdle() !void {
    var gate: memory_release.Gate = .{};
    const page = try openWithGate(&gate);
    defer page.close();

    const fragmented = try testing.allocator.create(Fragmented);
    defer testing.allocator.destroy(fragmented);
    fragmented.* = .{};
    defer fragmented.deinit();
    try fragmented.make();
    const before = try residentBytes();
    fragmented.freeMost();

    // The page does a little work, then nothing.
    try page.run("setTimeout(() => { globalThis.worked = true; }, 0);");
    try idleUntilReleased(page, &gate, 1);

    const after = try residentBytes();
    // 246 MiB were freed; at least half of it has left the process. Without
    // the release the frees return nothing (each freed block lies between
    // two kept ones), and resident memory does not fall at all.
    if (before < after + Fragmented.freed_bytes / 2) {
        std.debug.print("resident {d} MiB before the frees, {d} MiB after the idle loop's release; {d} MiB were freed\n", .{ before / mib, after / mib, Fragmented.freed_bytes / mib });
        return error.FreedMemoryStayedResident;
    }
}

test "malloc memory a page freed leaves the process once its event loop has been idle" {
    if (comptime !resident_falls) return error.SkipZigTest;
    try helpers.onFreshThread(residentMemoryFallsWhenThePageGoesIdle);
}
