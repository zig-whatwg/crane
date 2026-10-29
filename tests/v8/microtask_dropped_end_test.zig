//! A microtask that carries heap data needs a dropped end (lane leaks1,
//! 2026-10-29).
//!
//! `engine.queueMicrotask` has none: a microtask still queued when its agent's
//! queue is discarded - a terminated checkpoint (a worker's termination, a
//! runaway script's deadline: V8 deletes the rest of its queue) or the agent's
//! end - never runs and never tells the host, so the data it was handed leaks.
//! The protocol says so (engine_protocol.zig, queueMicrotask) and names
//! `queueRealmMicrotask`, whose `dropped` step runs instead. Every test here
//! queues one of the microtasks that carried heap data through the old
//! operation, then ends the agent's checkpoint or the realm before it runs.
//!
//! What found it: three `leaked:` reports with empty stacks at the end of WPT
//! runner processes over the FileAPI/accname/console/CSP head of the worklist
//! (rows 124/125, three times). A Debug runner with CRANE_LEAK_TRACES and
//! CRANE_LEAK_FILES named them: fetch_body's FullRead, its Deferred and its
//! bytes, allocated while FileAPI/BlobURL/cross-partition.https.html ran -
//! whose dispatcher executors poll with fetch().text() in workers that the
//! test's end terminates. The same runs found a double free of fetch_body's
//! PipeStream: CreateReadableByteStream failed after its controller was
//! wrapped, and both the caller and the controller freed the source.
//!
//! Each test runs on a thread of its own with a runtime, an agent and a
//! Window realm on std.testing.allocator: what the realm's end does not free
//! is reported as leaked, a second free as a double free.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}

fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn evaluate(realm: runtime.Context, source: []const u8) !engine.Owned {
    return engine.evaluateClassicScript(realm, .{ .utf8 = source }, "leaks1-microtask.js", null, .{ .report = report });
}

/// Run `source`; an exception it throws fails the test, with its message.
fn run(realm: runtime.Context, comptime source: []const u8) !void {
    const got = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = "(() => { try {\n" ++ source ++ "\n} catch (e) { return String(e); } return 'ok'; })()" }, "leaks1-microtask.js", null, std.testing.allocator, .{ .report = report });
    defer std.testing.allocator.free(got);
    if (!std.mem.eql(u8, got, "ok")) {
        std.debug.print("setup script threw: {s}\n", .{got});
        return error.SetupScriptThrew;
    }
}

/// `body` in a leak-checked agent and Window realm, on a thread of its own
/// (tests/v8 is one process: the testing allocator's lock and traces must
/// not be shared with another file's agent). The realm ends after `body`.
fn inRealm(comptime body: fn (*engine.Agent, runtime.Context) anyerror!void) !void {
    return inRealmEnding(body, false);
}

/// `inRealm`, where `body_ends_realm` says `body` ends the realm itself.
fn inRealmEnding(comptime body: fn (*engine.Agent, runtime.Context) anyerror!void, comptime body_ends_realm: bool) !void {
    const Run = struct {
        fn thread(result: *anyerror!void) void {
            result.* = check();
        }

        fn check() !void {
            try engine.initializeEngine(.{});
            runtime.initializeRuntime(std.testing.allocator);
            defer runtime.deinitializeRuntime();
            interfaces.process_hooks.startHooksForTest();
            // The thread's mutation observer agent, made on this thread's
            // first mutation with the realm's allocator.
            defer dom.mutation_observer_algorithms.resetAgent();
            const hooks: engine.HostHooks = .{};
            const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
            defer engine.destroyAgent(agent);
            const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://leaks1.test", .create_global_object = createGlobal });
            defer if (!body_ends_realm) engine.destroyWindowRealm(realm, .global_detached);
            try body(agent, realm);
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.thread, .{&result});
    thread.join();
    try result;
}

/// `abortAgent()`: engine.abortRunningScript on the agent, as a worker's
/// termination and a script deadline do.
fn abortSteps(data: ?*anyopaque, _: []const runtime.JSValue) runtime.EngineError!runtime.JSValue {
    engine.abortRunningScript(@ptrCast(@alignCast(data.?)));
    return .undefined;
}

/// Run `source` behind a microtask that aborts the agent's script: every
/// microtask `source` queues waits behind it, and the aborted checkpoint
/// discards them. Then let the agent run script again.
fn runThenAbortCheckpoint(agent: *engine.Agent, realm: runtime.Context, comptime source: []const u8) !void {
    var abort_function: runtime.BuiltinFunction = .{ .steps = abortSteps, .data = agent };
    try engine.defineBuiltinFunction(realm, "abortAgent", 0, &abort_function);
    // The script's own clean-up runs the checkpoint; it may end abruptly.
    if (evaluate(realm, "queueMicrotask(() => { abortAgent(); for (;;) {} });\n" ++ source)) |value| value.release() else |_| {}
    engine.resumeScripts(agent);
}

fn platformObject(realm: runtime.Context, source: []const u8) !*runtime.Instance {
    const value = try evaluate(realm, source);
    defer value.release();
    return engine.convertToPlatformObject(realm, value.value) orelse error.NotAPlatformObject;
}

// =============================================================================
// fetch_body's read loop (Fetch "fully read body")
// =============================================================================

test "a body read whose next step was queued when the checkpoint was aborted is freed" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            // The body's stream made, and started at the script's checkpoint.
            try run(realm, "globalThis.r = new Response('abc'); r.body;");
            // text()'s first read gets the body's bytes at once; the read
            // loop's next step is a microtask behind the abort.
            try runThenAbortCheckpoint(agent, realm, "r.text();");
        }
    }.body);
}

