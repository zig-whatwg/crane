//! Who owns the `WeakCallbackData` that `v8_Global_SetWeak` allocates?
//!
//! Arming a handle weak heap-allocates a small record in `v8_wrapper.cpp`
//! holding the Zig finalizer, its user data, and a raw pointer back to the
//! `Global<T>` the arm was placed on. Nothing in the FFI signature says who
//! frees that record, and the answer has to be "whoever ends the arm" - because
//! the record outliving the `Global` it points at is a use-after-free, not a
//! leak.
//!
//! It was neither, in both directions:
//!
//!   * `PersistentBase::ClearWeak()` is `ClearWeak<void>()`, which DISCARDS the
//!     parameter V8 hands back. Every disarm leaked one record - and
//!     `wrapper_cache.zig` disarms in five places, on every DOM wrapper.
//!   * Disposing an armed `Global` deleted it while the record still pointed at
//!     it. V8 copies the callback parameter into a pending list at GC time and
//!     runs every first-pass callback afterwards, so one callback's Zig side can
//!     dispose a second armed handle whose callback is still queued in the SAME
//!     pass. That second callback then reset a `Global<Value>` whose memory had
//!     already been recycled:
//!
//!         Segmentation fault at address 0x4dbacbca5b9a861c
//!           GlobalHandles::NodeSpace<Node>::Release
//!           PersistentBase<Value>::Reset
//!           WeakCallbackWrapper            v8_wrapper.cpp:220
//!           GlobalHandles::InvokeFirstPassWeakCallbacks
//!
//!     `0x4dba` is U+4DBA, a codepoint the encoding test was printing at the
//!     time - the freed handle's bytes, reused for test data.
//!
//! These tests pin the rule that fixes both: **the record is owned by the arm,
//! and the arm ends when the handle is disarmed or disposed, whichever comes
//! first.** `v8_Debug_LiveWeakCallbackData()` counts the records that are still
//! alive, so "returns to baseline" is the assertion.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const v8 = @import("v8");
const ffi = v8.ffi;

/// A finalizer that does nothing. These tests never let a GC reach the objects
/// they arm, so it is only here to make the arm well-formed - `v8_Global_SetWeak`
/// ignores a null callback.
fn noopFinalizer(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = data;
    _ = length_in_bytes;
}

/// A live isolate with an entered context, which `v8_Object_New` needs: the
/// test's own agent's (test_agent), made by the engine's createAgent and ended
/// with the test through destroyAgent, as a Browser ends its page agent.
/// Every assertion below is a delta against a baseline read inside the test.
const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var test_env: ?Env = null;

/// The test's own agent, ended with the test (test_process.TestAgent);
/// `reset` clears what the file caches of it.
var test_agent: test_process.TestAgent = .{ .reset = reset };

fn reset() void {
    test_env = null;
}

fn env() !Env {
    const isolate = try test_agent.open(.{});
    if (test_env == null) test_env = .{ .isolate = isolate, .context = test_agent.context.? };
    return test_env.?;
}

