//! Unhandled promise rejections: the "unhandledrejection" and
//! "rejectionhandled" events.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#unhandled-promise-rejections
//!       https://html.spec.whatwg.org/multipage/webappapis.html#the-hostpromiserejectiontracker-implementation
//!
//! V8 reports the two HostPromiseRejectionTracker operations through its
//! promise reject callback: kPromiseRejectWithNoHandler is "reject",
//! kPromiseHandlerAddedAfterReject is "handle". HTML runs "notify about
//! rejected promises" at the end of every microtask checkpoint; V8 runs its
//! microtasks-completed callbacks at exactly that point, automatic checkpoints
//! included, so that is where notification is hooked.
//!
//! Nothing installed either callback before, so no page ever saw an
//! unhandledrejection event, and a test waiting on one waited out the harness
//! timeout.
//!
//! Deviation, stated: a global's "outstanding rejected promises weak set" holds
//! STRONG Globals here, released when the global goes away (or, past a cap,
//! oldest first). Weak V8 handles carry teardown obligations (AGENTS.md "Whoever
//! ends a weak arm inherits V8's Reset obligation") that are not worth taking on
//! for a set whose only purpose is to notice a late handler. What it changes: a
//! promise nobody will ever handle stays alive until its page does.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const v8 = @import("v8");
const ffi = v8.ffi;
const report_exception = @import("report_exception.zig");

const log = std.log.scoped(.rejected_promises);
const allocator = std.heap.c_allocator;

/// How many outstanding rejected promises a global keeps before dropping the
/// oldest (see the module doc).
const max_outstanding = 1024;

/// V8's PromiseRejectEvent values (v8-promise.h).
const kPromiseRejectWithNoHandler: c_int = 0;
const kPromiseHandlerAddedAfterReject: c_int = 1;

/// One global's rejection bookkeeping.
const Tracked = struct {
    /// The global, held as (address, slab generation): the slab reuses a freed
    /// Window's slot, and a stale entry must not be mistaken for the new one.
    global: *runtime.Instance,
    generation: u64,
    /// "about-to-be-notified rejected promises list": owned Globals.
    about_to_be_notified: std.ArrayListUnmanaged(*ffi.Value) = .empty,
    /// "outstanding rejected promises weak set": owned Globals.
    outstanding: std.ArrayListUnmanaged(*ffi.Value) = .empty,

    fn isAlive(self: *const Tracked) bool {
        return runtime.SlabAllocator.generationOf(self.global) == self.generation;
    }

    fn destroy(self: *Tracked) void {
        for (self.about_to_be_notified.items) |p| ffi.v8_Global_Dispose(p);
        for (self.outstanding.items) |p| ffi.v8_Global_Dispose(p);
        self.about_to_be_notified.deinit(allocator);
        self.outstanding.deinit(allocator);
        allocator.destroy(self);
    }
};

var tracked: std.ArrayListUnmanaged(*Tracked) = .empty;
var installed_isolate: ?*ffi.Isolate = null;

/// Start tracking promise rejections on `isolate`. Idempotent per isolate.
pub fn install(isolate: *ffi.Isolate) void {
    if (installed_isolate == isolate) return;
    ffi.v8_Isolate_SetPromiseRejectCallback(isolate, null, &onPromiseReject);
    ffi.v8_Isolate_AddMicrotasksCompletedCallback(isolate, &onMicrotasksCompleted, null);
    installed_isolate = isolate;
}

/// Stop tracking and release every handle, before `isolate` is disposed.
pub fn uninstall(isolate: *ffi.Isolate) void {
    if (installed_isolate != isolate) return;
    ffi.v8_Isolate_ClearPromiseRejectCallback(isolate);
    ffi.v8_Isolate_RemoveMicrotasksCompletedCallback(isolate, &onMicrotasksCompleted, null);
    for (tracked.items) |t| t.destroy();
    tracked.deinit(allocator);
    tracked = .empty;
    installed_isolate = null;
}

