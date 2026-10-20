//! "Notify mutation observers" frees each mutation record exactly once, on
//! every path out of out of memory (lane leaks6, item 4).
//!
//! notifyMutationObservers handed an observer's records to
//! dom.observer_registrations.invokeCallback, whose contract is that the
//! records are TAKEN: MutationObserver's invokeCallback wraps them (the
//! wrapper cache owns a wrapped record) or frees them itself. But its catch
//! freed them again whenever the call failed:
//!
//! - wrapping the records failed (createSequenceOfPlatformObjects): the impl
//!   had already freed every record - including those wrapped before the
//!   failure, which the wrapper cache owns - and the catch freed all of them
//!   a second time;
//! - invoking the callback failed after the sequence was made: every record
//!   was the wrapper cache's, and the catch freed them under it.
//!
//! And cloning the record queue appended each record `catch continue`: a
//! record the clone could not hold was dropped from both, never delivered and
//! never freed.
//!
//! The sweep: a script queues three records for an observer, and its end
//! runs the notify microtask; each round fails the i-th allocation from that
//! script on, and every one after it, until the round ends - so the rounds
//! walk through queueing the records, the notify's clone, the wrapping and
//! the callback. The Browser allocates from a FailingAllocator over a
//! DebugAllocator: a double free is the DebugAllocator's error report (or a
//! crash), a dropped record its leak report at the end. Before the sweep, a
//! control with memory to spare: the three records are delivered in one
//! call. After it, the observer still delivers.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const Browser = @import("browser").Browser;

const page_url = "https://leaks6.test/page.html";

fn ignoreReport(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn evaluate(realm: runtime.Context, allocator: std.mem.Allocator, source: []const u8) ![]u8 {
    return engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, allocator, .{ .report = ignoreReport });
}

fn expectAnswer(realm: runtime.Context, allocator: std.mem.Allocator, source: []const u8, want: []const u8) !void {
    const got = try evaluate(realm, allocator, source);
    defer allocator.free(got);
    if (!std.mem.eql(u8, want, got)) std.debug.print("{s}\n  answered {s}\n", .{ source, got });
    try testing.expectEqualStrings(want, got);
}

const queue_three = "t.setAttribute('a', ++k); t.setAttribute('b', k); t.setAttribute('c', k); String(seen)";

fn sweep(rounds: usize) !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    var leaked = false;
    defer if (leaked) std.debug.print("the sweep's Browser leaked\n", .{});
    {
        var failing = std.testing.FailingAllocator.init(debug.allocator(), .{});
        const browser = try Browser.init(failing.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body><div id=t></div>", .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        const realm = browser.getRealm() orelse return error.NoRealm;
        const agent = realm.agent orelse return error.NoAgent;
        const allocator = std.heap.c_allocator;

        try expectAnswer(realm, allocator,
            \\globalThis.t = document.getElementById('t'); globalThis.k = 0; globalThis.seen = 0; globalThis.calls = 0;
            \\globalThis.mo = new MutationObserver(records => { calls++; seen += records.length; });
            \\mo.observe(t, { attributes: true }); 'ok'
        , "ok");

        // The control: the three records are delivered in one call (the
        // script reads `seen` before its end runs the notify microtask).
        try expectAnswer(realm, allocator, queue_three, "0");
        try engine.performMicrotaskCheckpoint(agent);
        try expectAnswer(realm, allocator, "calls + ',' + seen", "1,3");

        // Each round fails the i-th allocation from the script that queues
        // the records on, and every one after it: queueing the records,
        // then the notify microtask the script's end runs (a checkpoint
        // after it runs whatever is left).
        var round: usize = 0;
        while (round < rounds) : (round += 1) {
            failing.has_induced_failure = false;
            failing.fail_index = failing.alloc_index + round;
            if (evaluate(realm, allocator, queue_three)) |pending| allocator.free(pending) else |_| {}
            engine.performMicrotaskCheckpoint(agent) catch {};
            failing.fail_index = std.math.maxInt(usize);
            // Whatever the round left pending is delivered now.
            try engine.performMicrotaskCheckpoint(agent);
            // A sweep past the last allocation fails nothing.
            if (!failing.has_induced_failure) break;
        } else return error.SweepDidNotEnd;
        // The sweep failed something: the rounds reached the notify.
        if (round < 3) {
            std.debug.print("the sweep ended after {d} rounds\n", .{round});
            return error.SweepFailedNothing;
        }

        // After the sweep, the observer still works.
        const before = try evaluate(realm, allocator, "String(seen)");
        defer allocator.free(before);
        try expectAnswer(realm, allocator, queue_three, before);
        try engine.performMicrotaskCheckpoint(agent);
        const want = try std.fmt.allocPrint(allocator, "{d}", .{(try std.fmt.parseInt(usize, before, 10)) + 3});
        defer allocator.free(want);
        try expectAnswer(realm, allocator, "String(seen)", want);
    }
    leaked = debug.deinit() == .leak;
    if (leaked) return error.Leaked;
}

