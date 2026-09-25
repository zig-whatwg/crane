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

/// A live isolate with an entered context, which `v8_Object_New` needs.
///
/// One test binary per file (`addTestFilesFromDir`), so this process owns the V8
/// platform outright and no other test can be disturbed by initialising it. One
/// isolate for the whole file, because V8 is never torn down here: this codebase
/// has a known teardown race, and a flaky test in the correctness suite is worse
/// than a process-lifetime reservation that `exit` releases. Every assertion
/// below is a delta against a baseline read inside the test, so sharing the
/// isolate costs nothing.
const Env = struct {
    isolate: *ffi.Isolate,
    context: *ffi.Context,
};

var env_once: ?Env = null;

fn env() !Env {
    if (env_once) |e| return e;
    const isolate = ffi.v8_Isolate_New() orelse return error.IsolateCreationFailed;
    ffi.v8_Isolate_Enter(isolate);
    _ = ffi.v8_HandleScope_New(isolate);
    const context = ffi.v8_Context_New(isolate) orelse return error.ContextCreationFailed;
    ffi.v8_Context_Enter(context);
    env_once = .{ .isolate = isolate, .context = context };
    return env_once.?;
}

test "disarming a handle frees the record V8 hands back" {
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
