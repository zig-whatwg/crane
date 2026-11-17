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
//! src/browser/memory_release.zig): it starts a detached thread for the one
//! release, and that thread makes the allocator's call.
//!
//! The rule's two halves are pinned without a Browser beside the code
//! (memory_release.zig: IdleWatch - 200 ms, once per idle stretch; Gate -
//! the process's hold-off). Here, a whole Browser: its loop asks once it has
//! been idle, asks again after it has worked again, does not ask while it
//! keeps working, is free to handle a worker's reply while a release runs,
//! and - on glibc - the freed memory leaves the process.
//!
//! Each test runs a whole Browser on a thread of its own, and gives its loop
//! a gate over a hold-off record of its own (EventLoop.memory_gate): the
//! process's record holds the next release off for 5 seconds or more after any
//! Browser's, which a test repeated in one process, or run beside another
//! Browser, would meet. A test waits for the release it started before its
//! record goes (Gate.settle): the release's thread writes to it.

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

/// Turn the loop until `releases` releases started through `gate` have
/// ended, at most 20 s.
fn idleUntilReleased(page: helpers.Page, gate: memory_release.Gate, releases: u64) !void {
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    const start = clock.monotonicMillis();
    while (gate.count() < releases) {
        if (clock.monotonicMillis() - start > 20_000) return error.NeverReleased;
        _ = loop.runOnceBlocking(5);
    }
}

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

/// A page whose loop asks through `gate` instead of the process's.
fn openWithGate(gate: memory_release.Gate) !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = gate;
    return page;
}

fn idleLoopAsksAndAsksAgainAfterWork() !void {
    var hold: memory_release.HoldOff = .{};
    const gate: memory_release.Gate = .{ .hold = &hold };
    defer gate.settle();
    var second_hold: memory_release.HoldOff = .{};
    const second: memory_release.Gate = .{ .hold = &second_hold };
    defer second.settle();
    const page = try openWithGate(gate);
    defer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;

    // The page was made and left alone: its loop asks, once it has been idle
    // for the delay - not at once.
    const made = clock.monotonicMillis();
    try idleUntilReleased(page, gate, 1);
    // (Whole milliseconds, each rounded down: 199.)
    try testing.expect(clock.monotonicMillis() - made >= 199);
    try testing.expect(!loop.memory_idle.armed);

    // The page works again (a timer's callback), then nothing: a second
    // idle stretch. The first gate holds its next release off for at least 5
    // seconds, so the loop gets a fresh one - and asks it.
    loop.memory_gate = second;
    try page.run("globalThis.worked = 0; setTimeout(() => { worked = 1; }, 0);");
    try idleUntilReleased(page, second, 1);
    const worked = try page.evaluate("String(worked)");
    defer testing.allocator.free(worked);
    try testing.expectEqualStrings("1", worked);
    try testing.expectEqual(@as(u64, 1), gate.count());
}

test "an idle event loop asks for the allocator's free memory, and again after it has worked again" {
    try helpers.onFreshThread(idleLoopAsksAndAsksAgainAfterWork);
}

fn workingLoopDoesNotAsk() !void {
    var hold: memory_release.HoldOff = .{};
    const gate: memory_release.Gate = .{ .hold = &hold };
    defer gate.settle();
    const page = try openWithGate(gate);
    defer page.close();
    // A callback every 20 ms: the loop is never without work for 200 ms.
    try page.run("globalThis.ticks = 0; globalThis.ticker = setInterval(() => { ticks++; }, 20);");
    try idleFor(page, 600);
    try page.run("clearInterval(ticker);");
    const ticks_text = try page.evaluate("String(ticks)");
    defer testing.allocator.free(ticks_text);
    try testing.expect(try std.fmt.parseInt(u32, ticks_text, 10) >= 5);
    try testing.expectEqual(@as(u64, 0), gate.count());
    try testing.expect(!gate.isReleasing());
}

test "an event loop that keeps working does not ask for the allocator's free memory" {
    try helpers.onFreshThread(workingLoopDoesNotAsk);
}

/// An echo worker, as tests/html/rep2_window_wake_test.zig's: after its
/// first reply the page waits for `resume()`, then makes 40 round trips,
/// each begun by a 3 ms timer - the window waits, idle, for every reply.
/// `longest` is the longest the window went without work: from a round
/// trip's timer to its reply. phase: 1 after the first reply, 2 at the end.
const round_trips =
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
;