test "disarming a handle frees the record V8 hands back" {
    defer test_agent.close();
    const e = try env();

    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    var user_data: u32 = 0xC0FFEE;

    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    try testing.expectEqual(baseline + 1, ffi.v8_Debug_LiveWeakCallbackData());

    // `ClearWeak()` is `ClearWeak<void>()`. V8 returns the parameter; the
    // non-template overload throws it away, and the caller is the only one who
    // could ever free it.
    ffi.v8_Global_ClearWeak(@ptrCast(obj));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());

    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "disposing an armed handle ends the arm - the record cannot outlive the Global" {
    defer test_agent.close();
    const e = try env();

    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    var user_data: u32 = 0xC0FFEE;

    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    try testing.expectEqual(baseline + 1, ffi.v8_Debug_LiveWeakCallbackData());

    // No disarm first. This is what `disposeEntryWrapper` does on every path
    // that does not go through the weak callback, and what the returned handle
    // of `zig_callbacks.createCallback` invites its caller to do.
    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "re-arming the same handle replaces the record rather than stacking one" {
    defer test_agent.close();
    const e = try env();

    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    var user_data: u32 = 0xC0FFEE;

    // V8 keeps only the newest parameter, so a second arm strands the first
    // record: it can never fire, and nothing else knows it exists.
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    ffi.v8_Global_SetWeak(@ptrCast(obj), @ptrCast(&user_data), noopFinalizer);
    try testing.expectEqual(baseline + 1, ffi.v8_Debug_LiveWeakCallbackData());

    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "a handle that was never armed is unaffected by disarm and dispose" {
    defer test_agent.close();
    const e = try env();

    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;

    // Both are reached with unarmed handles all over the tree - `wrapper_cache`
    // disarms entries it never armed, and every `v8_Object_Dispose` in the
    // codebase lands here. Neither may touch the count or the handle.
    ffi.v8_Global_ClearWeak(@ptrCast(obj));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());

    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "v8_Value_ToWeakGlobal arms the handle it returns, not a null one" {
    defer test_agent.close();
    const e = try env();

    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    // A null callback asks for a plain Global, so nothing is armed and nothing
    // is owed. This is the shape `conversions.zig` uses.
    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    const local = ffi.v8_Global_Get(e.isolate, @ptrCast(obj)) orelse return error.LocalFailed;

    const unarmed = ffi.v8_Value_ToWeakGlobal(e.isolate, local, null, null) orelse
        return error.WeakGlobalFailed;
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
    ffi.v8_Value_Dispose(unarmed);

    // With a callback it must record the handle it just created, or the callback
    // cannot meet V8's "the first callback MUST Reset the Global which triggered
    // it" contract and the Global leaks on every collection.
    var user_data: u32 = 0xC0FFEE;
    const local2 = ffi.v8_Global_Get(e.isolate, @ptrCast(obj)) orelse return error.LocalFailed;
    const armed = ffi.v8_Value_ToWeakGlobal(e.isolate, local2, @ptrCast(&user_data), noopFinalizer) orelse
        return error.WeakGlobalFailed;
    try testing.expectEqual(baseline + 1, ffi.v8_Debug_LiveWeakCallbackData());

    ffi.v8_Value_Dispose(armed);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());

    ffi.v8_Object_Dispose(obj);
}

/// Shared by `pairFinalizer`: two objects collected in one GC, and an isolate
/// that has nothing to do with them.
const DetachPair = struct {
    a: ?*ffi.Object = null,
    b: ?*ffi.Object = null,
    other_isolate: ?*ffi.Isolate = null,
    finalizers_run: u32 = 0,
};
var detach_pair: DetachPair = .{};
const tag_a: u8 = 'a';
const tag_b: u8 = 'b';

/// The first finalizer of the pass disposes both handles - its own, already
/// reset, and the other one, whose callback V8 has queued in this same pass,
/// which leaves that record detached - and then disposes an unrelated isolate,
/// as a worker's teardown can from inside a page's GC.
fn pairFinalizer(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = length_in_bytes;
    detach_pair.finalizers_run += 1;
    if (detach_pair.finalizers_run > 1) return;
    const which: *const u8 = @ptrCast(data.?);
    const own = if (which.* == 'a') detach_pair.a else detach_pair.b;
    const other = if (which.* == 'a') detach_pair.b else detach_pair.a;
    if (other) |h| ffi.v8_Object_Dispose(h);
    if (own) |h| ffi.v8_Object_Dispose(h);
    detach_pair.a = null;
    detach_pair.b = null;
    if (detach_pair.other_isolate) |iso| {
        ffi.v8_Isolate_Dispose(iso);
        detach_pair.other_isolate = null;
    }
}

test "disposing an isolate leaves another isolate's detached records alone" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();

    // Created before the GC and never entered: it only has to be disposed.
    detach_pair = .{ .other_isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed };

    detach_pair.a = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    detach_pair.b = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    ffi.v8_Global_SetWeak(@ptrCast(detach_pair.a.?), @ptrCast(@constCast(&tag_a)), pairFinalizer);
    ffi.v8_Global_SetWeak(@ptrCast(detach_pair.b.?), @ptrCast(@constCast(&tag_b)), pairFinalizer);
    try testing.expectEqual(baseline + 2, ffi.v8_Debug_LiveWeakCallbackData());

    // Both objects are reachable only through their weak handles.
    ffi.v8_Isolate_RequestGarbageCollection(e.isolate);

    // One finalizer ran; the other's record was detached and freed by its own
    // queued callback, not by the other isolate's dispose.
    try testing.expectEqual(@as(u32, 1), detach_pair.finalizers_run);
    try testing.expect(detach_pair.other_isolate == null);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// ---------------------------------------------------------------------------
// Finalizers: V8's second pass (v8_Global_SetWeakFinalizer)
// ---------------------------------------------------------------------------

const PassProbe = struct {
    unlinks: u32 = 0,
    unlink_in_first_pass: bool = false,
    finalizes: u32 = 0,
    finalize_in_first_pass: bool = true,
    /// The handle the unlink disposes, for the cancellation case.
    dispose_in_unlink: ?*ffi.Object = null,
};
var pass_probe: PassProbe = .{};

fn probeUnlink(_: ?*anyopaque, _: usize) callconv(.c) void {
    pass_probe.unlinks += 1;
    pass_probe.unlink_in_first_pass = ffi.v8_Debug_InFirstPassWeakCallback();
    if (pass_probe.dispose_in_unlink) |h| {
        ffi.v8_Object_Dispose(h);
        pass_probe.dispose_in_unlink = null;
    }
}

fn probeFinalize(_: ?*anyopaque, _: usize) callconv(.c) void {
    pass_probe.finalizes += 1;
    pass_probe.finalize_in_first_pass = ffi.v8_Debug_InFirstPassWeakCallback();
}

test "a finalizer runs in V8's second pass, after its first-pass unlink, and its record goes with it" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    pass_probe = .{};

    const scope = ffi.v8_HandleScope_New(e.isolate);
    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    var user_data: u32 = 0xC0FFEE;
    ffi.v8_Global_SetWeakFinalizer(@ptrCast(obj), @ptrCast(&user_data), probeUnlink, probeFinalize);
    try testing.expectEqual(baseline + 1, ffi.v8_Debug_LiveWeakCallbackData());

    // A forced collection runs its second pass before it returns.
    ffi.v8_Isolate_RequestGarbageCollection(e.isolate);
    try testing.expectEqual(@as(u32, 1), pass_probe.unlinks);
    try testing.expect(pass_probe.unlink_in_first_pass);
    try testing.expectEqual(@as(u32, 1), pass_probe.finalizes);
    try testing.expect(!pass_probe.finalize_in_first_pass);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
    // The handle, Reset by the first pass, is still its owner's to dispose.
    ffi.v8_Object_Dispose(obj);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "disposing a handle before its second pass cancels the finalizer and frees its record" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    pass_probe = .{};

    const scope = ffi.v8_HandleScope_New(e.isolate);
    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    var user_data: u32 = 0xC0FFEE;
    // Its owner ends it between the passes - here, from the unlink itself.
    pass_probe.dispose_in_unlink = obj;
    ffi.v8_Global_SetWeakFinalizer(@ptrCast(obj), @ptrCast(&user_data), probeUnlink, probeFinalize);

    ffi.v8_Isolate_RequestGarbageCollection(e.isolate);
    try testing.expectEqual(@as(u32, 1), pass_probe.unlinks);
    try testing.expectEqual(@as(u32, 0), pass_probe.finalizes);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// ---------------------------------------------------------------------------
// Finalizers leave V8's second pass: the agent's queue and its safe point
// ---------------------------------------------------------------------------
//
// V8 15.7 runs a collection's second pass under DisallowJavascriptExecution
// and DisallowJSObjectModification - at the end of a forced collection and in
// the task it posts for every other one (src/heap/heap.cc:1470-1477,
// src/handles/global-handles.cc:890-900) - and a write to a JS object there
// is fatal: "Check failed: AllowJSObjectModification::IsAllowed(isolate)". A
// finalizer is an instance's teardown and may write (a dropped Response
// cancels its open body transfer, which reports a resource-timing entry to
// its page), so the second pass only queues it on its agent, and it runs at
// the agent's safe point: the pump, after the task; a forced collection,
// before it returns (v8_wrapper.cpp `runQueuedFinalizers`).

const QueueProbe = struct {
    const max = 4;
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    /// What a finalizer writes to: a live object of the agent's.
    target: *ffi.Object,
    unlink_order: [max]u8 = @splat(0xff),
    unlinks: usize = 0,
    finalize_order: [max]u8 = @splat(0xff),
    finalizes: usize = 0,
    /// Whether each finalizer writes a new property of `target`.
    writes: bool = true,
    write_failed: bool = false,
};
var queue_probe: ?QueueProbe = null;

/// One armed object: its index and its handle, which its finalizer disposes
/// as an owner does.
const Armed = struct {
    index: u8,
    handle: ?*ffi.Object = null,
};

fn queueUnlink(data: ?*anyopaque, _: usize) callconv(.c) void {
    const armed: *Armed = @ptrCast(@alignCast(data.?));
    const probe = &queue_probe.?;
    probe.unlink_order[probe.unlinks] = armed.index;
    probe.unlinks += 1;
}

/// The finalizer: engine work - a NEW property on a live JS object, which
/// changes its map - then its handle goes.
fn queueFinalize(data: ?*anyopaque, _: usize) callconv(.c) void {
    const armed: *Armed = @ptrCast(@alignCast(data.?));
    const probe = &queue_probe.?;
    probe.finalize_order[probe.finalizes] = armed.index;
    probe.finalizes += 1;
    if (probe.writes) {
        var name: [8]u8 = undefined;
        const text = std.fmt.bufPrint(&name, "f{d}", .{armed.index}) catch unreachable;
        const key = ffi.v8_String_NewFromUtf8(probe.isolate, text.ptr, @intCast(text.len)).?;
        defer ffi.v8_String_Dispose(key);
        const value = ffi.v8_Integer_New(probe.isolate, armed.index);
        defer ffi.v8_Value_Dispose(@ptrCast(value));
        if (!ffi.v8_Object_Set(probe.target, probe.context, @ptrCast(key), @ptrCast(value))) probe.write_failed = true;
    }
    if (armed.handle) |handle| ffi.v8_Object_Dispose(handle);
    armed.handle = null;
}

fn armForQueue(e: Env, armed: *Armed) !void {
    const scope = ffi.v8_HandleScope_New(e.isolate);
    const obj = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    armed.handle = obj;
    ffi.v8_Global_SetWeakFinalizer(@ptrCast(obj), @ptrCast(armed), queueUnlink, queueFinalize);
}

fn openQueueProbe(e: Env, writes: bool) !void {
    // Nothing of an earlier collection is under way or queued.
    ffi.v8_Isolate_RequestGarbageCollection(e.isolate);
    while (ffi.v8_Platform_PumpMessageLoop(e.isolate)) {}
    const scope = ffi.v8_HandleScope_New(e.isolate);
    const target = ffi.v8_Object_New(e.isolate) orelse return error.ObjectCreationFailed;
    if (scope) |s| ffi.v8_HandleScope_Dispose(s);
    queue_probe = .{ .isolate = e.isolate, .context = e.context, .target = target, .writes = writes };
}

fn closeQueueProbe() void {
    if (queue_probe) |probe| ffi.v8_Object_Dispose(probe.target);
    queue_probe = null;
}

/// A collection V8 delivers BY TASK, as it delivers every collection the
/// embedder did not force. The trigger is a moderate memory-pressure notice
/// (Isolate::MemoryPressureNotification(kModerate)): V8 starts an incremental
/// collection that its marking job finishes in foreground tasks (15.7
/// Heap::CheckMemoryPressure), and the second pass of such a collection is a
/// task V8 posts (GlobalHandles::PostGarbageCollectionProcessing) - nothing
/// is collected before the notice returns. Pumps WITHOUT the agent's safe
/// point until `count` finalizers are queued.
fn collectByTaskHoldingFinalizers(isolate: *ffi.Isolate, count: usize) !void {
    ffi.v8_Isolate_MemoryPressureNotification(isolate, .moderate);
    var turns: usize = 0;
    while (ffi.v8_Debug_QueuedFinalizers(isolate) < count and turns < 2_000_000) : (turns += 1) {
        if (queue_probe.?.finalizes != 0) {
            std.debug.print("a finalizer ran inside V8's second pass: {d} run, {d} queued\n", .{ queue_probe.?.finalizes, ffi.v8_Debug_QueuedFinalizers(isolate) });
            return error.FinalizerRanInsideTheSecondPass;
        }
        if (!ffi.v8_Debug_PumpMessageLoopHoldingFinalizers(isolate)) std.Thread.yield() catch {};
    }
    if (ffi.v8_Debug_QueuedFinalizers(isolate) < count) {
        std.debug.print("{d} of {d} finalizers queued {d} loop turns after a moderate memory-pressure notice ({d} unlinked)\n", .{ ffi.v8_Debug_QueuedFinalizers(isolate), count, turns, queue_probe.?.unlinks });
        return error.NoCollectionByTask;
    }
}

test "a finalizer that writes a JS object runs when a forced collection returns, outside its second pass" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, true);
    defer closeQueueProbe();

    var armed: Armed = .{ .index = 0 };
    try armForQueue(e, &armed);
    // Forced: V8 runs the second pass before it returns, under
    // DisallowJSObjectModification. The finalizer's write must come after.
    ffi.v8_Isolate_RequestGarbageCollection(e.isolate);
    try testing.expectEqual(@as(usize, 1), queue_probe.?.finalizes);
    try testing.expect(!queue_probe.?.write_failed);
    try testing.expect(ffi.v8_Object_Has(e.context, queue_probe.?.target, "f0"));
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "finalizers of a collection delivered by task wait for the agent's safe point and run there in the order V8's second pass handed them over" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, true);
    defer closeQueueProbe();

    var armed: [3]Armed = .{ .{ .index = 0 }, .{ .index = 1 }, .{ .index = 2 } };
    for (&armed) |*a| try armForQueue(e, a);

    try collectByTaskHoldingFinalizers(e.isolate, 3);
    // Both passes have run and nothing of Zig's has: the three wait.
    try testing.expectEqual(@as(usize, 3), queue_probe.?.unlinks);
    try testing.expectEqual(@as(usize, 0), queue_probe.?.finalizes);
    try testing.expect(!ffi.v8_Object_Has(e.context, queue_probe.?.target, "f0"));

    // The safe point: the pump, V8's task off the stack. It answers that
    // work ran, so the event loop performs its microtask checkpoint.
    try testing.expect(ffi.v8_Platform_PumpMessageLoop(e.isolate));
    try testing.expectEqual(@as(usize, 3), queue_probe.?.finalizes);
    // The queue keeps the second pass's order, so the finalizers run in the
    // order they ran in when that pass ran them itself. V8 lists a record
    // for its second pass as its first pass visits it (15.7 src/handles/
    // global-handles.cc:850, push_back) and the second pass takes them from
    // the back (:765-767): the reverse of the first pass's order.
    var handed_over: [3]u8 = undefined;
    for (&handed_over, 0..) |*index, i| index.* = queue_probe.?.unlink_order[2 - i];
    try testing.expectEqualSlices(u8, &handed_over, queue_probe.?.finalize_order[0..3]);
    try testing.expect(!queue_probe.?.write_failed);
    inline for (.{ "f0", "f1", "f2" }) |name| try testing.expect(ffi.v8_Object_Has(e.context, queue_probe.?.target, name));
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "a handle disposed while its finalizer is queued cancels it, and the safe point frees the record uncalled" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, false);
    defer closeQueueProbe();

    var armed: [2]Armed = .{ .{ .index = 0 }, .{ .index = 1 } };
    for (&armed) |*a| try armForQueue(e, a);
    try collectByTaskHoldingFinalizers(e.isolate, 2);

    // Their owner ends them first - a realm's end does, for every entry
    // still pending (WrapperCache.deinit) - and frees what they point at.
    for (&armed) |*a| {
        ffi.v8_Object_Dispose(a.handle.?);
        a.handle = null;
    }
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    while (ffi.v8_Platform_PumpMessageLoop(e.isolate)) {}
    try testing.expectEqual(@as(usize, 0), queue_probe.?.finalizes);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

