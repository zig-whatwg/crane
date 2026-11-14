//! What a realm's end finalizes that no wrapper owns: the host data behind a
//! promise reaction that has not run (engine.PromiseReactionSteps.dropped)
//! and behind an asynchronous iterator still alive
//! (engine.AsyncIteratorSteps.finalize).
//!
//! Before: a reaction on a promise that never settled kept its host data
//! forever - streams' pipeTo PipeState and Deferreds, tee state, from()'s
//! pull steps - and an iterator script still held at the page's end kept its
//! reader. Each run of the WPT runner reported them as `leaked:` at exit
//! (streams/readable-byte-streams/tee 74, readable-streams/async-iterator
//! 82, ...). The protocol now says: for every reactToPromise that succeeded,
//! exactly one of fulfilled, rejected and dropped runs, once; an iterator's
//! finalize runs when it is collected or when its realm ends, whichever is
//! first.
//!
//! The realms are made and ended the way a page's are (createWindowRealm,
//! destroyWindowRealm), so their end goes through the context manager and
//! the realm's wrapper cache.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const ffi = v8.ffi;
const protocol = @import("engine");

/// The hooks of the file's agent: none.
const window_agent_hooks: protocol.HostHooks = .{};
const interfaces = @import("interfaces");

/// The test's isolate and bootstrap context: its own agent's (test_agent),
/// ended with the test.
var test_isolate: ?*ffi.Isolate = null;
var test_context: ?*ffi.Context = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_isolate = null;
    test_context = null;
}

fn agent() !*ffi.Isolate {
    const i = try test_agent.open(.{ .hooks = &window_agent_hooks });
    if (test_isolate == null) {
        const context = test_agent.context.?;
        _ = try v8.context_manager.getOrCreate(context, std.heap.page_allocator);
        test_isolate = i;
        test_context = context;
    }
    return test_isolate.?;
}

/// The test's host for a Window realm: it makes the realm's Window.
const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// A Window realm, made as a navigation makes one.
fn windowRealm() !runtime.Context {
    return windowRealmIn(null);
}

/// A Window realm whose navigable's parent's realm is `parent` - an iframe's:
/// it shares its parent's engine-level access, as a same-origin frame does.
fn frameRealm(parent: runtime.Context) !runtime.Context {
    return windowRealmIn(parent);
}

fn windowRealmIn(parent: ?runtime.Context) !runtime.Context {
    const isolate = try agent();
    return protocol.createWindowRealm(&.{
        .agent = @ptrCast(isolate),
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .global_this = .new_window_proxy,
        .parent = parent,
        .create_global_object = WindowHost.createGlobalObject,
        .host = null,
    });
}

const Ignored = struct {
    fn report(_: ?*anyopaque, _: *const protocol.ErrorInfo) void {}
    const reporter: protocol.Reporter = .{ .report = report, .host = null };
};

fn evalOwned(r: runtime.Context, source: []const u8) !protocol.Owned {
    return protocol.evaluateClassicScript(r, .{ .utf8 = source }, "", null, Ignored.reporter);
}

fn run(r: runtime.Context, source: []const u8) !void {
    try protocol.runClassicScript(r, .{ .utf8 = source }, "", null, Ignored.reporter);
}

fn evalString(r: runtime.Context, source: []const u8) ![]u8 {
    return protocol.evaluateClassicScriptToString(r, .{ .utf8 = source }, "", null, std.testing.allocator, Ignored.reporter);
}

