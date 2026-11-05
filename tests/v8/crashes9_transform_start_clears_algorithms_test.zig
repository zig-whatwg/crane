//! `new TransformStream(transformer)`: transformer.start() may terminate or
//! error the stream it is starting, and the constructor goes on after the
//! call.
//!
//! controller.terminate() and controller.error() run
//! TransformStreamErrorWritableAndUnblockWrite, whose step 1 is
//! TransformStreamDefaultControllerClearAlgorithms - which frees the
//! controller's algorithms. In Crane those were the converted Transformer
//! dictionary itself (JsTransformer), and the constructor's steps 12-13 ran
//! start() through that same dictionary (`callStart`), then read it again
//! after the call returned: a read of freed memory whenever start() cleared
//! the algorithms. Spec-wise step 12 invokes transformerDict["start"] with
//! callback this value `transformer` - the constructor's own values, which
//! ClearAlgorithms does not touch (Streams § 6.2.4 constructor steps 11-13,
//! § 6.4.2 TransformStreamDefaultControllerClearAlgorithms). Gecko calls the
//! constructor's local RootedDictionary's mStart with `transformerObj`
//! (dom/streams/TransformStream.cpp, TransformStream::Constructor step 12);
//! Blink runs a separate start algorithm object it holds on the stack
//! (core/streams/transform_stream.cc, InitInternal).
//!
//! WPT: streams/transform-streams/{terminate,errors,general}.any.js crashed in
//! the 2026-11-05 sweep at 0xdddddddddddddded once the correctness runner
//! poisoned freed blocks (lane crashes9). Each realm here allocates with the
//! testing allocator, which fills a freed block, so a read through the freed
//! dictionary faults at once, and anything never freed is a leak.

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
    const answer = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "crashes9-transform-start.js", null, std.testing.allocator, reports.reporter());
    errdefer std.testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    return answer;
}

/// Runs `setup` in a fresh realm, settles every microtask, then expects
/// `check` to evaluate to `expected` (the log sorted: the order of promise
/// jobs is not what these tests are about).
fn expectAfterSettling(setup: []const u8, check: []const u8, expected: []const u8) !void {
    test_process.start();
    const own_runtime = test_process.OwnRuntime.begin(std.testing.allocator);
    defer own_runtime.end();
    interfaces.process_hooks.startHooksForTest();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://crashes9.test", .create_global_object = createGlobal });
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

test "start() that terminates the stream: the constructor finishes, the chunk is read, enqueue throws" {
    // terminate.any.js "controller.enqueue() should throw after controller.terminate()".
    try onThread(
        \\globalThis.log = [];
        \\const ts = new TransformStream({
        \\  start(c) {
        \\    c.enqueue(0);
        \\    c.terminate();
        \\    try { c.enqueue(1); log.push('enqueued'); } catch (e) { log.push('enqueue:' + e.name); }
        \\  },
        \\});
        \\const reader = ts.readable.getReader();
        \\reader.read().then((r) => log.push('read:' + r.value + ':' + r.done));
        \\reader.read().then((r) => log.push('read2:' + r.done));
        \\ts.writable.getWriter().closed.catch((e) => log.push('writable:' + e.name));
        \\'ok'
    , "log.sort().join(',')", "enqueue:TypeError,read2:true,read:0:false,writable:TypeError");
}

test "start() that terminates twice, with every other transformer method present" {
    // general.any.js "controller.terminate() should do nothing the second
    // time it is called" - transform, flush and cancel keep `this` for their
    // calls, so the constructor used to read the freed dictionary's members.
    try onThread(
        \\globalThis.log = [];
        \\const ts = new TransformStream({
        \\  start(c) { c.terminate(); c.terminate(); log.push('started'); },
        \\  transform() { log.push('transform'); },
        \\  flush() { log.push('flush'); },
        \\  cancel() { log.push('cancel'); },
        \\});
        \\ts.readable.getReader().closed.then(() => log.push('closed'));
        \\'ok'
    , "log.sort().join(',')", "closed,started");
}

test "start() that errors the stream: later enqueues throw and both sides error" {
    // errors.any.js "errored TransformStream should not enqueue new chunks".
    try onThread(
        \\globalThis.log = [];
        \\const ts = new TransformStream({
        \\  start(c) {
        \\    c.enqueue('a');
        \\    c.error(new Error('generic error'));
        \\    try { c.enqueue('b'); log.push('enqueued'); } catch (e) { log.push('enqueue:' + e.name); }
        \\  },
        \\  cancel() { log.push('cancel'); },
        \\});
        \\ts.readable.getReader().closed.catch((e) => log.push('readable:' + e.message));
        \\ts.writable.getWriter().closed.catch((e) => log.push('writable:' + e.message));
        \\'ok'
    , "log.sort().join(',')", "enqueue:TypeError,readable:generic error,writable:generic error");
}

test "start() whose enqueue meets a throwing size(): the constructor throws that error" {
    // errors.any.js "when strategy.size throws inside start(), the
    // constructor should throw the same error": the enqueue's abrupt
    // completion runs TransformStreamErrorWritableAndUnblockWrite, which
    // clears the algorithms inside start().
    try onThread(
        \\globalThis.log = [];
        \\try {
        \\  new TransformStream({ start(c) { c.enqueue('a'); }, transform() {} }, undefined, {
        \\    size() { throw new URIError('size thrown error'); },
        \\  });
        \\  log.push('constructed');
        \\} catch (e) {
        \\  log.push('threw:' + e.name);
        \\}
        \\'ok'
    , "log.sort().join(',')", "threw:URIError");
}

test "start() that errors the stream and then throws: the constructor throws start's error" {
    // The completion is start()'s own throw, after the algorithms were cleared.
    try onThread(
        \\globalThis.log = [];
        \\try {
        \\  new TransformStream({
        \\    start(c) { c.error(new Error('first')); throw new RangeError('second'); },
        \\    flush() {},
        \\  });
        \\  log.push('constructed');
        \\} catch (e) {
        \\  log.push('threw:' + e.name + ':' + e.message);
        \\}
        \\'ok'
    , "log.sort().join(',')", "threw:RangeError:second");
}

test "start() that leaves the algorithms: transform, flush and cancel still run with the transformer as this" {
    // The constructor's start call and the controller's algorithms each see
    // `transformer` as their callback this value (§ 6.4.2
    // SetUpTransformStreamDefaultControllerFromTransformer steps 5-7).
    try onThread(
        \\globalThis.log = [];
        \\const transformer = {
        \\  tag: 'T',
        \\  start(c) { log.push('start:' + this.tag); },
        \\  transform(chunk, c) { log.push('transform:' + this.tag + ':' + chunk); c.enqueue(chunk); },
        \\  flush(c) { log.push('flush:' + this.tag); },
        \\};
        \\const ts = new TransformStream(transformer);
        \\const writer = ts.writable.getWriter();
        \\const reader = ts.readable.getReader();
        \\writer.write('a');
        \\writer.close();
        \\reader.read().then((r) => log.push('read:' + r.value));
        \\reader.read().then((r) => log.push('read2:' + r.done));
        \\'ok'
    , "log.sort().join(',')", "flush:T,read2:true,read:a,start:T,transform:T:a");
}