test "an agent that ends with finalizers queued runs each once while it is alive, and leaks neither their records nor what they free" {
    const e = try env();
    var closed = false;
    defer if (!closed) test_agent.close();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, false);

    // What each finalizer frees is the test allocator's: one that never ran
    // leaks, and one that ran twice frees twice.
    const armed = try testing.allocator.alloc(Armed, 2);
    var freed = false;
    defer if (!freed) testing.allocator.free(armed);
    for (armed, 0..) |*a, i| {
        a.* = .{ .index = @intCast(i) };
        try armForQueue(e, a);
    }
    try collectByTaskHoldingFinalizers(e.isolate, 2);
    try testing.expectEqual(@as(usize, 0), queue_probe.?.finalizes);

    // The agent ends: its last forced collections are a safe point, with
    // the isolate entered and alive (protocol_agents.endAgent). Nothing is
    // left for v8_Isolate_Dispose, which calls no finalizer. The probe's
    // target goes before its agent; its counts stay readable.
    ffi.v8_Object_Dispose(queue_probe.?.target);
    test_agent.close();
    closed = true;
    const finalizes = queue_probe.?.finalizes;
    queue_probe = null;
    try testing.expectEqual(@as(usize, 2), finalizes);
    for (armed) |a| try testing.expect(a.handle == null);
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
    testing.allocator.free(armed);
    freed = true;
}