fn expectEval(r: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evalString(r, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

fn collect() void {
    ffi.v8_Isolate_RequestGarbageCollection(test_isolate.?);
}

// ============================================================================
// Promise reactions
// ============================================================================

/// What a reaction's steps saw.
const Reaction = struct {
    fulfilled: usize = 0,
    rejected: usize = 0,
    dropped: usize = 0,
    dropped_in_first_pass: bool = false,

    fn onFulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Reaction = @ptrCast(@alignCast(data.?));
        self.fulfilled += 1;
    }

    fn onRejected(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Reaction = @ptrCast(@alignCast(data.?));
        self.rejected += 1;
    }

    fn onDropped(data: ?*anyopaque) void {
        const self: *Reaction = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
        if (ffi.v8_Debug_InFirstPassWeakCallback()) self.dropped_in_first_pass = true;
    }

    const all: protocol.PromiseReactionSteps = .{ .fulfilled = onFulfilled, .rejected = onRejected, .dropped = onDropped };
    const fulfilled_only: protocol.PromiseReactionSteps = .{ .fulfilled = onFulfilled, .dropped = onDropped };

    fn total(self: Reaction) usize {
        return self.fulfilled + self.rejected + self.dropped;
    }
};

test "a reaction on a promise that never settles is dropped once when its realm ends" {
    defer test_agent.close();
    const w = try windowRealm();
    var capability = try protocol.createPromise(w);
    defer protocol.releasePromiseCapability(&capability);
    var reaction: Reaction = .{};
    try protocol.reactToPromise(w, capability.promise, &Reaction.all, &reaction);

    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
    // Nothing more, whatever the collector does later.
    collect();
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}

test "a reaction whose promise settles runs its step once and is never dropped" {
    defer test_agent.close();
    const w = try windowRealm();
    var capability = try protocol.createPromise(w);
    defer protocol.releasePromiseCapability(&capability);
    var reaction: Reaction = .{};
    try protocol.reactToPromise(w, capability.promise, &Reaction.all, &reaction);
    try protocol.resolvePromise(&capability, runtime.JSValue.fromNumber(3));
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), reaction.fulfilled);

    protocol.destroyWindowRealm(w, .global_detached);
    collect();
    try std.testing.expectEqual(@as(usize, 0), reaction.dropped);
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}

test "a reaction whose outcome has no step given is dropped once when its promise settles" {
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    var capability = try protocol.createPromise(w);
    defer protocol.releasePromiseCapability(&capability);
    var reaction: Reaction = .{};
    try protocol.reactToPromise(w, capability.promise, &Reaction.fulfilled_only, &reaction);
    const reason = try protocol.createSimpleException(w, .TypeError, "no");
    defer reason.release();
    try protocol.rejectPromise(&capability, reason.value);
    try protocol.performMicrotaskCheckpoint(w.agent.?);
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}

test "a reaction collected with its promise unsettled is dropped once, after the collection" {
    defer test_agent.close();
    const w = try windowRealm();
    var reaction: Reaction = .{};
    {
        const promise = try evalOwned(w, "new Promise(() => {})");
        defer promise.release();
        try protocol.reactToPromise(w, promise.value, &Reaction.all, &reaction);
    }
    collect();
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);
    try std.testing.expect(!reaction.dropped_in_first_pass);
    // The realm's end finds nothing left to drop.
    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}

test "a reaction of an ended realm on another realm's promise does nothing when that promise settles" {
    defer test_agent.close();
    const page = try windowRealm();
    defer protocol.destroyWindowRealm(page, .global_detached);
    var capability = try protocol.createPromise(page);
    defer protocol.releasePromiseCapability(&capability);

    const frame = try frameRealm(page);
    var reaction: Reaction = .{};
    try protocol.reactToPromise(frame, capability.promise, &Reaction.all, &reaction);
    protocol.destroyWindowRealm(frame, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);

    // The page's promise still holds the frame's reaction functions: settling
    // it runs them, and they find the reaction gone.
    try protocol.resolvePromise(&capability, runtime.JSValue.fromNumber(1));
    try protocol.performMicrotaskCheckpoint(page.agent.?);
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}

test "reactToPromise on a realm that has ended fails, and the data stays the caller's" {
    defer test_agent.close();
    const page = try windowRealm();
    defer protocol.destroyWindowRealm(page, .global_detached);
    var capability = try protocol.createPromise(page);
    defer protocol.releasePromiseCapability(&capability);
    const frame = try frameRealm(page);
    protocol.destroyWindowRealm(frame, .global_detached);
    var reaction: Reaction = .{};
    try std.testing.expect(std.meta.isError(protocol.reactToPromise(frame, capability.promise, &Reaction.all, &reaction)));
    try std.testing.expectEqual(@as(usize, 0), reaction.total());
}

