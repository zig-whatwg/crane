//! Lane mp1: the OS's memory-pressure signal reaches a Browser.
//!
//! The platform protocol's `memory_pressure` event (docs/platform-protocol.md
//! section 7) is posted by the platform's observer - a
//! DISPATCH_SOURCE_TYPE_MEMORYPRESSURE source on darwin, a /proc/meminfo
//! poller on linux - through the EventSink Crane gave
//! `createBrowserPlatform`, on any thread. Crane's sink
//! (src/browser/platform_events.zig) turns it into tasks:
//!
//! - critical: on the window's event loop, `engine.notifyMemoryPressure`
//!   (.critical: everything that can be collected is, before it returns) and
//!   then one release of the allocator's free memory at `.pressure` through
//!   the loop's gate (src/browser/memory_release.zig); and on every running
//!   worker of the Browser, the same collection in the worker's own agent,
//!   on the worker's own thread.
//! - warning, normal: nothing (WebKit collects no script memory at a
//!   warning on macOS and Linux; Firefox answers at critical only; Chromium
//!   alone sends V8 a moderate notice).
//!
//! The testing platform has no OS observer: a test posts the event itself
//! with `platform.adapter.postEvent`, which calls the Browser's EventSink on
//! the calling thread exactly as an observer does. Each test runs a whole
//! Browser on a thread of its own, and gives its loop a gate over a record
//! of its own whose Source records the level of every release it is asked
//! to start: the process's record holds the next release off for seconds
//! after any Browser's, which a repeated test would meet.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const clock = @import("clock");
const html = @import("html");
const browser_mod = @import("browser");
const memory_release = browser_mod.memory_release;
const helpers = @import("edges_node_holders_helpers.zig");

/// A gate whose releases start nothing: each start is counted by its level,
/// and ends at once with the record open again (its end is dated long before
/// the gate's clock, so no hold-off refuses the next).
const Recorder = struct {
    hold: memory_release.HoldOff = .{},
    idle: u32 = 0,
    pressure: u32 = 0,

    fn gate(self: *Recorder) memory_release.Gate {
        return .{ .hold = &self.hold, .source = .{ .context = self, .now = now, .start = start } };
    }

    fn now(_: ?*anyopaque) i64 {
        return 100_000 * std.time.ns_per_s;
    }

    fn start(context: ?*anyopaque, hold: *memory_release.HoldOff) bool {
        const self: *Recorder = @ptrCast(@alignCast(context.?));
        const level: platform.MemoryRelease = @fromBackingInt(@intCast(hold.level.load(.acquire)));
        switch (level) {
            .pressure => self.pressure += 1,
            else => self.idle += 1,
        }
        memory_release.ended(hold, 0, 0, 0);
        return true;
    }
};

/// A page whose loop asks through `recorder`'s gate.
fn openWith(recorder: *Recorder) !helpers.Page {
    const page = try helpers.Page.open();
    errdefer page.close();
    const loop = page.browser.event_loop orelse return error.NoEventLoop;
    loop.memory_gate = recorder.gate();
    return page;
}

/// Post a memory-pressure event of `level` to `page`'s Browser, as the
/// platform's observer would: through the Browser's EventSink, on this
/// thread.
fn postPressure(page: helpers.Page, level: platform.MemoryPressureLevel) !void {
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const browser_platform = html.platform_state.of(realm) orelse return error.NoBrowserPlatform;
    const event: platform.PlatformEvent = .{ .kind = .memory_pressure, .memory_pressure = level };
    platform.adapter.postEvent(browser_platform, &event);
}