test "leaks6 MutationObserver: an out-of-memory notify frees each record once and drops none" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            sweep(400) catch |err| {
                std.debug.print("the sweep failed: {s}\n", .{@errorName(err)});
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

/// The engine-failure path, which WPT pages reach: the observer's callback
/// is a function of a frame's realm, and the frame was removed before the
/// notify microtask - "a Window whose associated Document is not fully
/// active runs nothing" (engine.invokeCallbackFunction: OperationFailed).
/// The records were wrapped by then: the sequence was made first. The catch
/// in notifyMutationObservers freed them under the wrapper cache, which frees
/// each again when its wrapper goes - a double free, or a use after free.
fn notFullyActive() !void {
    var debug: std.heap.DebugAllocator(.{ .stack_trace_frames = 0 }) = .init;
    {
        const browser = try Browser.init(debug.allocator(), .{ .persist_storage = false, .snapshot_path = "" });
        defer browser.deinit();
        try browser.navigateWithOptions(page_url, .window, .{ .skip_load = true });
        const page = browser.current_context orelse return error.NoPage;
        try page.loadHTML("<!doctype html><body><div id=t></div>", .{ .base_url = page_url });
        _ = try browser.runEventLoopBlocking(10);
        const realm = browser.getRealm() orelse return error.NoRealm;
        const agent = realm.agent orelse return error.NoAgent;
        const allocator = std.heap.c_allocator;
        for (0..8) |_| {
            try expectAnswer(realm, allocator,
                \\(() => {
                \\  const t = document.getElementById('t');
                \\  const f = document.body.appendChild(document.createElement('iframe'));
                \\  const callback = f.contentWindow.eval('(function () { top.ran = true; })');
                \\  const mo = new MutationObserver(callback);
                \\  mo.observe(t, { attributes: true });
                \\  t.setAttribute('a', String(Math.random()));
                \\  t.setAttribute('b', String(Math.random()));
                \\  f.remove();
                \\  return 'queued';
                \\})()
            , "queued");
            try engine.performMicrotaskCheckpoint(agent);
            _ = try browser.runEventLoopBlocking(10);
        }
        // Nothing ran in the removed frames' realms.
        try expectAnswer(realm, allocator, "String(globalThis.ran)", "undefined");
        // The wrappers go: each record's wrapper is collected and frees it.
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                const a: *engine.Agent = @ptrCast(@alignCast(data.?));
                engine.requestGarbageCollection(a);
                engine.requestGarbageCollection(a);
            }
        };
        try engine.runInRealm(realm, Collect.steps, agent);
        _ = try browser.runEventLoopBlocking(10);
    }
    if (debug.deinit() == .leak) return error.Leaked;
}

test "leaks6 MutationObserver: a callback whose realm is not fully active frees each record once" {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            notFullyActive() catch |err| {
                std.debug.print("the not-fully-active run failed: {s}\n", .{@errorName(err)});
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}