test "reactions settled, dropped by the realm's end or collected leave no global handle behind" {
    defer test_agent.close();
    const isolate = try agent();
    const round = struct {
        fn run(reactions: *[3]Reaction) !void {
            const w = try windowRealm();
            var settles = try protocol.createPromise(w);
            defer protocol.releasePromiseCapability(&settles);
            var pending = try protocol.createPromise(w);
            defer protocol.releasePromiseCapability(&pending);
            try protocol.reactToPromise(w, settles.promise, &Reaction.all, &reactions[0]);
            try protocol.reactToPromise(w, pending.promise, &Reaction.all, &reactions[1]);
            {
                const forgotten = try evalOwned(w, "new Promise(() => {})");
                defer forgotten.release();
                try protocol.reactToPromise(w, forgotten.value, &Reaction.all, &reactions[2]);
            }
            try protocol.resolvePromise(&settles, runtime.JSValue.fromNumber(1));
            try protocol.performMicrotaskCheckpoint(w.agent.?);
            protocol.destroyWindowRealm(w, .global_detached);
        }
    }.run;
    var reactions: [3]Reaction = .{ .{}, .{}, .{} };
    try round(&reactions);
    collect();
    // The agent's own global handles - a weak record's handle among them -
    // not the process's live weak records, which every Browser of the
    // process moves (beside the many-Browsers variant's busy Browser they
    // moved while this measured: docs/lessons/testing-a-test-that-measures-
    // a-process-wide-counter-assumes-it-is-alone.md).
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    const rounds = 16;
    for (0..rounds) |_| try round(&reactions);
    collect();
    const after = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (reactions) |r| try std.testing.expectEqual(@as(usize, rounds + 1), r.total());
    if (after > before) {
        std.debug.print("the agent's global handles {d} -> {d} bytes over {d} rounds\n", .{ before, after, rounds });
        return error.HandlesLeaked;
    }
}

// ============================================================================
// Asynchronous iterators
// ============================================================================

/// An asynchronous iterator's host side: counts what the engine called.
const Iterated = struct {
    nexts: usize = 0,
    finalized: usize = 0,
    finalized_in_first_pass: bool = false,
    realm: ?runtime.Context = null,

    fn next(data: ?*anyopaque) protocol.Error!protocol.Owned {
        const self: *Iterated = @ptrCast(@alignCast(data.?));
        self.nexts += 1;
        // A promise that never settles: the iterator stays busy.
        var capability = try protocol.createPromise(self.realm.?);
        defer protocol.releasePromiseCapability(&capability);
        return protocol.retainValue(self.realm.?, capability.promise);
    }

    fn finalize(data: ?*anyopaque) void {
        const self: *Iterated = @ptrCast(@alignCast(data.?));
        self.finalized += 1;
        if (ffi.v8_Debug_InFirstPassWeakCallback()) self.finalized_in_first_pass = true;
    }

    const steps: protocol.AsyncIteratorSteps = .{ .next = next, .finalize = finalize };
};

fn setGlobal(r: runtime.Context, name: []const u8, value: runtime.JSValue) !void {
    const context: *ffi.Context = @ptrCast(@alignCast(r.engine_ctx.?));
    const global = ffi.v8_Context_Global(context) orelse return error.NoGlobal;
    defer ffi.v8_Object_Dispose(global);
    const key = ffi.v8_String_NewFromUtf8(test_isolate.?, name.ptr, @intCast(name.len)) orelse return error.StringFailed;
    defer ffi.v8_String_Dispose(key);
    const handle: *ffi.Value = @ptrCast(@alignCast(value.handle.ptr));
    if (!ffi.v8_Object_Set(global, context, @ptrCast(key), handle)) return error.SetFailed;
}

test "an asynchronous iterator alive at its realm's end is finalized once, outside any collection" {
    defer test_agent.close();
    const w = try windowRealm();
    var iterated: Iterated = .{ .realm = w };
    {
        const iterator = try protocol.createAsyncIterator(w, &Iterated.steps, &iterated);
        defer iterator.release();
        // Script holds it: the collector will not take it before the end.
        try setGlobal(w, "held", iterator.value);
    }
    try run(w, "held.next();");
    try std.testing.expectEqual(@as(usize, 1), iterated.nexts);

    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), iterated.finalized);
    try std.testing.expect(!iterated.finalized_in_first_pass);
    collect();
    try std.testing.expectEqual(@as(usize, 1), iterated.finalized);
}

test "an asynchronous iterator of an ended realm never calls its steps again" {
    defer test_agent.close();
    const page = try windowRealm();
    defer protocol.destroyWindowRealm(page, .global_detached);
    const frame = try frameRealm(page);
    var iterated: Iterated = .{ .realm = frame };
    {
        const iterator = try protocol.createAsyncIterator(frame, &Iterated.steps, &iterated);
        defer iterator.release();
        // The page holds the frame's iterator past the frame's end.
        try setGlobal(page, "fromFrame", iterator.value);
    }
    protocol.destroyWindowRealm(frame, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), iterated.finalized);

    try run(page, "globalThis.outcome = 'none'; try { fromFrame.next().then(() => { outcome = 'fulfilled'; }, (e) => { outcome = e instanceof TypeError || e.name === 'TypeError' ? 'TypeError' : 'rejected'; }); } catch (e) { outcome = 'threw'; }");
    try protocol.performMicrotaskCheckpoint(page.agent.?);
    try std.testing.expectEqual(@as(usize, 0), iterated.nexts);
    try std.testing.expectEqual(@as(usize, 1), iterated.finalized);
    try run(page, "delete globalThis.fromFrame;");
    collect();
    try std.testing.expectEqual(@as(usize, 1), iterated.finalized);
}