test "a body read whose next step is queued when its realm ends is freed" {
    try inRealm(struct {
        fn body(_: *engine.Agent, realm: runtime.Context) !void {
            const response = try platformObject(realm, "globalThis.r = new Response('abc'); r.body; r");
            // From native code no checkpoint follows: the realm ends with the
            // read loop's next step queued.
            const promise = try interfaces.Response.call_text(response);
            engine.releaseValue(.{ .value = promise });
        }
    }.body);
}

// =============================================================================
// CreateReadableByteStream's failure
// =============================================================================

/// What the realm microtask below saw: dropped at the realm's end, after its
/// reactions ended (none can be added) but while its objects live.
///
/// The body's stream is made there, and its setup fails after its controller
/// exists: the realm has left the context manager, so a wrap answers
/// undefined and makes no wrapper (the stream and the controller are nobody's
/// but this call's), and the start reaction is refused (the realm's
/// reactions have ended). Before the fix the caller freed the source and the
/// controller kept it: here the stream and the controller leak, because the
/// realm's orphan sweep already ran; in the WPT runner a worker's termination
/// fails the same setup (every API call refused) BEFORE that sweep, which
/// then tore the controller down and freed the source a second time - the
/// double free of PipeStream the Debug runs showed, 3 times in 24.
const BodyAtRealmEnd = struct {
    response: *runtime.Instance,
    ran: bool = false,
    dropped: bool = false,

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *BodyAtRealmEnd = @ptrCast(@alignCast(data.?));
        self.ran = true;
    }

    /// Make the body's stream now.
    fn readBody(data: ?*anyopaque) void {
        const self: *BodyAtRealmEnd = @ptrCast(@alignCast(data.?));
        self.dropped = true;
        _ = interfaces.Response.get_body(self.response) catch null;
    }

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .dropped = readBody };
};

test "a byte stream whose setup fails after its controller exists leaves nothing holding its source" {
    try inRealmEnding(struct {
        fn body(_: *engine.Agent, realm: runtime.Context) !void {
            const response = try platformObject(realm, "globalThis.r = new Response('abc'); r");
            const seen = try std.testing.allocator.create(BodyAtRealmEnd);
            defer std.testing.allocator.destroy(seen);
            seen.* = .{ .response = response };
            try engine.queueRealmMicrotask(realm, &BodyAtRealmEnd.steps, seen);
            // The realm ends with it queued.
            engine.destroyWindowRealm(realm, .global_detached);
            try std.testing.expect(seen.dropped and !seen.ran);
        }
    }.body, true);
}

// =============================================================================
// The tee's chunk steps (Streams ReadableStreamDefaultTee / ReadableByteStreamTee:
// "queue a microtask to perform the following steps")
// =============================================================================

test "a default tee's chunk queued when the checkpoint was aborted is freed" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            // The tee's own read waits on the source: the chunk comes after
            // the abort is queued, and its chunk steps queue behind it.
            try run(realm,
                \\globalThis.s = new ReadableStream({ start(c) { globalThis.ctl = c; } });
                \\globalThis.t = s.tee();
                \\globalThis.rd = t[0].getReader();
                \\rd.read();
            );
            try runThenAbortCheckpoint(agent, realm, "ctl.enqueue('x');");
        }
    }.body);
}

test "a byte tee's chunk for a default reader queued when the checkpoint was aborted is freed" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            try run(realm,
                \\globalThis.t = new Response('abc').body.tee();
                \\globalThis.rd = t[0].getReader();
            );
            try runThenAbortCheckpoint(agent, realm, "rd.read();");
        }
    }.body);
}

test "a byte tee's chunk for a BYOB reader queued when the checkpoint was aborted is freed" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            try run(realm,
                \\globalThis.t = new Response('abc').body.tee();
                \\globalThis.rd = t[0].getReader({ mode: 'byob' });
            );
            try runThenAbortCheckpoint(agent, realm, "rd.read(new Uint8Array(8));");
        }
    }.body);
}

// =============================================================================
// queueMicrotask() and the mutation observer microtask
// =============================================================================

test "a queueMicrotask() callback discarded with an aborted checkpoint is freed" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            try runThenAbortCheckpoint(agent, realm, "queueMicrotask(() => {});");
        }
    }.body);
}

test "a mutation observer microtask discarded with an aborted checkpoint leaves nothing behind" {
    try inRealm(struct {
        fn body(agent: *engine.Agent, realm: runtime.Context) !void {
            try run(realm,
                \\globalThis.d = new Document();
                \\globalThis.n = d.createTextNode('a');
                \\globalThis.mo = new MutationObserver(() => {});
                \\mo.observe(n, { characterData: true });
            );
            try runThenAbortCheckpoint(agent, realm, "n.data = 'b';");
        }
    }.body);
}