// A collection the adapter did not force. V8 collects by itself, in the middle
// of whatever allocated, when an allocation fails: Heap::CollectAllAvailableGarbage
// (15.7.112.43 src/heap/heap-allocator.cc:201-218 and :528, the last resort
// before the fatal out-of-memory at :537), and that collection runs its
// second pass BEFORE it returns (src/handles/global-handles.cc:881-889:
// kGCCallbackFlagCollectAllAvailableGarbage). The adapter is not on the stack
// to run the queue, so the finalizers wait where every by-task collection's
// do - on their agent - for its next safe point. The queue is bounded by what
// has died: a record joins it once, when its wrapper dies, and a later
// collection finds nothing of it to hand over again.
test "finalizers of a synchronous second pass the adapter did not force wait for the agent's next safe point, each queued once" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, true);
    defer closeQueueProbe();

    var armed: [4]Armed = .{ .{ .index = 0 }, .{ .index = 1 }, .{ .index = 2 }, .{ .index = 3 } };
    for (armed[0..3]) |*a| try armForQueue(e, a);

    // V8's own collection of last resort: both passes run inside it, under
    // DisallowJavascriptExecution and DisallowJSObjectModification.
    ffi.v8_Debug_CollectHoldingFinalizers(e.isolate);
    try testing.expectEqual(@as(usize, 3), queue_probe.?.unlinks);
    // Nothing of Zig's ran inside the collection - a finalizer's write there
    // is V8's fatal "Check failed: AllowJSObjectModification::IsAllowed".
    try testing.expectEqual(@as(usize, 0), queue_probe.?.finalizes);
    try testing.expectEqual(@as(usize, 3), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expect(!ffi.v8_Object_Has(e.context, queue_probe.?.target, "f0"));

    // A second one, with no pump between them (one long task): the three are
    // not handed over again, and the one that died since joins behind them.
    try armForQueue(e, &armed[3]);
    ffi.v8_Debug_CollectHoldingFinalizers(e.isolate);
    try testing.expectEqual(@as(usize, 4), queue_probe.?.unlinks);
    try testing.expectEqual(@as(usize, 0), queue_probe.?.finalizes);
    try testing.expectEqual(@as(usize, 4), ffi.v8_Debug_QueuedFinalizers(e.isolate));

    // The next safe point - the pump after the task that was running - runs
    // each once: the first collection's in the order its second pass handed
    // them over (the reverse of its first pass's), then the second's.
    try testing.expect(ffi.v8_Platform_PumpMessageLoop(e.isolate));
    try testing.expectEqual(@as(usize, 4), queue_probe.?.finalizes);
    var handed_over: [4]u8 = undefined;
    for (handed_over[0..3], 0..) |*index, i| index.* = queue_probe.?.unlink_order[2 - i];
    handed_over[3] = queue_probe.?.unlink_order[3];
    try testing.expectEqualSlices(u8, &handed_over, queue_probe.?.finalize_order[0..4]);
    try testing.expect(!queue_probe.?.write_failed);
    inline for (.{ "f0", "f1", "f2", "f3" }) |name| try testing.expect(ffi.v8_Object_Has(e.context, queue_probe.?.target, name));
    for (armed) |a| try testing.expect(a.handle == null);
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// One long task. A collection V8 runs by itself posts its second pass as a
// task (15.7.112.43 src/handles/global-handles.cc:892-901), and when the next
// collection begins before that task has run, V8 runs the pending pass first,
// right there (src/heap/heap.cc:1509-1511, Heap::CollectGarbage: "Ensure that
// all pending phantom callbacks are invoked"), under the same two scopes
// (heap.cc:1470-1477; global-handles.cc:746-747). A script
// that makes and drops objects in one loop never reaches the pump, so that is
// where its dead wrappers' finalizers ran: one collection late, in the middle
// of an allocation. They may not run there (the pass is under V8's scopes), and
// the pump is a task away - 300,000 dropped Events in one loop peaked at 392 MB
// instead of 168 MB while every finalizer waited for it.
//
// The agent has a safe point inside the task: the host's external-memory
// report (external_memory.zig - the binding exit back into script at
// DOM-algorithm depth zero and the microtask checkpoint, Blink's
// V8GCController::reportDOMMemoryUsageToV8 point; made once the host's figure
// moved 128 KB), which is where a collection the report starts meets no DOM
// frame. What V8's second passes queued since the last safe point runs when a
// report returns.
test "finalizers a collection of V8's own queued inside one task run at the agent's next external-memory report, without a pump" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, true);
    defer closeQueueProbe();
    const accounter = ffi.v8_ExternalMemoryAccounter_New() orelse return error.OutOfMemory;
    var reported: u64 = 0;
    // V8's count goes back to what it was before the test reported anything.
    defer ffi.v8_ExternalMemoryAccounter_Delete(accounter, e.isolate, reported);

    var armed: [2]Armed = .{ .{ .index = 0 }, .{ .index = 1 } };
    for (&armed) |*a| try armForQueue(e, a);

    // Native memory the host says its objects hold, 256 MB a report, and
    // never a pump or a forced collection: a report that overshoots V8's
    // limits by a large margin collects before it returns (heap.cc:7021-7038
    // Heap::UpdateExternalMemory; its first pass unlinks the two), that
    // collection's second pass is a posted task (CollectGarbageWithRetry
    // passes no callback flags, heap.cc:2132), and the next collection -
    // inside a later report - runs it at its start.
    const step: i64 = 256 << 20;
    var reports: usize = 0;
    var collected_at: usize = 0;
    while (queue_probe.?.finalizes < armed.len and reports < 64) {
        ffi.v8_ExternalMemoryAccounter_Update(accounter, e.isolate, step);
        reported += @intCast(step);
        reports += 1;
        if (collected_at == 0 and queue_probe.?.unlinks == armed.len) collected_at = reports;
    }
    if (queue_probe.?.finalizes != armed.len) {
        std.debug.print("after {d} reports of 256 MB: {d} of {d} unlinked (inside report {d}), {d} finalizers run, {d} queued\n", .{ reports, queue_probe.?.unlinks, armed.len, collected_at, queue_probe.?.finalizes, ffi.v8_Debug_QueuedFinalizers(e.isolate) });
    }
    // Both ran when a report returned, their engine work done outside the
    // collection, and nothing waits for the pump.
    try testing.expectEqual(armed.len, queue_probe.?.finalizes);
    try testing.expect(!queue_probe.?.write_failed);
    inline for (.{ "f0", "f1" }) |name| try testing.expect(ffi.v8_Object_Has(e.context, queue_probe.?.target, name));
    for (armed) |a| try testing.expect(a.handle == null);
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}