// ---------------------------------------------------------------------------
// A finalizer never runs inside V8's collector (lane v8up b6)
// ---------------------------------------------------------------------------
//
// V8 15.7 runs its weak callbacks under DisallowJSObjectModification and
// CHECKs it; the first pass only queues the finalizer on its agent, which
// runs it at its safe point - the pump after the task, or a forced
// collection's return (v8_wrapper.cpp `runQueuedFinalizers`;
// tests/v8/weak_callback_ownership_test.zig has the queue's own tests).

/// A reaction whose `dropped` step does engine work in its realm: it writes
/// a NEW property of the realm's global, which changes the object's map.
const WritingReaction = struct {
    realm: runtime.Context,
    dropped: usize = 0,
    failed: bool = false,

    fn onDropped(data: ?*anyopaque) void {
        const self: *WritingReaction = @ptrCast(@alignCast(data.?));
        self.dropped += 1;
        run(self.realm, "globalThis.droppedReactions = (globalThis.droppedReactions || 0) + 1") catch {
            self.failed = true;
        };
    }

    const steps: protocol.PromiseReactionSteps = .{ .dropped = onDropped };
};

/// A collection V8 delivers BY TASK (a moderate memory-pressure notice:
/// Isolate::MemoryPressureNotification(kModerate) starts an incremental
/// collection its marking job finishes in foreground tasks, and its second
/// pass is a task V8 posts), pumped by `pump` until `done` or the bound.
fn collectByTask(comptime pump: fn (*ffi.Isolate) callconv(.c) bool, context: anytype, comptime done: fn (@TypeOf(context)) bool) !void {
    const isolate = test_isolate.?;
    ffi.v8_Isolate_MemoryPressureNotification(isolate, .moderate);
    var turns: usize = 0;
    while (!done(context) and turns < 2_000_000) : (turns += 1) {
        if (!pump(isolate)) std.Thread.yield() catch {};
    }
    if (!done(context)) return error.NoCollectionByTask;
}

fn writingReactionDropped(reaction: *WritingReaction) bool {
    return reaction.dropped != 0;
}

fn finalizerQueued(_: void) bool {
    return ffi.v8_Debug_QueuedFinalizers(test_isolate.?) != 0;
}

test "a collected reaction's dropped step writes to its realm after a collection delivered by task" {
    defer test_agent.close();
    const w = try windowRealm();
    defer protocol.destroyWindowRealm(w, .global_detached);
    collect();
    while (ffi.v8_Platform_PumpMessageLoop(test_isolate.?)) {}
    var reaction: WritingReaction = .{ .realm = w };
    {
        const promise = try evalOwned(w, "new Promise(() => {})");
        defer promise.release();
        try protocol.reactToPromise(w, promise.value, &WritingReaction.steps, &reaction);
    }
    // The event loop's own pump: the task that finishes V8's collection runs
    // in it, and the finalizer at the safe point after that task.
    try collectByTask(ffi.v8_Platform_PumpMessageLoop, &reaction, writingReactionDropped);
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);
    try std.testing.expect(!reaction.failed);
    try expectEval(w, "String(globalThis.droppedReactions)", "1");
}

test "a realm that ends while a collected reaction's finalizer is queued drops it once, and the safe point runs nothing for it" {
    defer test_agent.close();
    const w = try windowRealm();
    collect();
    while (ffi.v8_Platform_PumpMessageLoop(test_isolate.?)) {}
    var reaction: Reaction = .{};
    {
        const promise = try evalOwned(w, "new Promise(() => {})");
        defer promise.release();
        try protocol.reactToPromise(w, promise.value, &Reaction.all, &reaction);
    }
    // Both passes ran; the finalizer waits on the agent's queue.
    try collectByTask(ffi.v8_Debug_PumpMessageLoopHoldingFinalizers, {}, finalizerQueued);
    try std.testing.expectEqual(@as(usize, 0), reaction.dropped);
    // Its realm ends first: the realm drops the reaction itself, once, and
    // cancels the queued finalizer, whose record points at freed memory.
    protocol.destroyWindowRealm(w, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), reaction.dropped);
    while (ffi.v8_Platform_PumpMessageLoop(test_isolate.?)) {}
    try std.testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(test_isolate.?));
    try std.testing.expectEqual(@as(usize, 1), reaction.total());
}