/// A release kept running: started as the platform's is - a thread of its
/// own through platform.spawnThread, detached - it stays in its "allocator
/// call" until the test lets it go, as an allocator with much to return
/// would. Records which thread it ran on.
const KeptRunning = struct {
    hold: memory_release.HoldOff = .{},
    started: std.atomic.Value(u32) = .init(0),
    running: std.atomic.Value(bool) = .init(false),
    let_go: std.atomic.Value(bool) = .init(false),
    ran_on: std.atomic.Value(u64) = .init(0),

    fn gate(self: *KeptRunning) memory_release.Gate {
        return .{ .hold = &self.hold, .source = .{ .context = self, .now = now, .start = start } };
    }

    fn now(_: ?*anyopaque) i64 {
        return @intCast(platform.monotonicNow().ns);
    }

    /// On the loop's thread.
    fn start(context: ?*anyopaque, hold: *memory_release.HoldOff) bool {
        const self: *KeptRunning = @ptrCast(@alignCast(context.?));
        std.debug.assert(hold == &self.hold);
        const thread = platform.spawnThread(.{ .name = .from("kept-release") }, run, self) catch return false;
        platform.detachThread(thread);
        _ = self.started.fetchAdd(1, .monotonic);
        return true;
    }

    /// On the release's thread.
    fn run(context: ?*anyopaque) callconv(.c) void {
        const self: *KeptRunning = @ptrCast(@alignCast(context.?));
        self.ran_on.store(std.Thread.getCurrentId(), .release);
        self.running.store(true, .release);
        while (!self.let_go.load(.acquire)) platform.sleepThread(100 * std.time.ns_per_us);
        memory_release.ended(&self.hold, now(null), 0, 0);
    }
};

fn replyIsHandledWhileAReleaseRuns() !void {
    var kept: KeptRunning = .{};
    const gate = kept.gate();
    // Whatever fails below, the release's thread is let go and the test
    // waits for it before the record goes.
    defer gate.settle();
    defer kept.let_go.store(true, .release);
    const page = try openWithGate(gate);
    defer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;

    try page.run(round_trips);
    try turnUntil(page, "String(phase)");
    // The window is idle (it waits for `resume()`): its loop starts a
    // release, which runs - and keeps running - on a thread of its own.
    const start = clock.monotonicMillis();
    while (!kept.running.load(.acquire)) {
        if (clock.monotonicMillis() - start > 20_000) return error.NeverAsked;
        _ = loop.runOnceBlocking(5);
    }
    try testing.expect(gate.isReleasing());
    try testing.expect(kept.ran_on.load(.acquire) != std.Thread.getCurrentId());

    // 40 worker replies arrive while it runs: the loop's thread is free, and
    // handles each one.
    try page.run("resume();");
    try turnUntil(page, "String(phase - 1)");
    try testing.expect(gate.isReleasing());
    try testing.expectEqual(@as(u64, 0), gate.count());
    // One release: a loop starts no other while one runs, however often it
    // works and idles meanwhile.
    try testing.expectEqual(@as(u32, 1), kept.started.load(.monotonic));

    // The release ends: its thread writes the hold-off.
    kept.let_go.store(true, .release);
    gate.settle();
    try testing.expectEqual(@as(u64, 1), gate.count());
    try page.run("w.terminate(); clearTimeout(keepAlive);");
}

test "a worker's reply that arrives while a release runs is handled at once: the release is on a detached thread, not the loop's" {
    try helpers.onFreshThread(replyIsHandledWhileAReleaseRuns);
}