/// The bookkeeping for `global`, created on first use. Entries whose global
/// has gone are released on the way.
fn trackedFor(global: *runtime.Instance, create: bool) ?*Tracked {
    var i: usize = 0;
    var found: ?*Tracked = null;
    while (i < tracked.items.len) {
        const t = tracked.items[i];
        if (!t.isAlive()) {
            t.destroy();
            _ = tracked.swapRemove(i);
            continue;
        }
        if (t.global == global) found = t;
        i += 1;
    }
    if (found != null or !create) return found;

    const t = allocator.create(Tracked) catch return null;
    t.* = .{ .global = global, .generation = runtime.SlabAllocator.generationOf(global) };
    tracked.append(allocator, t) catch {
        allocator.destroy(t);
        return null;
    };
    return t;
}

/// HostPromiseRejectionTracker steps 3-5: the current settings object's global.
fn currentGlobal() ?*runtime.Instance {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    // GetCurrentContext hands back a Global the caller owns.
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse return null;
    defer ffi.v8_Context_Dispose(context);
    return v8.context_manager.getWindowForContext(context);
}

/// Remove the entry of `list` that is `promise`, returning it (owned).
fn takeMatching(list: *std.ArrayListUnmanaged(*ffi.Value), promise: *ffi.Value) ?*ffi.Value {
    for (list.items, 0..) |candidate, i| {
        if (ffi.v8_Value_StrictEquals(candidate, promise)) return list.orderedRemove(i);
    }
    return null;
}

/// HostPromiseRejectionTracker(promise, operation).
///
/// `promise_ptr` and `value_ptr` are new Globals this callback owns.
fn onPromiseReject(user_data: ?*anyopaque, event_type: c_int, promise_ptr: ?*anyopaque, value_ptr: ?*anyopaque) callconv(.c) void {
    _ = user_data;
    const promise: *ffi.Value = @ptrCast(@alignCast(promise_ptr orelse return));
    var keep_promise = false;
    defer if (!keep_promise) ffi.v8_Global_Dispose(promise);
    defer if (value_ptr) |v| ffi.v8_Global_Dispose(@ptrCast(@alignCast(v)));

    // Steps 1-5. (Step 2's muted-errors exception needs the running script,
    // which V8 does not hand this callback.)
    const global = currentGlobal() orelse return;

    switch (event_type) {
        // Step 6: operation "reject" - append promise to the global's
        // about-to-be-notified rejected promises list.
        kPromiseRejectWithNoHandler => {
            const t = trackedFor(global, true) orelse return;
            t.about_to_be_notified.append(allocator, promise) catch return;
            keep_promise = true;
        },
        // Step 7: operation "handle".
        kPromiseHandlerAddedAfterReject => {
            const t = trackedFor(global, false) orelse return;
            // 7.1: still waiting to be notified - just forget it.
            if (takeMatching(&t.about_to_be_notified, promise)) |pending| {
                ffi.v8_Global_Dispose(pending);
                return;
            }
            // 7.2-7.3: not outstanding - nothing was ever reported.
            const outstanding = takeMatching(&t.outstanding, promise) orelse return;
            // 7.4: queue a global task to fire rejectionhandled.
            queueNotification(global, .rejection_handled, &.{outstanding});
        },
        else => {},
    }
}

/// End of a microtask checkpoint: "notify about rejected promises" for every
/// global with promises waiting.
fn onMicrotasksCompleted(isolate: *ffi.Isolate, data: ?*anyopaque) callconv(.c) void {
    _ = isolate;
    _ = data;
    var i: usize = 0;
    while (i < tracked.items.len) {
        const t = tracked.items[i];
        if (!t.isAlive()) {
            t.destroy();
            _ = tracked.swapRemove(i);
            continue;
        }
        i += 1;
        // Steps 1-3: take the list, leaving it empty.
        if (t.about_to_be_notified.items.len == 0) continue;
        const list = t.about_to_be_notified.toOwnedSlice(allocator) catch continue;
        defer allocator.free(list);
        // Step 4: queue a global task.
        queueNotification(t.global, .unhandled_rejection, list);
    }
}

const Kind = enum { unhandled_rejection, rejection_handled };

const Notification = struct {
    global: *runtime.Instance,
    generation: u64,
    kind: Kind,
    /// Owned Globals.
    promises: []*ffi.Value,
};