// The same report, counted: the collection it runs finds the two dead, and
// they are finalized when THAT report returns. V8's first pass hands the
// adapter each dead wrapper inside the collection, the adapter queues its
// finalizer there, and the report's safe point - V8's collector off the
// stack - runs the queue. Queued by V8's second pass instead (a posted task:
// Heap::UpdateExternalMemory's CollectGarbageWithRetry passes no callback
// flags, src/heap/heap.cc:7021-7038, 2132), they waited for the next
// collection, which runs a pending pass at its start (heap.cc:1509-1511): a
// later report's, 256 MB of the host's memory further on.
test "a report whose own collection found wrappers dead runs their finalizers when it returns, not at the next collection" {
    defer test_agent.close();
    const e = try env();
    const baseline = ffi.v8_Debug_LiveWeakCallbackData();
    try openQueueProbe(e, true);
    defer closeQueueProbe();
    const accounter = ffi.v8_ExternalMemoryAccounter_New() orelse return error.OutOfMemory;
    var reported: u64 = 0;
    defer ffi.v8_ExternalMemoryAccounter_Delete(accounter, e.isolate, reported);

    var armed: [2]Armed = .{ .{ .index = 0 }, .{ .index = 1 } };
    for (&armed) |*a| try armForQueue(e, a);

    // Reports of 256 MB until one of them collects (its first pass unlinks
    // the two), and not one report more.
    const step: i64 = 256 << 20;
    var reports: usize = 0;
    while (queue_probe.?.unlinks < armed.len and reports < 64) {
        ffi.v8_ExternalMemoryAccounter_Update(accounter, e.isolate, step);
        reported += @intCast(step);
        reports += 1;
    }
    if (queue_probe.?.unlinks != armed.len or queue_probe.?.finalizes != armed.len) {
        std.debug.print("after {d} reports of 256 MB, the last of which collected: {d} of {d} unlinked, {d} finalizers run, {d} queued\n", .{ reports, queue_probe.?.unlinks, armed.len, queue_probe.?.finalizes, ffi.v8_Debug_QueuedFinalizers(e.isolate) });
    }
    try testing.expectEqual(armed.len, queue_probe.?.unlinks);
    try testing.expectEqual(armed.len, queue_probe.?.finalizes);
    try testing.expect(!queue_probe.?.write_failed);
    inline for (.{ "f0", "f1" }) |name| try testing.expect(ffi.v8_Object_Has(e.context, queue_probe.?.target, name));
    for (armed) |a| try testing.expect(a.handle == null);
    try testing.expectEqual(@as(usize, 0), ffi.v8_Debug_QueuedFinalizers(e.isolate));
    try testing.expectEqual(baseline, ffi.v8_Debug_LiveWeakCallbackData());
}