fn noReleaseIsAskedForBetweenAPostAndItsReply() !void {
    var hold: memory_release.HoldOff = .{};
    const gate: memory_release.Gate = .{ .hold = &hold };
    defer gate.settle();
    var fresh_hold: memory_release.HoldOff = .{};
    const fresh: memory_release.Gate = .{ .hold = &fresh_hold };
    defer fresh.settle();
    const page = try openWithGate(gate);
    defer page.close();
    try page.run(round_trips);
    // The worker starts on its own thread; the window may be idle long
    // enough meanwhile to ask once. That is before the round trips.
    try turnUntil(page, "String(phase)");
    // A gate that would not refuse: if the loop asked during the round
    // trips, it would be counted.
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = fresh;
    try page.run("resume();");
    try turnUntil(page, "String(phase - 1)");
    try page.run("w.terminate(); clearTimeout(keepAlive);");

    const longest_text = try page.evaluate("String(Math.ceil(longest))");
    defer testing.allocator.free(longest_text);
    const longest_ms = try std.fmt.parseInt(u64, longest_text, 10);
    // A release makes the allocator's arenas busy one after another, and an
    // allocation from the one being trimmed waits. The loop asks only after
    // 200 ms with nothing to run, so none is asked for between a post and
    // its reply while a round trip is shorter than that. (A host that
    // stalled this thread for 150 ms or more shows nothing either way.)
    if (longest_ms < 150) {
        try testing.expectEqual(@as(u64, 0), fresh.count());
        try testing.expect(!fresh.isReleasing());
    }
    try testing.expect(gate.count() <= 1);
}

test "no release is asked for between a window's post to a worker and the reply: the loop asks only after 200 ms with nothing to run" {
    try helpers.onFreshThread(noReleaseIsAskedForBetweenAPostAndItsReply);
}

/// A release that outlives its test: the process's own record says one
/// runs, and a detached thread keeps calling the allocator for 300 ms, then
/// leaves the record as the test found it. In the C heap: the thread frees
/// it at its end, and a process that exits first never does.
const OutlivingRelease = struct {
    found: i64,

    fn run(context: ?*anyopaque) callconv(.c) void {
        const self: *OutlivingRelease = @ptrCast(@alignCast(context.?));
        const start = platform.monotonicNow().ns;
        while (platform.monotonicNow().ns - start < 300 * std.time.ns_per_ms) {
            _ = platform.releaseFreeMemory(.idle);
        }
        memory_release.processGate().hold.not_before_ns.store(self.found, .release);
        std.heap.c_allocator.destroy(self);
    }
};

test "a process that exits while a release runs, and never ends the process, exits cleanly" {
    // The hosts that end the process (the repl, the WPT runner) wait for a
    // release in flight (crane.Process.deinit: Gate.settle). A host that
    // only makes Browsers does not - a test executable under the launcher,
    // an embedder through the C API (src/lib_exports.zig) - and may exit
    // while the release's detached thread is inside the allocator. This
    // test's process is such a host: it returns with the release running.
    // The launcher runs it in a process of its own (the suite's batch is 1),
    // so its verdict is that process's exit: no hang, no crash, and under
    // the thread sanitizer no thread reported as leaked (the thread is
    // detached, and still running).
    const hold = memory_release.processGate().hold;
    // Claim the process's record as a release does. Another release may be
    // running: an earlier repeat of this test in the same process (it ends
    // within 300 ms), or a Browser's beside it.
    var waited_us: u64 = 0;
    const found = while (true) : (waited_us += 100) {
        const seen = hold.not_before_ns.load(.acquire);
        if (seen != memory_release.HoldOff.releasing and
            hold.not_before_ns.cmpxchgStrong(seen, memory_release.HoldOff.releasing, .acq_rel, .acquire) == null) break seen;
        if (waited_us > 20 * std.time.us_per_s) return error.RecordNeverFree;
        platform.sleepThread(100 * std.time.ns_per_us);
    };
    const release = std.heap.c_allocator.create(OutlivingRelease) catch {
        hold.not_before_ns.store(found, .release);
        return error.OutOfMemory;
    };
    release.* = .{ .found = found };
    const thread = platform.spawnThread(.{ .name = .from("crane-memory") }, OutlivingRelease.run, release) catch |err| {
        hold.not_before_ns.store(found, .release);
        std.heap.c_allocator.destroy(release);
        return err;
    };
    platform.detachThread(thread);
    try testing.expect(memory_release.processGate().isReleasing());
}

fn residentMemoryFallsWhenThePageGoesIdle() !void {
    var hold: memory_release.HoldOff = .{};
    const gate: memory_release.Gate = .{ .hold = &hold };
    defer gate.settle();
    const page = try openWithGate(gate);
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
    try idleUntilReleased(page, gate, 1);

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