/// Queue a global task on the DOM manipulation task source to run
/// `runNotification`. Takes ownership of every Global in `promises` (the
/// slice itself is copied).
fn queueNotification(global: *runtime.Instance, kind: Kind, promises: []const *ffi.Value) void {
    const loop = global.ctx.getOptionalEventLoop() orelse return disposeAll(promises);
    const task = allocator.create(Notification) catch return disposeAll(promises);
    const copy = allocator.dupe(*ffi.Value, promises) catch {
        allocator.destroy(task);
        return disposeAll(promises);
    };
    task.* = .{
        .global = global,
        .generation = runtime.SlabAllocator.generationOf(global),
        .kind = kind,
        .promises = copy,
    };
    loop.queueTask(.{ .callback = &runNotification, .context = task });
}

fn disposeAll(promises: []const *ffi.Value) void {
    for (promises) |p| ffi.v8_Global_Dispose(p);
}

fn runNotification(data: ?*anyopaque) void {
    const task: *Notification = @ptrCast(@alignCast(data orelse return));
    defer {
        allocator.free(task.promises);
        allocator.destroy(task);
    }

    const global = task.global;
    if (runtime.SlabAllocator.generationOf(global) != task.generation) return disposeAll(task.promises);

    // A task runs from the event loop: no HandleScope, no entered context.
    const scope = v8.JsScope.init(global.ctx) orelse return disposeAll(task.promises);
    defer scope.deinit();

    for (task.promises) |promise| {
        switch (task.kind) {
            .unhandled_rejection => notifyOne(global, promise),
            .rejection_handled => {
                defer ffi.v8_Global_Dispose(promise);
                _ = firePromiseRejectionEvent(global, "rejectionhandled", promise, false);
            },
        }
    }
}

/// "Notify about rejected promises" step 4.1, for one promise it owns.
fn notifyOne(global: *runtime.Instance, promise: *ffi.Value) void {
    // 4.1.1: If p.[[PromiseIsHandled]] is true, continue.
    if (ffi.v8_Promise_HasHandler(promise)) return ffi.v8_Global_Dispose(promise);

    // 4.1.2: fire unhandledrejection, cancelable, with p and its result.
    const not_canceled = firePromiseRejectionEvent(global, "unhandledrejection", promise, true);

    // 4.1.3: the user agent may report it to a developer console.
    if (not_canceled) log.debug("unhandled promise rejection", .{});

    // 4.1.4: still not handled - it is now outstanding.
    if (ffi.v8_Promise_HasHandler(promise)) return ffi.v8_Global_Dispose(promise);
    const t = trackedFor(global, true) orelse return ffi.v8_Global_Dispose(promise);
    if (t.outstanding.items.len >= max_outstanding) ffi.v8_Global_Dispose(t.outstanding.orderedRemove(0));
    t.outstanding.append(allocator, promise) catch ffi.v8_Global_Dispose(promise);
}

/// Fire a PromiseRejectionEvent named `event_type` at `global`, with
/// `promise` and its [[PromiseResult]] as the reason. Returns notCanceled.
fn firePromiseRejectionEvent(global: *runtime.Instance, event_type: []const u8, promise: *ffi.Value, cancelable: bool) bool {
    const reason = ffi.v8_Promise_Result(@ptrCast(promise));
    defer if (reason) |r| ffi.v8_Global_Dispose(r);

    const init = dictionaries.PromiseRejectionEventInit{
        .base = .{ .bubbles = false, .cancelable = cancelable, .composed = false },
        // The event takes Globals of its own.
        .promise = runtime.JSValue.fromHandleNonOwning(promise),
        .reason = if (reason) |r| runtime.JSValue.fromHandleNonOwning(r) else null,
    };
    const event = interfaces.PromiseRejectionEvent.call_constructor(
        global.ctx,
        runtime.DOMString.initInterned(event_type),
        init,
    ) catch |err| {
        log.debug("could not create PromiseRejectionEvent: {}", .{err});
        return true;
    };
    const not_canceled = interfaces.EventTarget.call_dispatchEvent(global, event) catch true;
    report_exception.releaseIfUnwrapped(event);
    return not_canceled;
}
