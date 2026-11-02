//! ReadableStream.from(iterable): the iterator's own next() - or a getter on
//! its result - can cancel the stream it feeds, and the pull that called it
//! goes on with the source.
//!
//! `reader.cancel()` runs the controller's [[CancelSteps]]: the cancel
//! algorithm (the iterator's return()), then
//! ReadableStreamDefaultControllerClearAlgorithms - which frees the
//! ReadableStreamFromIterable source and its Iterator Record. When the
//! cancel comes from inside the pull's own IteratorNext, that free happens
//! while the pull is still in the middle of the call: IteratorNext reads the
//! record after next() returns (the async-from-sync continuation reads
//! [[Iterator]] after the result's "done" and "value" getters), and the pull
//! algorithm reads the source's realm for its reaction. Spec-wise nothing
//! ends there - the pull's steps are a closure over iteratorRecord, and they
//! run to their end (Streams 4.9.1 ReadableStreamFromIterable step 4) - so
//! the source must outlive every call into the iterator that is in
//! progress. Gecko holds it the same way: CallPullIfNeeded and CancelSteps
//! take a RefPtr to the controller's algorithms across the call
//! (dom/streams/ReadableStreamDefaultController.cpp).
//!
//! WPT: streams/readable-streams/from.any.js "reader.cancel() inside next()"
//! (a SIGSEGV in a sweep, 2026-11-02: the record's page unmapped under
//! protocol_conversions.iteratorNextValue). Each realm here allocates with
//! the testing allocator, so a freed source is filled with undefined bytes
//! and read through at once, and a source never freed is a leak.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

fn evaluate(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const answer = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "crashes6-from.js", null, std.testing.allocator, reports.reporter());
    errdefer std.testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    return answer;
}

/// Runs `setup` in a fresh realm, settles every microtask, then expects
/// `check` to evaluate to `expected` (the log sorted: what the order of
/// promise jobs is, is not what these tests are about).
fn expectAfterSettling(setup: []const u8, check: []const u8, expected: []const u8) !void {
    try engine.initializeEngine(.{});
    const own_runtime = test_process.OwnRuntime.begin(std.testing.allocator);
    defer own_runtime.end();
    interfaces.process_hooks.startHooksForTest();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://crashes6.test", .create_global_object = createGlobal });
    defer engine.destroyWindowRealm(realm, .global_detached);

    std.testing.allocator.free(try evaluate(realm, setup));
    for (0..16) |_| try engine.performMicrotaskCheckpoint(agent);
    const got = try evaluate(realm, check);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

/// On a thread of its own: a fresh per-thread engine state, as each test
/// here may assume nothing a test before it made.
fn onThread(comptime setup: []const u8, comptime check: []const u8, comptime expected: []const u8) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = expectAfterSettling(setup, check, expected);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

test "an async iterator's next() that cancels the stream: the pull finishes and the read is done" {
    // from.any.js "reader.cancel() inside next()".
    try onThread(
        \\globalThis.log = [];
        \\let reader;
        \\const iterable = {
        \\  async next() {
        \\    log.push('next');
        \\    await reader.cancel();
        \\    log.push('cancelled');
        \\    return { value: 'something else', done: false };
        \\  },
        \\  async return() { log.push('return'); return { done: true }; },
        \\  [Symbol.asyncIterator]: () => iterable,
        \\};
        \\reader = ReadableStream.from(iterable).getReader();
        \\reader.read().then((r) => log.push('read:' + r.done + ':' + r.value));
        \\reader.closed.then(() => log.push('closed'));
        \\'ok'
    , "log.sort().join(',')", "cancelled,closed,next,read:true:undefined,return");
}

test "a sync iterator's next() that cancels the stream: the async-from-sync continuation finishes" {
    // The record is read after next() returns: AsyncFromSyncIteratorContinuation
    // closes over [[Iterator]] for its rejection steps.
    try onThread(
        \\globalThis.log = [];
        \\let reader;
        \\const iterable = {
        \\  [Symbol.iterator]() {
        \\    return {
        \\      next() { log.push('next'); reader.cancel(); return { value: 1, done: false }; },
        \\      return() { log.push('return'); return { done: true }; },
        \\    };
        \\  },
        \\};
        \\reader = ReadableStream.from(iterable).getReader();
        \\reader.read().then((r) => log.push('read:' + r.done + ':' + r.value));
        \\'ok'
    , "log.sort().join(',')", "next,read:true:undefined,return");
}

test "a getter on a sync iterator's result that cancels the stream" {
    // IteratorComplete's Get runs script after IteratorNext returned.
    try onThread(
        \\globalThis.log = [];
        \\let reader;
        \\const iterable = {
        \\  [Symbol.iterator]() {
        \\    return {
        \\      next() {
        \\        log.push('next');
        \\        return { get done() { log.push('done?'); reader.cancel(); return false; }, value: 2 };
        \\      },
        \\    };
        \\  },
        \\};
        \\reader = ReadableStream.from(iterable).getReader();
        \\reader.read().then((r) => log.push('read:' + r.done + ':' + r.value));
        \\'ok'
    , "log.sort().join(',')", "done?,next,read:true:undefined");
}

test "an async iterator's next() that cancels the stream and then throws" {
    // IteratorNext's throw completion sets [[Done]] on the record after the
    // call; the pull's promise rejects, on a stream already closed.
    try onThread(
        \\globalThis.log = [];
        \\let reader;
        \\const iterable = {
        \\  next() { log.push('next'); reader.cancel(); throw new Error('after cancel'); },
        \\  return() { log.push('return'); return Promise.resolve({ done: true }); },
        \\  [Symbol.asyncIterator]: () => iterable,
        \\};
        \\reader = ReadableStream.from(iterable).getReader();
        \\reader.read().then((r) => log.push('read:' + r.done), (e) => log.push('rejected:' + e.message));
        \\reader.closed.then(() => log.push('closed'), (e) => log.push('errored:' + e.message));
        \\'ok'
    , "log.sort().join(',')", "closed,next,read:true,return");
}

test "a stream cancelled from next() still cancels once: a second cancel inside return() is a no-op" {
    // The source is cleared while next() runs; the later settling of next()'s
    // promise enqueues nothing into the closed stream and calls nothing more.
    try onThread(
        \\globalThis.log = [];
        \\let reader;
        \\let calls = 0;
        \\const iterable = {
        \\  next() {
        \\    calls++;
        \\    log.push('next' + calls);
        \\    reader.cancel('why');
        \\    return new Promise((resolve) => Promise.resolve().then(() => resolve({ value: 'late', done: false })));
        \\  },
        \\  return(reason) { log.push('return:' + reason); reader.cancel('again'); return { done: true }; },
        \\  [Symbol.asyncIterator]: () => iterable,
        \\};
        \\reader = ReadableStream.from(iterable).getReader();
        \\reader.read().then((r) => log.push('read:' + r.done));
        \\'ok'
    , "log.sort().join(',')", "next1,read:true,return:why");
}