fn expectEval(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const text = try page.evaluate(source);
    defer testing.allocator.free(text);
    try testing.expectEqualStrings(expected, text);
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

/// An object only a WeakRef reaches, made in a job that has ended: the next
/// full collection takes it.
fn makeWeakTarget(page: helpers.Page) !void {
    try page.run("globalThis.w = new WeakRef({});");
    try page.turn();
}

fn criticalCollectsAndReleases() !void {
    var recorder: Recorder = .{};
    defer recorder.gate().settle();
    const page = try openWith(&recorder);
    defer page.close();
    try makeWeakTarget(page);

    try postPressure(page, .critical);
    // Nothing ran inside the post: the event became a task of the loop.
    try testing.expectEqual(@as(u32, 0), recorder.pressure);
    try page.turn();

    // The task collected everything that could be collected ...
    try expectEval(page, "String(w.deref() === undefined)", "true");
    // ... and then asked, once, for the allocator's free memory at the
    // pressure level.
    try testing.expectEqual(@as(u32, 1), recorder.pressure);
}

test "a critical memory-pressure event collects the window's garbage and releases the allocator's free memory, as a task of the loop" {
    try helpers.onFreshThread(criticalCollectsAndReleases);
}

fn warningAndNormalDoNothing() !void {
    var recorder: Recorder = .{};
    defer recorder.gate().settle();
    const page = try openWith(&recorder);
    defer page.close();
    try makeWeakTarget(page);

    try postPressure(page, .warning);
    try postPressure(page, .normal);
    try page.turn();
    try page.turn();

    try testing.expectEqual(@as(u32, 0), recorder.pressure);
    // Nothing was collected for them. (deref keeps its target for the job,
    // so this is the last read of it.)
    try expectEval(page, "String(w.deref() === undefined)", "false");
}

test "a warning and a return to normal collect nothing and release nothing" {
    try helpers.onFreshThread(warningAndNormalDoNothing);
}

fn postedFromAnotherThread() !void {
    var recorder: Recorder = .{};
    defer recorder.gate().settle();
    const page = try openWith(&recorder);
    defer page.close();
    try makeWeakTarget(page);

    // An OS observer posts from a thread of its own (a dispatch queue, the
    // poller), never the Browser's.
    const Poster = struct {
        fn post(target: helpers.Page, failure: *?anyerror) void {
            postPressure(target, .critical) catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Poster.post, .{ page, &failure });
    thread.join();
    if (failure) |err| return err;
    // Nothing ran on the observer's thread.
    try testing.expectEqual(@as(u32, 0), recorder.pressure);

    try page.turn();
    try expectEval(page, "String(w.deref() === undefined)", "true");
    try testing.expectEqual(@as(u32, 1), recorder.pressure);
}

test "a critical event posted from another thread runs on the Browser's thread, as a task of its loop" {
    try helpers.onFreshThread(postedFromAnotherThread);
}

/// A worker that makes an object only a WeakRef reaches ('make'), and says
/// whether it is gone ('check'). state: 1 once it has made it, 2 once it
/// has answered; answer: "true" when the object is gone.
const weak_worker =
    \\globalThis.state = 0;
    \\globalThis.answer = '';
    \\globalThis.wk = new Worker('data:text/javascript,' + encodeURIComponent(`
    \\  let w = null;
    \\  onmessage = e => {
    \\    if (e.data === 'make') { w = new WeakRef({}); postMessage('made'); }
    \\    else postMessage(String(w.deref() === undefined));
    \\  };
    \\`));
    \\wk.onmessage = e => {
    \\  if (e.data === 'made') state = 1;
    \\  else { answer = e.data; state = 2; }
    \\};
    \\wk.postMessage('make');
;

fn criticalCollectsInAWorker() !void {
    var recorder: Recorder = .{};
    defer recorder.gate().settle();
    const page = try openWith(&recorder);
    defer page.close();
    try page.run(weak_worker);
    try turnUntil(page, "String(state)");

    // The worker's collection is queued on the worker's own loop by the
    // post itself, so it is ahead of the 'check' the window posts next.
    try postPressure(page, .critical);
    try page.run("wk.postMessage('check');");
    try turnUntil(page, "String(state - 1)");

    try expectEval(page, "answer", "true");
    // The window's own task ran too: one release, the process's allocator
    // being one.
    try testing.expectEqual(@as(u32, 1), recorder.pressure);
}

test "a critical memory-pressure event collects the garbage of the Browser's running workers, each on its own thread" {
    try helpers.onFreshThread(criticalCollectsInAWorker);
}

fn workerIsLeftAloneAtWarning() !void {
    var recorder: Recorder = .{};
    defer recorder.gate().settle();
    const page = try openWith(&recorder);
    defer page.close();
    try page.run(weak_worker);
    try turnUntil(page, "String(state)");

    try postPressure(page, .warning);
    try page.run("wk.postMessage('check');");
    try turnUntil(page, "String(state - 1)");

    try expectEval(page, "answer", "false");
    try testing.expectEqual(@as(u32, 0), recorder.pressure);
}

test "a warning collects nothing in a worker" {
    try helpers.onFreshThread(workerIsLeftAloneAtWarning);
}
