//! Context - V8 Context per Navigation
//!
//! This module manages a V8 context (JavaScript execution environment) for a single
//! page navigation. A new context is created for each navigation while the isolate
//! is reused.
//!
//! ## Responsibilities
//!
//! - Create V8 context within existing isolate
//! - Register browser globals (window, document, navigator, etc.)
//! - Register WebIDL bindings
//! - Execute scripts and handle events
//!
//! ## Performance
//!
//! Context creation is cheap (~1-5ms) compared to isolate creation (~50-100ms).
//! This enables efficient WPT test execution.
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Window object https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object

const std = @import("std");
const log = std.log.scoped(.browser_context);
const v8 = @import("v8");
const clock = @import("clock");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const namespaces = @import("namespaces");
const fetch = @import("fetch");

const storage_mod = @import("storage/Storage.zig");
const Storage = storage_mod.Storage;
const navigation = @import("navigation.zig");
const context_manager = v8.context_manager;
const impls = @import("impls");

// Threadlocal state cleanup modules
const dom_mod = @import("dom");
const html_mod = @import("html");
const custom_elements = html_mod.custom_elements;
const mutation_observer_algorithms = dom_mod.mutation_observer_algorithms;
const instance_lifecycle = runtime.instance_lifecycle;

// Timer support
const TimerInterface = runtime.TimerInterface;
const TimerId = runtime.TimerId;
const TimerCallback = runtime.TimerCallback;
const typed_callback = runtime.typed_callback;
const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;

// ============================================================================
// Thread-local storage for timer interface (mirrors browser_context.zig pattern)
// ============================================================================

threadlocal var current_timer_interface: ?TimerInterface = null;
threadlocal var current_allocator: ?std.mem.Allocator = null;
threadlocal var timer_contexts: ?std.AutoHashMap(TimerId, *V8TimerCallback) = null;

// ============================================================================
// Animation frames
// ============================================================================
//
// https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html#animation-frames
//
// Crane paints nothing, but requestAnimationFrame is an EVENT LOOP feature, not
// a paint feature: its callbacks run in the "update the rendering" step, which a
// headless engine still performs. WPT uses rAF as the standard "wait one frame"
// idiom, so a stubbed rAF does not fail tests - it HANGS them for the full
// timeout. The WebIDL binding (impls/Window.zig call_requestAnimationFrame)
// discarded its callback and returned 0, which reached ~90 worklist sources.
//
// A frame is a BATCH, which is why this cannot be one timer per callback:
// every callback registered before the frame runs in registration order, all
// with the SAME timestamp, and a callback registered from inside the batch is
// deferred to a later frame.

/// ~60Hz. The spec leaves the rate to the implementation.
const FRAME_INTERVAL_MS: u64 = 16;

const AnimationFrameEntry = struct {
    handle: u32,
    /// OWNED. `info.get` is `v8_FunctionCallbackInfo_GetArgument`, whose C++ body
    /// ends `return trackHandle(new Global<Value>(isolate, arg))` - so it hands
    /// back a heap-allocated Global and the caller owns it. That is what lets it
    /// outlive the registering scope, and it means this entry must dispose it:
    /// once the callback has run, once it has been cancelled, or at teardown.
    callback_fn: *v8.ffi.Function,
    /// OWNED - `v8_Isolate_GetCurrentContext` allocates a Global per call.
    /// The realm of the requestAnimationFrame that registered the callback:
    /// each Window has its own map of animation frame callbacks, so the
    /// callback runs, and reports what it throws, in the window it came from.
    context: *v8.ffi.Context,
    cancelled: bool = false,

    fn deinit(self: AnimationFrameEntry) void {
        v8.ffi.v8_Global_Dispose(@ptrCast(self.callback_fn));
        v8.ffi.v8_Global_Dispose(@ptrCast(self.context));
    }
};

const AnimationFrameState = struct {
    isolate: *v8.ffi.Isolate,
    /// Registered for the NEXT frame, in registration order.
    pending: std.ArrayListUnmanaged(AnimationFrameEntry) = .empty,
    /// The single timer driving the next frame, if one is scheduled.
    timer_id: ?TimerId = null,
    /// The batch currently being run, borrowed from animationFrameHandler's
    /// stack for the duration of the loop. cancelAnimationFrame has to be able
    /// to reach it: per HTML's "run the animation frame callbacks", cancelling
    /// from INSIDE a callback must still suppress a later callback in the SAME
    /// frame, and those entries are no longer in `pending`.
    running: []AnimationFrameEntry = &.{},
    /// Handles are their own space, not the timer id space: per spec
    /// cancelAnimationFrame(someTimeoutId) must do nothing.
    next_handle: u32 = 1,
};

threadlocal var animation_frames: ?AnimationFrameState = null;

/// Captured when the timer interface is installed, which is context setup - close
/// enough to the spec's time origin, and it avoids taking an hr_time dependency
/// here. rAF timestamps are therefore ms since context setup, monotonic and
/// comparable to each other, which is what the frame tests assert.
threadlocal var animation_frame_origin_ms: i64 = 0;

// ============================================================================
// HTML timer initialisation steps (HTML Standard s8.6)
// ============================================================================
//
// setTimeout/setInterval do NOT schedule the delay the author asked for. The spec
// runs "timer initialisation steps" first:
//
//   3. If timeout is less than 0, then set timeout to 0.
//   5. If nesting level is greater than 5, and timeout is less than 4, then set
//      timeout to 4.
//
// and the timer being scheduled records `nesting level + 1`, so a chain of
// self-rescheduling timers is throttled to 4ms once it is more than five deep.
//
// Crane already had a correct implementation of this in
// src/html/event_loop/timers.zig (MIN_NESTED_DELAY_MS, NESTING_LEVEL_THRESHOLD,
// setTimerInternal). It is DEAD CODE - nothing references its TimerManager. The live
// path is this file -> the thread-local TimerInterface -> V8EventLoop -> libuv_timer,
// which applied no clamping whatsoever. So the clamp is implemented here, at the
// setTimeout boundary, which is where the spec puts it: initialisation runs before
// the timer is handed to any scheduler.
//
// Thread-local because the nesting level belongs to the agent, and one agent is one
// thread with one isolate.

// HTML §8.6's nesting and clamp now live in `v8.native_timer`, so the worker
// binding can apply the same rule - it previously had no clamp at all. These are
// aliases, not a second copy: two definitions of a spec constant is how the two
// paths diverged in the first place.
const nested_min_delay_ms = v8.native_timer.nested_min_delay_ms;
const nesting_threshold = v8.native_timer.nesting_threshold;

/// Restore the timer nesting level at the start of the microtask checkpoint.
///
/// A plain `defer` around the callback restores too late. V8's default microtask
/// policy drains the queue when the JS call stack empties - which happens INSIDE
/// `v8_Function_Call` - so a microtask queued by a timer callback would still
/// observe the task's nesting level and have its sub-4ms timeout clamped.
///
/// Microtasks run FIFO, so enqueueing this BEFORE invoking the callback puts it
/// ahead of anything the callback enqueues. That lands the reset exactly on the
/// spec boundary: a setTimeout called synchronously from the callback nests one
/// deeper, while one scheduled from a microtask does not inherit the level at all.
/// The checkpoint runs between tasks, so the level there is 0 by definition.
fn resetNestingMicrotask(_: ?*anyopaque) callconv(.c) void {
    v8.native_timer.nesting_level = 0;
}

/// Invoke a timer or animation frame callback, reporting what it throws.
///
/// HTML's timer initialization steps and "run the animation frame callbacks"
/// invoke the callback with "report": an exception is REPORTED for the
/// global - an ErrorEvent at the Window, `window.onerror` - not printed and
/// dropped, which is all `v8_Function_Call` did. It also returned an owned
/// Global for the result that every caller here threw away.
fn invokeReporting(
    context: *v8.ffi.Context,
    function: *v8.ffi.Function,
    receiver: anytype,
    args: []const *v8.ffi.Value,
) void {
    var threw = false;
    const completion = v8.ffi.v8_Function_CallCatching(
        context,
        @ptrCast(function),
        @ptrCast(receiver),
        @intCast(args.len),
        args.ptr,
        &threw,
    ) orelse return;
    defer v8.ffi.v8_Global_Dispose(completion);
    if (!threw) return;

    const report = html_mod.report_exception;
    const window = report.globalForContext(context) orelse return;
    _ = report.reportException(window, completion, .{});
}

/// Apply the clamping half of the timer initialisation steps.
///
/// Returns the delay actually to be scheduled. Separated from the nesting bookkeeping
/// so it can be unit-tested without a V8 isolate.
const clampTimeout = v8.native_timer.clampTimeout;

/// Set the current timer interface for V8 callbacks
pub fn setTimerInterface(timer: TimerInterface, allocator: std.mem.Allocator) void {
    current_timer_interface = timer;
    current_allocator = allocator;
    // Initialize timer contexts map if needed
    if (timer_contexts == null) {
        timer_contexts = std.AutoHashMap(TimerId, *V8TimerCallback).init(allocator);
    }
    animation_frame_origin_ms = clock.monotonicMillis();

    // Every window created under this one - an iframe's, a popup's - gets the
    // same timer, animation frame and fetch bindings, and gives them up when
    // it is destroyed. They serve every realm from the state above.
    context_manager.setChildContextGlobalsCallback(registerChildContextGlobals);
    context_manager.setChildWindowCleanupCallback(clearChildWindowState);
}

/// Get the current timer interface (for V8 callbacks)
pub fn getTimerInterface() ?TimerInterface {
    return current_timer_interface;
}

/// Clear the timer interface reference and clean up ALL pending timer contexts
/// This properly cancels libuv timers to prevent handle accumulation
pub fn clearTimerInterface() void {
    // Clean up any remaining timer contexts (both one-shot and intervals)
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level to prevent callback from firing
            // and to properly clean up the libuv timer handle.
            //
            // The result is deliberately discarded: this is context teardown, so the
            // timer manager is going away with us and every wrapper must be freed
            // here or leak. Unlike unregisterTimerContext there is no later callback
            // to hand ownership to.
            if (current_timer_interface) |timer| {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            destroyTimer(wrapper);
        }
        map.deinit();
        timer_contexts = null;
    }

    // Animation frames: cancel the frame timer and drop the pending batch. The
    // entries hold Globals owned by V8, not by us, so only the list is freed.
    if (animation_frames) |*state| {
        if (state.timer_id) |id| {
            if (current_timer_interface) |timer| _ = timer.clearTimeout(id);
        }
        // Every pending entry still owns its callback and context Globals.
        for (state.pending.items) |entry| entry.deinit();
        if (current_allocator) |alloc| state.pending.deinit(alloc);
        animation_frames = null;
    }

    context_manager.clearChildContextGlobalsCallback();
    context_manager.clearChildWindowCleanupCallback();
    current_timer_interface = null;
    current_allocator = null;
}

/// Whether two context handles name the same V8 context. Each reads the
/// context's current address; nothing between the two reads can allocate, so
/// no GC can move it in between.
fn sameContext(a: *v8.ffi.Context, b: *v8.ffi.Context) bool {
    return v8.ffi.v8_Context_GetRawAddress(a) == v8.ffi.v8_Context_GetRawAddress(b);
}

/// context_manager's child-window cleanup hook: a frame's document is being
/// destroyed, and with it its window's map of active timers (HTML "unloading
/// document cleanup steps": clear window's map of active timers) and its map
/// of animation frame callbacks. Without this a removed frame's timers kept
/// firing, and a destroyed one's fired into a window whose state was freed.
fn clearChildWindowState(context: *v8.ffi.Context) void {
    if (timer_contexts) |*map| {
        var doomed: std.ArrayListUnmanaged(TimerId) = .empty;
        defer if (current_allocator) |alloc| doomed.deinit(alloc);
        var iter = map.iterator();
        while (iter.next()) |entry| {
            if (!sameContext(entry.value_ptr.*.getData().v8_context, context)) continue;
            const alloc = current_allocator orelse break;
            doomed.append(alloc, entry.key_ptr.*) catch break;
        }
        // Not while iterating: unregistering removes from the map.
        for (doomed.items) |id| unregisterTimerContext(id);
    }

    if (animation_frames) |*state| {
        // The batch in progress sees its own entries through `running`; one
        // of this window's is skipped rather than removed from under the loop.
        for (state.running) |*entry| {
            if (sameContext(entry.context, context)) entry.cancelled = true;
        }
        var i: usize = 0;
        while (i < state.pending.items.len) {
            const entry = state.pending.items[i];
            if (sameContext(entry.context, context)) {
                entry.deinit();
                _ = state.pending.orderedRemove(i);
            } else i += 1;
        }
    }
}

/// A native function on a window's global, bound in that window's realm.
const NativeGlobal = struct {
    name: []const u8,
    callback: v8.ffi.FunctionCallback,
    length: i32,
};

/// What every window gets natively, the top-level one and every frame's: the
/// WebIDL operations for these are stubs. (fetch() is the WebIDL operation,
/// the WindowOrWorkerGlobalScope mixin's.)
const window_native_globals = [_]NativeGlobal{
    .{ .name = "setTimeout", .callback = setTimeoutCallback, .length = 1 },
    .{ .name = "clearTimeout", .callback = clearTimeoutCallback, .length = 0 },
    .{ .name = "setInterval", .callback = setIntervalCallback, .length = 1 },
    .{ .name = "clearInterval", .callback = clearTimeoutCallback, .length = 0 },
    .{ .name = "requestAnimationFrame", .callback = requestAnimationFrameCallback, .length = 1 },
    .{ .name = "cancelAnimationFrame", .callback = cancelAnimationFrameCallback, .length = 1 },
};

/// Define each of `natives` on `global_obj`, as functions of `v8_ctx`'s realm.
fn installNativeGlobals(
    isolate: *v8.ffi.Isolate,
    v8_ctx: *v8.ffi.Context,
    global_obj: *v8.ffi.Object,
    natives: []const NativeGlobal,
) !void {
    for (natives) |native| {
        // Every one of these returns a Global the caller owns; the function
        // keeps its template, and the property keeps the function.
        const template = v8.ffi.v8_FunctionTemplate_New(isolate, native.callback, null) orelse return error.FunctionTemplateCreateFailed;
        defer v8.ffi.v8_FunctionTemplate_Dispose(template);
        v8.ffi.v8_FunctionTemplate_SetLength(template, native.length);
        const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
        defer v8.ffi.v8_Function_Dispose(func);
        const key = v8.ffi.v8_String_NewFromUtf8(isolate, native.name.ptr, @intCast(native.name.len)) orelse return error.StringCreateFailed;
        defer v8.ffi.v8_String_Dispose(key);
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
    }
}

/// context_manager's child-context-globals hook: an iframe's or a popup's
/// window gets the natives the top-level window has. Without it every frame
/// ran the stubs - setTimeout threw NotSupportedError in every iframe.
fn registerChildContextGlobals(isolate: *v8.ffi.Isolate, v8_ctx: *v8.ffi.Context, global_obj: *v8.ffi.Object) void {
    installNativeGlobals(isolate, v8_ctx, global_obj, &window_native_globals) catch |err| {
        log.warn("child window globals not installed: {}", .{err});
    };
}

/// Clear ALL pending timer contexts but keep the timer interface
/// This is used during test isolation to cancel timers without tearing down the interface
pub fn clearPendingTimers() void {
    if (timer_contexts) |*map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            const wrapper = entry.value_ptr.*;
            // Cancel the timer at the libuv level
            if (current_timer_interface) |timer| {
                _ = timer.clearTimeout(wrapper.getData().current_timer_id);
            }
            destroyTimer(wrapper);
        }
        map.clearRetainingCapacity();
    }
}

/// Schedule `wrapper`'s first run and enter it in the map of active timers
/// under the id returned to script. Null when either fails, in which case
/// the wrapper has been freed.
///
/// The id is the manager's id for this FIRST run, and it stays the timer's id
/// for its whole life: an interval's repeats get new manager ids, but the timer
/// initialization steps run again "given ... id", so clearInterval must keep
/// working with the id setInterval returned. It used to be re-keyed to each
/// repeat's manager id, so after the first repeat clearInterval(id) found
/// nothing and the interval ran until the page went away.
fn scheduleTimer(timer: TimerInterface, wrapper: *V8TimerCallback, delay_ms: u64) ?TimerId {
    const map = if (timer_contexts) |*m| m else {
        destroyTimer(wrapper);
        return null;
    };
    const id = timer.setTimeout(delay_ms, V8TimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
    if (id == 0) {
        destroyTimer(wrapper);
        return null;
    }
    wrapper.getData().id = id;
    wrapper.getData().current_timer_id = id;
    map.put(id, wrapper) catch {
        // Untracked, it could never be cleared or cleaned up. Cancel before
        // freeing: a scheduled timer holds the wrapper.
        _ = timer.clearTimeout(id);
        destroyTimer(wrapper);
        return null;
    };
    return id;
}

/// Unregister a timer context (cancels and destroys it)
///
/// Timer IDs are looked up in the map and nowhere else. Passing script's number
/// straight to the manager, as clearTimeout used to, cancelled whatever manager
/// timer had that id - an animation frame, an AbortSignal timeout.
fn unregisterTimerContext(timer_id: TimerId) void {
    if (timer_contexts) |*map| {
        if (map.fetchRemove(timer_id)) |kv| {
            const wrapper = kv.value;
            // Mark as cancelled so interval callbacks know to stop rescheduling.
            // This must happen before anything else: it is the only signal that
            // reaches a callback we could not cancel.
            wrapper.getData().cancelled = true;

            // Cancel at the libuv level so the callback cannot fire.
            //
            // The thread-local TimerInterface belongs to the realm calling
            // clearTimeout, which is NOT necessarily the realm that scheduled the
            // timer. Cross-realm, the id is unknown to this manager and nothing is
            // cancelled - clearTimeout used to return void, so that silent miss was
            // invisible and the wrapper was freed anyway. The armed timer then fired
            // on freed memory and destroyed it a second time: a double free, and a
            // 0xaa-poisoned segfault in destroyChildContext just after.
            //
            // So the wrapper is only freed when cancellation is CONFIRMED. Otherwise
            // ownership passes to the callback, which sees `cancelled` and destroys
            // it when it fires.
            const cancelled = if (current_timer_interface) |timer|
                timer.clearTimeout(wrapper.getData().current_timer_id)
            else
                false;

            // Never free a wrapper whose callback is on the stack - that handler
            // still reads `data` after the callback returns and frees it itself.
            if (cancelled and !wrapper.getData().executing) destroyTimer(wrapper);
        }
    }
}

// ============================================================================
// V8 Timer Context Types
// ============================================================================

/// A converted TimerHandler - `(TrustedScript or DOMString or Function)`.
///
/// Both arms are OWNED Globals, released by `V8TimerContextData.release`.
const TimerHandler = union(enum) {
    /// A callable handler: WebIDL's union conversion picks the Function member.
    function: *v8.ffi.Function,
    /// Anything else, converted by ToString when setTimeout or setInterval
    /// was called. (A TrustedScript converts the same way: its stringifier
    /// is its data.)
    string: *v8.ffi.String,

    fn dispose(self: TimerHandler) void {
        switch (self) {
            .function => |function| v8.ffi.v8_Global_Dispose(@ptrCast(function)),
            .string => |source| v8.ffi.v8_String_Dispose(source),
        }
    }
};

/// V8 Timer Context Data
///
/// Everything one setTimeout or setInterval needs when it fires. Every V8
/// handle in it is an OWNED Global - `info.get` and `v8_Isolate_GetCurrentContext`
/// each allocate one per call - and `release` disposes them all. Nothing did
/// before: the handler and the context leaked on every call, and a Global of a
/// context keeps that realm's whole heap alive, so every page that ever set a
/// timer stayed in memory until the isolate went away.
const V8TimerContextData = struct {
    handler: TimerHandler,
    /// `any... arguments`, passed to a Function handler on every run. OWNED
    /// Globals, in a slice from the wrapper's allocator.
    arguments: []*v8.ffi.Value,
    /// V8 isolate
    isolate: *v8.ffi.Isolate,
    /// The realm the timer was set in. OWNED.
    v8_context: *v8.ffi.Context,
    /// Whether this is an interval (repeating) timer - affects cleanup
    is_interval: bool,
    /// The timeout after conversion and step 4 (negative becomes 0), before
    /// the nesting clamp: an interval re-runs the timer initialization steps
    /// with it, and each repeat clamps afresh.
    timeout_ms: i64 = 0,
    /// The id setTimeout/setInterval returned, and this timer's key in
    /// `timer_contexts`. Stable for the timer's life (see scheduleTimer).
    id: TimerId = 0,
    /// The manager's id for the pending run. An interval gets a new one per repeat.
    current_timer_id: TimerId = 0,
    /// For intervals: whether the interval has been cancelled
    cancelled: bool = false,
    /// This timer's nesting level, per the timer initialisation steps. While its
    /// callback runs, `v8.native_timer.nesting_level` is set to this, so timers created inside
    /// nest one deeper and eventually trip the 4ms clamp.
    nesting_level: u32 = 0,
    /// True while this timer's callback is on the stack.
    ///
    /// A callback may cancel ITSELF - `clearInterval(id)` from inside the interval
    /// is ordinary JS, and testharness cleanups do it routinely. The handler is
    /// still executing on this wrapper at that moment, and destroys it again when
    /// the callback returns, so an unconditional free in unregisterTimerContext is
    /// a double free (and the freed wrapper's context pointer then surfaced as a
    /// 0xaa-poisoned segfault in destroyChildContext).
    ///
    /// While this is set, the running handler owns the wrapper and is the only
    /// thing allowed to free it.
    executing: bool = false,

    /// Dispose every handle this timer owns. Only `destroyTimer` calls it.
    fn release(self: *V8TimerContextData, allocator: std.mem.Allocator) void {
        self.handler.dispose();
        for (self.arguments) |argument| v8.ffi.v8_Global_Dispose(argument);
        allocator.free(self.arguments);
        self.arguments = &.{};
        v8.ffi.v8_Context_Dispose(self.v8_context);
    }
};

/// Type-safe timer callback wrapper for V8 timer contexts.
///
/// Uses SelfContainedWorkCallback to bundle the callback function and context data
/// together, providing compile-time type safety and eliminating manual
/// anyopaque casts in callback functions. The work callback variant stores
/// the allocator internally for no-argument destroy().
const V8TimerCallback = SelfContainedWorkCallback(V8TimerContextData);

/// Free a timer wrapper and every handle it owns. EVERY path that frees one
/// goes through here; `wrapper.destroy()` alone leaks the handles.
fn destroyTimer(wrapper: *V8TimerCallback) void {
    wrapper.getData().release(wrapper.allocator);
    wrapper.destroy();
}

/// Timer initialization step 8's task, steps 8.3-8.5: run the handler in the
/// timer's realm, at the timer's nesting level.
fn runTimerTask(data: *V8TimerContextData) void {
    const isolate = data.isolate;
    const context = data.v8_context;

    // Phase 5 instrumentation: timer callbacks arrive from the event loop, which is
    // exactly where isolate confinement would break if it is broken.
    v8.isolate_ownership.assertOwned(isolate, "Context.timerHandler");

    // A task runs from the event loop: V8 has opened no HandleScope and
    // entered no context for it.
    const scope = v8.ffi.v8_HandleScope_New(isolate) orelse return;
    defer v8.ffi.v8_HandleScope_Dispose(scope);
    v8.ffi.v8_Context_Enter(context);
    defer v8.ffi.v8_Context_Exit(context);

    // Step 1: thisArg is the WindowProxy - Context::Global is the global proxy.
    const this_arg = v8.ffi.v8_Context_Global(context) orelse return;
    defer v8.ffi.v8_Object_Dispose(this_arg);

    // The "current timer nesting level" is this timer's level for the DURATION OF
    // THE CALLBACK ONLY, so timers the callback creates nest one deeper. It is
    // restored before the microtask checkpoint the caller performs: per HTML the
    // checkpoint runs after the task's callback returns, so a timer scheduled from a
    // microtask must NOT inherit the task's nesting level and must not be clamped to
    // 4ms. (wpt: html/webappapis/timers/timer-nesting-not-inherited-in-microtask.html)
    const saved_nesting = v8.native_timer.nesting_level;
    v8.native_timer.nesting_level = data.nesting_level;
    defer v8.native_timer.nesting_level = saved_nesting;

    // Runs ahead of any microtask the callback enqueues; see resetNestingMicrotask.
    v8.ffi.v8_Isolate_EnqueueMicrotask(isolate, &resetNestingMicrotask, null);

    // This handler owns the wrapper for the duration of the callback, so a
    // clearTimeout/clearInterval from inside it defers the free to us.
    data.executing = true;
    defer data.executing = false;

    switch (data.handler) {
        // Step 8.4: invoke handler given arguments and "report", with callback
        // this value set to thisArg.
        .function => |function| invokeReporting(context, function, this_arg, data.arguments),
        // Step 8.5: create a classic script from the string and run it.
        .string => |source| html_mod.script_execution.runTimerHandlerString(context, source),
    }
}

/// Handler function for one-shot timer callbacks (invoked via SelfContainedCallback trampoline)
fn v8TimerHandler(data: *V8TimerContextData) void {
    // Step 8.9: remove global's map[id]. Before the run rather than after, so a
    // clearTimeout(id) from inside the callback finds nothing to free under us.
    if (timer_contexts) |*map| {
        _ = map.remove(data.id);
    }

    runTimerTask(data);

    // Run microtasks after the timer callback (per event loop semantics)
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(data.isolate);

    // Destroy the wrapper - this is a one-shot timer, so clean up after execution
    // Get the wrapper pointer from the data pointer (data is embedded in SelfContainedCallback)
    const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);
    destroyTimer(wrapper);
}

/// Handler function for interval callbacks (invoked via SelfContainedCallback trampoline)
fn v8IntervalHandler(data: *V8TimerContextData) void {
    const wrapper: *V8TimerCallback = @fieldParentPtr("data", data);

    // Check if interval was cancelled
    if (data.cancelled) {
        // unregisterTimerContext could not confirm cancellation (cross-realm), so it
        // left the wrapper alive and handed ownership here. Free it now - this is the
        // last time the timer system will reference it.
        return destroyTimer(wrapper);
    }

    runTimerTask(data);

    // Run microtasks after the timer callback
    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(data.isolate);

    // Steps 8.6-8.8: still in the map - not cleared by the callback or its
    // microtasks - so run the timer initialization steps again, given the
    // same id. Step 3 there: the running task is this timer's, so its nesting
    // level is this one's, and step 5 clamps with it; step 9 nests one deeper.
    if (!data.cancelled) {
        if (getTimerInterface()) |timer| {
            const delay: u64 = @intCast(clampTimeout(data.timeout_ms, data.nesting_level));
            data.nesting_level +|= 1;
            const new_timer_id = timer.setTimeout(delay, V8TimerCallback.getTrampolineCallback(), wrapper.eraseForFFI());
            if (new_timer_id != 0) {
                // The id script holds stays the key; only the pending run changes.
                data.current_timer_id = new_timer_id;
                return;
            }
        }
    }

    // Cancelled, or it could not be rescheduled: this was its last run.
    if (timer_contexts) |*map| {
        if (map.get(data.id) == wrapper) _ = map.remove(data.id);
    }
    destroyTimer(wrapper);
}

/// Context type for determining which globals to register
pub const ContextType = enum {
    /// Window context (for HTML pages)
    window,
    /// Dedicated worker context
    worker,
    /// Shared worker context
    shared_worker,
    /// Service worker context
    service_worker,
};

/// V8 Context representing a single page navigation
pub const Context = struct {
    allocator: std.mem.Allocator,
    /// V8 isolate (owned by Browser, not Context)
    isolate: *v8.ffi.Isolate,
    /// V8 context for this navigation
    v8_context: ?*v8.ffi.Context,
    /// Storage subsystem (shared across navigations)
    storage: *Storage,
    /// Current URL
    url: []const u8,
    /// Context type
    context_type: ContextType,
    /// Whether context is ready for execution
    initialized: bool,
    /// Event loop reference (owned by Browser)
    event_loop: ?*v8.V8EventLoop,
    /// Whether to skip interface binding registration (when using snapshot)
    skip_bindings: bool,

    // Singleton instances for cleanup
    window_instance: ?*runtime.Instance = null,
    document_instance: ?*runtime.Instance = null,
    navigator_instance: ?*runtime.Instance = null,
    location_instance: ?*runtime.Instance = null,
    history_instance: ?*runtime.Instance = null,
    performance_instance: ?*runtime.Instance = null,

    // Debug counter for tracking context lifecycle
    var context_id_counter: u32 = 0;

    /// Initialize a new Context
    ///
    /// Creates a V8 context within the existing isolate and registers all
    /// browser globals.
    ///
    /// If `skip_bindings` is true (when isolate was created from snapshot),
    /// the interface registration step is skipped since interfaces are already
    /// available in the snapshot.
    pub fn init(
        allocator: std.mem.Allocator,
        isolate: *v8.ffi.Isolate,
        storage: *Storage,
        url: []const u8,
        event_loop: ?*v8.V8EventLoop,
        context_type: ContextType,
        skip_bindings: bool,
    ) !*Context {
        context_id_counter += 1;
        const ctx_id = context_id_counter;
        log.debug("\n[Context.init] === Creating context #{d} ===\n", .{ctx_id});
        log.debug("[Context.init] URL: {s}\n", .{url});
        log.debug("[Context.init] Isolate: {*}\n", .{isolate});

        const ctx = try allocator.create(Context);
        errdefer allocator.destroy(ctx);

        const url_copy = try allocator.dupe(u8, url);
        errdefer allocator.free(url_copy);

        ctx.* = Context{
            .allocator = allocator,
            .isolate = isolate,
            .v8_context = null,
            .storage = storage,
            .url = url_copy,
            .context_type = context_type,
            .initialized = false,
            .event_loop = event_loop,
            .skip_bindings = skip_bindings,
        };

        try ctx.createV8Context();
        return ctx;
    }

    /// Create V8 context and register globals
    /// Uses a global template with internal fields to support Window instance binding.
    ///
    /// OPTIMIZATION: When skip_bindings is true (isolate was created from snapshot),
    /// we use v8_Context_NewFromSnapshot() which restores a context with all 1,099
    /// WebIDL interfaces already registered. This is the FAST path (~2ms).
    ///
    /// When skip_bindings is false, we create a fresh context and register all
    /// interfaces manually. This is the SLOW path (~40ms).
    fn createV8Context(self: *Context) !void {
        var v8_ctx: *v8.ffi.Context = undefined;

        if (self.skip_bindings) {
            // FAST PATH: Use snapshot context with interfaces already registered
            // The snapshot contains all WebIDL interfaces pre-registered on the global,
            // so we don't need to call initializeBindings() - saving ~1099 registrations.
            v8_ctx = v8.ffi.v8_Context_NewFromSnapshot(self.isolate) orelse {
                // Fallback to slow path if snapshot context fails
                log.debug("Warning: Snapshot context failed, falling back to fresh context\n", .{});
                return self.createV8ContextFresh();
            };
        } else {
            // SLOW PATH: Create fresh context without snapshot
            return self.createV8ContextFresh();
        }

        self.v8_context = v8_ctx;
        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks (only if not already initialized)
        // The context manager is per-thread, so it only needs to be initialized once.
        // Subsequent context creations within the same thread will get AlreadyInitialized.
        context_manager.init(self.allocator) catch |err| {
            if (err != error.AlreadyInitialized) {
                log.debug("Warning: Context manager init failed: {}\n", .{err});
            }
        };

        // Register context with context manager for wrapper caching
        // Pass timer and event loop interfaces so all runtime contexts share the same libuv loop
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            log.debug("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // SNAPSHOT MODE: Skip initializeBindings() - interfaces are already in the snapshot!
        // However, we still need to populate the Zig-side template registry so that
        // wrapInstanceAsV8Object() can wrap Document, Navigator, etc. with correct prototypes.
        v8.interface_bindings.registerAllTemplatesOnly(self.isolate, v8_ctx, .eager);

        // Register namespaces (console, WebAssembly, etc.) which are NOT included in the snapshot.
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

        // Fix Window instanceof by patching Window[Symbol.hasInstance].
        // V8 snapshots don't preserve the identity between Function.prototype and
        // objects in the prototype chain. So after snapshot restore, Window.prototype
        // is a different object than what's in global's prototype chain.
        //
        // Instead of trying to fix the prototype identity (which V8 prevents),
        // we patch Symbol.hasInstance to check the internal type info, which IS
        // correctly preserved in the snapshot.
        v8.ffi.v8_PatchWindowInstanceOf(self.isolate, v8_ctx, global);

        // Patch Document[Symbol.hasInstance] for cross-context instanceof checks.
        // When iframe.contentDocument is accessed from this context, the returned
        // Document is from the child context with a different prototype chain.
        // This custom Symbol.hasInstance checks the internal type info instead.
        v8.ffi.v8_PatchDocumentInstanceOf(self.isolate, v8_ctx, global);

        // Patch Event[Symbol.hasInstance] for event instanceof checks.
        // V8 snapshots don't preserve prototype identity, so event objects created
        // and dispatched within the runtime fail instanceof Event checks.
        v8.ffi.v8_PatchEventInstanceOf(self.isolate, v8_ctx, global);

        // Create and bind Window instance to global object's internal fields
        // This is required for WebIDL method callbacks to extract the Zig instance from `this`
        const Window = interfaces.Window;
        const WindowImpl = impls.Window;
        const window_instance = Window.init(self.allocator, runtime_ctx) catch |err| {
            log.debug("Warning: Failed to create Window instance: {}\n", .{err});
            self.window_instance = null;
            return;
        };
        self.window_instance = window_instance;

        // CRITICAL: Set this Window as the active window on its browsing context.
        // Per HTML spec §7.4, every browsing context has an "active window" which is the
        // Window object of its active document. This is required for:
        // - frames[index] access to work (WindowProxy [[GetOwnProperty]] calls getActiveWindow())
        // - iframe.contentWindow.parent to return the correct parent window
        // Without this, getActiveWindow() returns null and parent falls back to self.
        if (WindowImpl.getInternal(window_instance)) |internal| {
            internal.browsing_context.setActiveWindow(@ptrCast(window_instance));
        }

        // Store Window instance in internal field 0
        v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));

        // Store WrapperTypeInfo in internal field 1 for type-safe unwrapping
        if (v8.dom_type_info.getTypeInfoByName("Window")) |type_info| {
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
        }

        // Bind the V8 global to the Window instance for cross-realm access
        impls.Window.setBoundV8Global(window_instance, @ptrCast(global));

        // Register Window with context manager for getWindowForContext()
        // This is critical for cross-origin security checks where we need to get
        // the accessor's Window from the entered context.
        v8.context_manager.setWindowForContext(v8_ctx, window_instance) catch |err| {
            log.debug("Warning: Failed to setWindowForContext: {}\n", .{err});
        };

        // Register Window in wrapper cache for proper cleanup
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.set(window_instance, global, self.isolate) catch {};
        }

        // Create and register Realm for cross-realm support
        // The Realm stores V8 context and isolate pointers needed for:
        // - iframe named property registration (window['frameName'] = contentWindow)
        // - cross-realm error creation
        // - intrinsic caching
        if (runtime_ctx.realm == null) {
            const realm = runtime.Realm.init(self.allocator, .{
                .v8_context = @ptrCast(v8_ctx),
                .isolate = @ptrCast(self.isolate),
                .context_type = .window,
                .global_object = @ptrCast(window_instance),
            }) catch |err| {
                log.debug("Warning: Failed to create Realm: {}\n", .{err});
                return;
            };
            _ = realm.populateIntrinsics();
            runtime_ctx.setRealm(realm);
            // Also register with context manager
            context_manager.setRealmForContext(v8_ctx, realm) catch {};
        }

        // Register Window properties (document, navigator, etc.) as own properties on the global object.
        // This is required because the global's prototype is immutable (set via SetImmutableProto),
        // so we can't inherit properties from Window.prototype through the prototype chain.
        // This matches how child contexts (iframes) register Window properties.
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

        // Register Window methods (queueMicrotask, setTimeout, etc.) as own properties on the global object.
        // Per WebIDL §3.8: For [Global] interfaces, the global object should have
        // the interface's operations as own properties (callable functions).
        v8.interface_bindings.Window.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Also register EventTarget methods (addEventListener, removeEventListener, dispatchEvent)
        // since Window inherits from EventTarget.
        v8.interface_bindings.EventTarget.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Insert WindowProperties into the prototype chain for named property access.
        // Per HTML spec §7.4.3, Window supports named property access for:
        // 1. Child browsing contexts (iframe names) - frames['name'] returns contentWindow
        // 2. Named elements in the document (elements with id/name attributes)
        // The WindowProperties object has a named property handler that intercepts these accesses.
        _ = v8.window_properties.insertIntoPrototypeChain(self.isolate, v8_ctx, window_instance);

        // Set self/window/frames as data properties equal to global
        // This is critical for testharness.js compatibility: (function(global_scope){...})(self)
        // requires that self === globalThis so that properties set on global_scope become
        // accessible as global variables. These are skipped in registerPropertiesAsOwnOnObject
        // because they need to be data properties (not accessors) for object identity.
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4)) |self_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6)) |window_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "frames", 6)) |frames_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(frames_prop_key), @ptrCast(global));
        }

        // Set up global aliases FIRST (creates __internal object and accessor properties)
        // This must happen before registerBrowserGlobals() which stores singletons in __internal
        self.setupGlobalAliases() catch |err| {
            // Log but continue - setupGlobalAliases failing shouldn't prevent context creation
            log.debug("Warning: setupGlobalAliases failed: {} - continuing\n", .{err});
        };

        // Register browser globals based on context type
        // For window context, stores Document, Navigator, etc. in __internal
        try self.registerBrowserGlobals();

        // Set up timer interface in thread-local storage
        // This needs to be available for JavaScript setTimeout/setInterval calls
        if (self.event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        self.initialized = true;
    }

    /// SLOW PATH: Create fresh V8 context without using snapshot
    /// This is used when no snapshot is available, or as a fallback when snapshot context fails.
    fn createV8ContextFresh(self: *Context) !void {
        // Create fresh template with internal fields
        // This allows WebIDL method callbacks to get the Zig instance from `this`
        const global_template = v8.ffi.v8_ObjectTemplate_New(self.isolate);
        v8.ffi.v8_ObjectTemplate_SetInternalFieldCount(global_template, 2);

        // Per WebIDL spec §3.8, all objects in the global prototype chain must have
        // immutable [[Prototype]]. Object.setPrototypeOf(globalThis, {}) must throw TypeError.
        v8.ffi.v8_ObjectTemplate_SetImmutableProto(global_template);

        // Create V8 context with the global template
        const v8_ctx = v8.ffi.v8_Context_NewWithGlobalTemplate(self.isolate, global_template) orelse {
            return error.ContextCreateFailed;
        };
        self.v8_context = v8_ctx;

        v8.ffi.v8_Context_Enter(v8_ctx);

        // Initialize context manager for V8 callbacks (only if not already initialized)
        context_manager.init(self.allocator) catch |err| {
            if (err != error.AlreadyInitialized) {
                log.debug("Warning: Context manager init failed: {}\n", .{err});
            }
        };

        // Register context with context manager for wrapper caching
        const timer_iface = if (self.event_loop) |ev| ev.timerInterface() else null;
        const event_loop_iface = if (self.event_loop) |ev| ev.eventLoop() else null;
        const runtime_ctx = context_manager.getOrCreateWithExternalEventLoop(v8_ctx, timer_iface, event_loop_iface, self.allocator) catch |err| {
            log.debug("Warning: Context registration failed: {}\n", .{err});
            return error.ContextRegistrationFailed;
        };

        // SLOW PATH: Register all WebIDL interfaces manually
        // This is required for fresh contexts without snapshot
        v8.interface_bindings.initializeBindingsWithGlobalTemplate(self.isolate, v8_ctx);

        // Register all namespaces
        v8.interface_bindings.registerNamespacesGeneric(namespaces, self.isolate, v8_ctx);

        // Get the global object
        const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
            return error.NoGlobal;
        };

        // Set up Window prototype chain
        const window_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "Window", 6);
        if (window_key) |wk| {
            if (v8.ffi.v8_Object_Get(global, v8_ctx, @ptrCast(wk))) |window_ctor| {
                const proto_key = v8.ffi.v8_String_NewFromUtf8(self.isolate, "prototype", 9);
                if (proto_key) |pk| {
                    if (v8.ffi.v8_Object_Get(@ptrCast(window_ctor), v8_ctx, @ptrCast(pk))) |window_proto| {
                        _ = v8.ffi.v8_Object_SetPrototypeV2(global, v8_ctx, window_proto);
                    }
                }
            }
        }

        // Create and bind Window instance
        const Window = interfaces.Window;
        const WindowImpl = impls.Window;
        const window_instance = Window.init(self.allocator, runtime_ctx) catch |err| {
            log.debug("Warning: Failed to create Window instance: {}\n", .{err});
            self.window_instance = null;
            return;
        };
        self.window_instance = window_instance;

        // CRITICAL: Set this Window as the active window on its browsing context.
        // Per HTML spec §7.4, every browsing context has an "active window" which is the
        // Window object of its active document. This is required for:
        // - frames[index] access to work (WindowProxy [[GetOwnProperty]] calls getActiveWindow())
        // - iframe.contentWindow.parent to return the correct parent window
        // Without this, getActiveWindow() returns null and parent falls back to self.
        if (WindowImpl.getInternal(window_instance)) |internal| {
            internal.browsing_context.setActiveWindow(@ptrCast(window_instance));
        }

        // Store Window instance in internal field 0
        v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, @ptrCast(window_instance));

        // Store WrapperTypeInfo in internal field 1
        if (v8.dom_type_info.getTypeInfoByName("Window")) |type_info| {
            v8.ffi.v8_Object_SetAlignedPointerInInternalField(global, 1, @ptrCast(@constCast(type_info)));
        }

        // Bind the V8 global to the Window instance
        WindowImpl.setBoundV8Global(window_instance, @ptrCast(global));

        // Register Window with context manager for getWindowForContext()
        // This is critical for cross-origin security checks where we need to get
        // the accessor's Window from the entered context.
        v8.context_manager.setWindowForContext(v8_ctx, window_instance) catch |err| {
            log.debug("Warning: Failed to setWindowForContext: {}\n", .{err});
        };

        // Register Window in wrapper cache
        if (runtime_ctx.getV8WrapperCacheStorage()) |cache_storage| {
            const cache: *v8.wrapper_cache_mod.WrapperCache = @ptrCast(@alignCast(cache_storage));
            cache.set(window_instance, global, self.isolate) catch {};
        }

        // Register Window properties as own properties on the global object
        v8.interface_bindings.Window.registerPropertiesAsOwnOnObject(self.isolate, v8_ctx, global);

        // Register Window methods (queueMicrotask, setTimeout, etc.) as own properties on the global object.
        // Per WebIDL §3.8: For [Global] interfaces, the global object should have
        // the interface's operations as own properties (callable functions).
        v8.interface_bindings.Window.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Also register EventTarget methods (addEventListener, removeEventListener, dispatchEvent)
        // since Window inherits from EventTarget.
        v8.interface_bindings.EventTarget.registerMethodsAsOwnOnObject(self.isolate, v8_ctx, global);

        // Insert WindowProperties into the prototype chain for named property access.
        // Per HTML spec §7.4.3, Window supports named property access for:
        // 1. Child browsing contexts (iframe names) - frames['name'] returns contentWindow
        // 2. Named elements in the document (elements with id/name attributes)
        // The WindowProperties object has a named property handler that intercepts these accesses.
        _ = v8.window_properties.insertIntoPrototypeChain(self.isolate, v8_ctx, window_instance);

        // Set self/window/frames as data properties equal to global
        // This is critical for testharness.js compatibility
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "self", 4)) |self_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(self_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "window", 6)) |window_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(window_prop_key), @ptrCast(global));
        }
        if (v8.ffi.v8_String_NewFromUtf8(self.isolate, "frames", 6)) |frames_prop_key| {
            _ = v8.ffi.v8_Object_Set(global, v8_ctx, @ptrCast(frames_prop_key), @ptrCast(global));
        }

        // Set up global aliases
        self.setupGlobalAliases() catch |err| {
            log.debug("Warning: setupGlobalAliases failed: {} - continuing\n", .{err});
        };

        // Register browser globals
        try self.registerBrowserGlobals();

        // Set up timer interface
        if (self.event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timer| {
                setTimerInterface(timer, self.allocator);
            }
        }

        self.initialized = true;
    }

    /// Register browser globals based on context type
    fn registerBrowserGlobals(self: *Context) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;
        const global_obj = v8.ffi.v8_Context_Global(v8_ctx) orelse return error.NoGlobal;

        // Get runtime context for wrapper caching
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            log.debug("Warning: Failed to get runtime context: {}\n", .{err});
            return;
        };

        switch (self.context_type) {
            .window => try self.registerWindowGlobals(global_obj, runtime_ctx),
            .worker => try self.registerWorkerGlobals(global_obj, runtime_ctx),
            else => {},
        }

        // Register common globals (setTimeout, fetch, console, etc.)
        try self.registerCommonGlobals(global_obj);
    }

    /// Register Window context globals
    /// NOTE: Singletons are stored in __internal object, accessed via accessor properties
    /// defined in setupGlobalAliases(). This follows the WebIDL spec pattern.
    fn registerWindowGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // NOTE: 'self' is handled by Window interface accessor property (get_self).
        // Do NOT set 'self' as a data property here - it would overwrite the accessor
        // and result in the raw Global<Object>* pointer being visible to JavaScript
        // as a number instead of the actual global object.

        // Get __internal object for storing singleton values
        // The accessor properties defined in setupGlobalAliases() read from __internal
        const internal_key = v8.ffi.v8_String_NewFromUtf8(isolate, "__internal", 10) orelse return error.StringCreateFailed;
        defer v8.ffi.v8_String_Dispose(internal_key);
        const internal_obj = v8.ffi.v8_Object_Get(global_obj, v8_ctx, @ptrCast(internal_key)) orelse {
            log.debug("Warning: __internal object not found on global\n", .{});
            return error.ObjectNotFound;
        };
        // Owned, and it lives in this context: leaked, it kept the page alive.
        defer v8.ffi.v8_Value_Dispose(internal_obj);

        // Register Document singleton (stored in __internal.document)
        {
            const Document = interfaces.Document;
            const doc_instance = Document.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create document singleton: {}\n", .{err});
                return;
            };
            self.document_instance = doc_instance;

            // Link the document to the Window instance so window.document accessor works
            if (self.window_instance) |win| {
                impls.Window.setDocument(win, doc_instance);
                // Set the defaultView on the document (bidirectional Document <-> Window link)
                impls.Document.setDefaultView(doc_instance, win);
            }

            const v8_document = v8.template_registry.wrapInstanceAsV8Object(
                doc_instance,
                "Document",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap document: {}\n", .{err});
                return;
            };

            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "document", 8) orelse return error.StringCreateFailed;

            defer v8.ffi.v8_String_Dispose(doc_key);
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(doc_key), @ptrCast(v8_document));
        }

        // Register Navigator singleton (stored in __internal.navigator)
        {
            const Navigator = interfaces.Navigator;
            const nav_instance = Navigator.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create navigator: {}\n", .{err});
                return;
            };
            self.navigator_instance = nav_instance;

            // Link the navigator to the Window instance so window.navigator accessor works
            if (self.window_instance) |win| {
                impls.Window.setNavigator(win, nav_instance);
            }

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "Navigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap navigator: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Navigator.deinit(nav_instance);
                self.navigator_instance = null;
                return;
            };

            const nav_key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;

            defer v8.ffi.v8_String_Dispose(nav_key);
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(nav_key), @ptrCast(v8_navigator));
        }

        // Register Location singleton (stored in __internal.location)
        {
            const Location = interfaces.Location;
            const loc_instance = Location.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create location: {}\n", .{err});
                return;
            };
            self.location_instance = loc_instance;

            // Link the location to the Window instance so window.location accessor works
            if (self.window_instance) |win| {
                impls.Window.setLocation(win, loc_instance);
                // Set up bi-directional link: Location knows its Window
                impls.Location.setWindow(loc_instance, win);
                // Note: Top-level navigation callback is not set here yet
                // Full top-level navigation requires Phase 6: Navigation & History
            }

            const v8_location = v8.template_registry.wrapInstanceAsV8Object(
                loc_instance,
                "Location",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap location: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Location.deinit(loc_instance);
                self.location_instance = null;
                return;
            };

            const loc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "location", 8) orelse return error.StringCreateFailed;

            defer v8.ffi.v8_String_Dispose(loc_key);
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(loc_key), @ptrCast(v8_location));
        }

        // Register History singleton (stored in __internal.history)
        {
            const History = interfaces.History;
            const hist_instance = History.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create history: {}\n", .{err});
                return;
            };
            self.history_instance = hist_instance;

            // Link the history to the Window instance so window.history accessor works
            if (self.window_instance) |win| {
                impls.Window.setHistory(win, hist_instance);
            }

            const v8_history = v8.template_registry.wrapInstanceAsV8Object(
                hist_instance,
                "History",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap history: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                History.deinit(hist_instance);
                self.history_instance = null;
                return;
            };

            const hist_key = v8.ffi.v8_String_NewFromUtf8(isolate, "history", 7) orelse return error.StringCreateFailed;

            defer v8.ffi.v8_String_Dispose(hist_key);
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(hist_key), @ptrCast(v8_history));
        }

        // Register Performance singleton (stored in __internal.performance)
        {
            const Performance = interfaces.Performance;
            const perf_instance = Performance.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create performance: {}\n", .{err});
                return;
            };
            self.performance_instance = perf_instance;

            // Link the performance to the Window instance so window.performance accessor works
            if (self.window_instance) |win| {
                impls.Window.setPerformance(win, perf_instance);
            }

            const v8_performance = v8.template_registry.wrapInstanceAsV8Object(
                perf_instance,
                "Performance",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap performance: {}\n", .{err});
                // Clean up the instance we just created to avoid memory leak
                Performance.deinit(perf_instance);
                self.performance_instance = null;
                return;
            };

            const perf_key = v8.ffi.v8_String_NewFromUtf8(isolate, "performance", 11) orelse return error.StringCreateFailed;

            defer v8.ffi.v8_String_Dispose(perf_key);
            _ = v8.ffi.v8_Object_Set(@ptrCast(internal_obj), v8_ctx, @ptrCast(perf_key), @ptrCast(v8_performance));
        }

        // Register HTMLDocument as legacy alias for Document
        // Per HTML spec, HTMLDocument is a historical alias that maps to Document
        {
            const doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "Document", 8) orelse return error.StringCreateFailed;
            defer v8.ffi.v8_String_Dispose(doc_key);
            const doc_ctor = v8.ffi.v8_Object_Get(global_obj, v8_ctx, @ptrCast(doc_key));
            defer if (doc_ctor) |c| v8.ffi.v8_Value_Dispose(c);
            if (doc_ctor) |ctor| {
                const html_doc_key = v8.ffi.v8_String_NewFromUtf8(isolate, "HTMLDocument", 12) orelse return error.StringCreateFailed;
                defer v8.ffi.v8_String_Dispose(html_doc_key);
                _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(html_doc_key), ctor);
            }
        }
    }

    /// Register Worker context globals
    fn registerWorkerGlobals(
        self: *Context,
        global_obj: *v8.ffi.Object,
        runtime_ctx: runtime.Context,
    ) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Register 'self' as reference to global object
        const self_key = v8.ffi.v8_String_NewFromUtf8(isolate, "self", 4) orelse return error.StringCreateFailed;
        _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(self_key), @ptrCast(global_obj));

        // Register WorkerNavigator
        {
            const WorkerNavigator = interfaces.WorkerNavigator;
            const nav_instance = WorkerNavigator.init(self.allocator, runtime_ctx) catch |err| {
                log.debug("Warning: Failed to create worker navigator: {}\n", .{err});
                return;
            };

            const v8_navigator = v8.template_registry.wrapInstanceAsV8Object(
                nav_instance,
                "WorkerNavigator",
                isolate,
                v8_ctx,
            ) catch |err| {
                log.debug("Warning: Failed to wrap worker navigator: {}\n", .{err});
                return;
            };

            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "navigator", 9) orelse return error.StringCreateFailed;
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(v8_navigator));
        }
    }

    /// Register common globals (setTimeout, fetch, console, etc.)
    fn registerCommonGlobals(self: *Context, global_obj: *v8.ffi.Object) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // setTimeout, setInterval, their clears, animation frames and fetch -
        // the same natives every frame's window gets.
        try installNativeGlobals(isolate, v8_ctx, global_obj, &window_native_globals);

        // addEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, addEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            defer v8.ffi.v8_FunctionTemplate_Dispose(template);
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            defer v8.ffi.v8_Function_Dispose(func);
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "addEventListener", 16) orelse return error.StringCreateFailed;
            defer v8.ffi.v8_String_Dispose(key);
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // removeEventListener
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, removeEventListenerCallback, null) orelse return error.FunctionTemplateCreateFailed;
            defer v8.ffi.v8_FunctionTemplate_Dispose(template);
            v8.ffi.v8_FunctionTemplate_SetLength(template, 2);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            defer v8.ffi.v8_Function_Dispose(func);
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "removeEventListener", 19) orelse return error.StringCreateFailed;
            defer v8.ffi.v8_String_Dispose(key);
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // dispatchEvent
        {
            const template = v8.ffi.v8_FunctionTemplate_New(isolate, dispatchEventCallback, null) orelse return error.FunctionTemplateCreateFailed;
            defer v8.ffi.v8_FunctionTemplate_Dispose(template);
            v8.ffi.v8_FunctionTemplate_SetLength(template, 1);
            const func = v8.ffi.v8_FunctionTemplate_GetFunction(template, v8_ctx) orelse return error.FunctionCreateFailed;
            defer v8.ffi.v8_Function_Dispose(func);
            const key = v8.ffi.v8_String_NewFromUtf8(isolate, "dispatchEvent", 13) orelse return error.StringCreateFailed;
            defer v8.ffi.v8_String_Dispose(key);
            _ = v8.ffi.v8_Object_Set(global_obj, v8_ctx, @ptrCast(key), @ptrCast(func));
        }

        // NOTE: console object is registered via WebIDL namespace binding in snapshot
        // (see bindings.zig initializeNamespaces -> Console.registerGlobal)
        // The native binding provides proper console.log/error/etc with output to stderr

        // NOTE: getComputedStyle is now properly defined on Window.prototype via WebIDL binding.
        // The Window.call_getComputedStyle implementation creates a proper CSSStyleDeclaration
        // with named property handlers for CSS property access (e.g., style.borderStyle).
        // Do NOT register a stub here - it would shadow the proper implementation.

    }

    /// Set up global aliases via JavaScript
    /// Per WebIDL spec, window properties use accessor properties with proper this validation
    fn setupGlobalAliases(self: *Context) !void {
        const setup_script = switch (self.context_type) {
            .window =>
            // Window context: Set up __internal for singleton storage and GLOBAL for WPT tests
            // NOTE: Do NOT set self or window here! They are accessor properties registered by
            // registerPropertiesAsOwnOnObject() via the Window interface. Setting them here
            // would overwrite the accessor with a data property, breaking the getter mechanism.
            // NOTE: Do NOT try to set parent, top, opener, frames, length here!
            // These are read-only accessor properties defined by Window interface bindings.
            // The Window impl handles returning the correct values for these properties.
            \\globalThis.__internal = globalThis.__internal || { isSecureContext: false };
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return true; },
            \\  isWorker: function() { return false; },
            \\  isShadowRealm: function() { return false; }
            \\};
            \\
            \\// NOTE: document, navigator, location, history, performance are exposed via
            \\// the Window interface's attribute getters. We only set up __internal for
            \\// storage, and the Window impl's getters retrieve from there.
            ,
            .worker =>
            // Dedicated worker context: self, navigator, location
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface DedicatedWorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
            .shared_worker, .service_worker =>
            // Shared/Service worker context: only self, no window
            \\function __checkGlobalThis(thisArg, propName) {
            \\  if (thisArg === null || thisArg === undefined) {
            \\    return globalThis;
            \\  }
            \\  if (thisArg === globalThis) {
            \\    return globalThis;
            \\  }
            \\  throw new TypeError("'" + propName + "' called on an object that does not implement interface WorkerGlobalScope.");
            \\}
            \\
            \\Object.defineProperty(globalThis, 'self', {
            \\  get: function() { return __checkGlobalThis(this, 'self'); },
            \\  enumerable: true, configurable: true
            \\});
            \\
            \\// Set up GLOBAL object for WPT tests - WORKER context
            \\globalThis.GLOBAL = {
            \\  isWindow: function() { return false; },
            \\  isWorker: function() { return true; },
            \\  isShadowRealm: function() { return false; },
            \\};
            ,
        };

        self.runScript(setup_script) catch |err| {
            log.debug("ERROR: Failed to set up global aliases: {}\n", .{err});
            return err;
        };
    }

    /// Options for loadPage
    pub const LoadPageOptions = struct {
        /// Optional script loader for external scripts
        script_loader: ?ScriptLoader = null,
    };

    /// Load page content (fetch, parse, execute)
    ///
    /// Navigation flow per HTML Standard:
    /// 1. Fetch URL content via HTTP
    /// 2. Parse HTML into DOM tree
    /// 3. Execute inline and external scripts (in document order)
    /// 4. Fire DOMContentLoaded event
    /// 5. Fire load event
    pub fn loadPage(self: *Context) !void {
        return self.loadPageWithOptions(.{});
    }

    /// Load page content with options
    pub fn loadPageWithOptions(self: *Context, options: LoadPageOptions) !void {
        // For about:blank, just return with empty document
        if (std.mem.eql(u8, self.url, "about:blank")) {
            return;
        }

        // Step 1: Fetch URL content via HTTP
        //
        // Propagate the navigation error rather than flattening it to
        // `NavigationFailed`. The WPT runner prints whatever comes back here,
        // and one catch-all name made a DNS failure, a refused connection, a
        // TLS error and a missing file read identically in the journal.
        var result = try navigation.fetchUrl(self.allocator, self.url, .{});
        defer result.deinit();

        // Step 2: Check if HTML content
        const is_html = std.mem.indexOf(u8, result.content_type, "text/html") != null or
            std.mem.indexOf(u8, result.content_type, "application/xhtml") != null;

        if (!is_html) {
            // For non-HTML content, just return
            // This is a simplified approach for now
            return;
        }

        // Step 3-5: Parse HTML and execute scripts using loadHTML
        // This uses the full HTML parser with proper script loading
        try self.loadHTML(result.body, .{
            .base_url = self.url,
            .scripting_enabled = true,
            .script_loader = options.script_loader,
        });
    }

    /// Execute inline scripts from HTML content
    fn executeInlineScripts(self: *Context, html: []const u8) !void {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Simple script extractor - find <script>...</script> blocks
        var pos: usize = 0;
        while (pos < html.len) {
            // Find <script
            const script_start = std.mem.indexOfPos(u8, html, pos, "<script") orelse break;

            // Find > (end of opening tag)
            const tag_end = std.mem.indexOfPos(u8, html, script_start, ">") orelse break;

            // Check if it's a src script (external) - skip those for now
            const tag_attrs = html[script_start..tag_end];
            if (std.mem.indexOf(u8, tag_attrs, " src=") != null or
                std.mem.indexOf(u8, tag_attrs, " src =") != null)
            {
                // External script - skip for now
                // TODO: Fetch and execute external scripts
                pos = tag_end + 1;
                continue;
            }

            // Find </script>
            const script_end = std.mem.indexOfPos(u8, html, tag_end, "</script>") orelse break;

            // Extract script content
            const script_content = html[tag_end + 1 .. script_end];

            if (script_content.len > 0) {
                // Execute the script
                _ = self.evaluateScriptSafe(script_content, isolate, v8_ctx);
            }

            pos = script_end + 9; // Move past </script>
        }
    }

    /// Evaluate script with error handling (doesn't propagate errors)
    fn evaluateScriptSafe(
        self: *Context,
        script: []const u8,
        isolate: *v8.ffi.Isolate,
        v8_ctx: *v8.ffi.Context,
    ) ?*v8.ffi.Value {
        _ = self;

        const source_str = v8.ffi.v8_String_NewFromUtf8(
            isolate,
            script.ptr,
            @intCast(script.len),
        ) orelse return null;

        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            // Log compile error but continue
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    var buf: [1024]u8 = undefined;
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const write_len: usize = @min(@as(usize, @intCast(len)), buf.len - 1);
                    _ = v8.ffi.v8_String_WriteUtf8(str, &buf, @intCast(write_len));
                    log.debug("Script compile error: {s}\n", .{buf[0..write_len]});
                }
            }
            return null;
        };

        const result = v8.ffi.v8_Script_Run(v8_ctx, compiled);

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        return result;
    }

    // ============================================================================
    // HTML Loading and Parsing
    // ============================================================================

    /// Script loader callback type for external script loading
    /// Returns script content for the given URL, or null if loading failed
    pub const ScriptLoaderFn = *const fn (ctx: *anyopaque, url: []const u8) ?[]const u8;

    /// Script loader interface for customizing how external scripts are loaded
    pub const ScriptLoader = struct {
        context: *anyopaque,
        loadScript: ScriptLoaderFn,
    };

    /// Options for HTML loading
    pub const LoadHTMLOptions = struct {
        /// Base URL for resolving relative URLs
        base_url: []const u8,
        /// Enable script execution during parsing (default: true)
        scripting_enabled: bool = true,
        /// Custom script loader (optional)
        /// If null, external scripts will use default HTTP fetch
        script_loader: ?ScriptLoader = null,
    };

    /// Load and parse HTML content into the document
    ///
    /// This method:
    /// 1. Sets up the document URL and Window origin
    /// 2. Parses HTML using HTMLParser.parseHTMLWithScripting()
    /// 3. Executes inline and external scripts during parsing
    /// 4. Initializes iframe browsing contexts
    /// 5. Fires DOMContentLoaded after parsing
    ///
    /// Per HTML Standard §13.2.7 "The end":
    /// - Scripts execute during parsing (inline and deferred)
    /// - DOMContentLoaded fires after parsing completes
    ///
    /// ## Example
    /// ```zig
    /// const html =
    ///     \\<html>
    ///     \\<body>
    ///     \\<div id="test">Hello</div>
    ///     \\<script>
    ///     \\  window.found = document.getElementById('test').textContent;
    ///     \\</script>
    ///     \\</body>
    ///     \\</html>
    /// ;
    /// try ctx.loadHTML(html, .{ .base_url = "about:blank" });
    /// const result = try ctx.evaluateScript("window.found");
    /// // result === "Hello"
    /// ```
    pub fn loadHTML(self: *Context, html_content: []const u8, options: LoadHTMLOptions) !void {
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        log.debug("loadHTML: Browser.Context v8_context={*}\n", .{v8_ctx});

        // Get runtime context for HTMLParser
        const runtime_ctx = context_manager.getOrCreate(v8_ctx, self.allocator) catch |err| {
            log.debug("Failed to get runtime context: {}\n", .{err});
            return error.NotInitialized;
        };

        log.debug("loadHTML: runtime_ctx engine_ctx={*}\n", .{runtime_ctx.getEngineContext()});

        // Set the document URL in context_manager for fetch relative URL resolution
        context_manager.setDocumentUrl(v8_ctx, options.base_url) catch |err| {
            log.debug("Warning: Failed to set document URL: {}\n", .{err});
        };

        // Update location object with the document's URL
        try self.setUrl(options.base_url);

        // Set the Window's origin from the base URL for storage access
        // This is needed for sessionStorage/localStorage to work properly
        if (self.window_instance) |win| {
            if (std.mem.startsWith(u8, options.base_url, "http://") or std.mem.startsWith(u8, options.base_url, "https://")) {
                // Extract origin from URL (scheme://host:port)
                const scheme_end = std.mem.indexOf(u8, options.base_url, "://") orelse options.base_url.len;
                const after_scheme = options.base_url[scheme_end + 3 ..];
                const path_start = std.mem.indexOf(u8, after_scheme, "/") orelse after_scheme.len;
                const origin = options.base_url[0 .. scheme_end + 3 + path_start];
                impls.Window.setOrigin(win, origin) catch |err| {
                    log.debug("Warning: Failed to set Window origin: {}\n", .{err});
                };
            }
        }

        // Get existing document instance - it was created during context initialization
        // and is already registered in V8. We pass it to the parser so scripts can
        // access the DOM via document.getElementById(), querySelector(), etc.
        const document = self.document_instance orelse {
            log.debug("ERROR: document_instance is null - context must be initialized first\n", .{});
            return error.NotInitialized;
        };

        // Create HTMLParser script loader
        const HTMLParser = impls.HTMLParser;
        const script_loader: ?HTMLParser.ScriptLoader = if (options.script_loader) |loader|
            HTMLParser.ScriptLoader{
                .context = loader.context,
                .loadScript = @ptrCast(loader.loadScript),
            }
        else
            null;

        // Parse HTML into the existing document (already registered in V8)
        _ = HTMLParser.parseHTMLWithScripting(
            self.allocator,
            runtime_ctx,
            html_content,
            .{
                .scripting_enabled = options.scripting_enabled,
                .base_url = options.base_url,
                .script_loader = script_loader,
                .existing_document = document,
            },
        ) catch |err| {
            log.debug("HTML parse error: {}\n", .{err});
            return error.ParseError;
        };

        // Initialize browsing contexts for any iframes in the document
        // This is necessary for window.frames[N] to work properly
        self.initializeIframeBrowsingContexts(document) catch |err| {
            // Non-fatal - some iframes may not need initialization
            log.debug("Warning: Failed to initialize iframe browsing contexts: {}\n", .{err});
        };

        // DOMContentLoaded and load (HTML §13.2.7 "the end" steps 6 and 9)
        // are the parser's: it queued them as tasks when parsing stopped, with
        // readiness and pageshow around them (dom.document_lifecycle). Firing
        // load here as well, synchronously, ran every load listener twice.
    }

    /// Initialize browsing contexts for all iframes in a document.
    /// This triggers lazy initialization of iframe browsing contexts by accessing
    /// their contentWindow property, which is required for window.frames[N] to work.
    fn initializeIframeBrowsingContexts(self: *Context, document: *runtime.Instance) !void {
        _ = self;

        // Get all iframe elements using getElementsByTagName
        const iframes = try interfaces.Document.call_getElementsByTagName(
            document,
            runtime.DOMString.initInterned("iframe"),
        );
        defer interfaces.HTMLCollection.deinit(iframes);

        // Get the collection length
        const length = try interfaces.HTMLCollection.get_length(iframes);
        if (length == 0) return;

        // Access contentWindow on each iframe to trigger browsing context initialization
        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const element = try interfaces.HTMLCollection.call_item(iframes, i);
            if (element) |iframe_elem| {
                // Access contentWindow to trigger IFrameIntegration.ensureBrowsingContext
                _ = impls.HTMLIFrameElement.get_contentWindow(iframe_elem) catch |err| {
                    log.debug("Warning: Failed to initialize iframe {d}: {}\n", .{ i, err });
                };
            }
        }
    }

    /// Set the context URL (updates location object)
    fn setUrl(self: *Context, url: []const u8) !void {
        // Update internal URL
        // IMPORTANT: Check if url points to self.url (same slice) to avoid use-after-free.
        // This can happen when loadHTML is called with base_url = self.url
        if (url.ptr == self.url.ptr) {
            // URL is already set to this value, nothing to do
            return;
        }
        // Duplicate first, then free old to avoid use-after-free if url somehow
        // references memory that would be affected by the free
        const new_url = try self.allocator.dupe(u8, url);
        self.allocator.free(self.url);
        self.url = new_url;

        // Note: Location object URL is set during context initialization
        // and via JavaScript. Direct impl access would require Location.setHref
        // which isn't currently exposed. For now, the URL is tracked in Context.url.
        _ = self.location_instance;
    }

    /// Evaluate JavaScript in this context
    /// Evaluate `script` for its effects, releasing the completion value.
    pub fn runScript(self: *Context, script: []const u8) !void {
        if (try self.evaluateScript(script)) |value| v8.ffi.v8_Value_Dispose(value);
    }

    /// Evaluate `script` and return its completion value, an owned handle the
    /// caller releases with `v8_Value_Dispose` - a leaked one that holds an
    /// object keeps the page alive. Use `runScript` to discard it.
    pub fn evaluateScript(self: *Context, script: []const u8) !?*v8.ffi.Value {
        const isolate = self.isolate;
        const v8_ctx = self.v8_context orelse return error.NotInitialized;

        // Debug: v8_ctx and script.len available if needed

        // Create V8 string from content
        const source_str = v8.ffi.v8_String_NewFromUtf8(isolate, script.ptr, @intCast(script.len)) orelse {
            return error.StringCreateFailed;
        };
        defer v8.ffi.v8_String_Dispose(source_str);

        // Compile script
        const compiled = v8.ffi.v8_Script_Compile(v8_ctx, source_str) orelse {
            const exception = v8.ffi.v8_TryCatch_Exception(v8_ctx);
            if (exception) |exc| {
                const exc_str = v8.ffi.v8_Value_ToString(exc, v8_ctx);
                if (exc_str) |str| {
                    const len = v8.ffi.v8_String_Utf8Length(str);
                    const buffer = self.allocator.alloc(u8, @intCast(len)) catch return error.CompileError;
                    defer self.allocator.free(buffer);
                    _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
                    log.debug("Script compile error: {s}\n", .{buffer});
                }
            }
            return error.CompileError;
        };

        // A bound script keeps its context alive, and the WPT runner evaluates
        // one per harness poll - hundreds a page - so leaking it kept every
        // page the runner ever loaded.
        defer v8.ffi.v8_Script_Dispose(compiled);

        // Run script using safe variant that properly captures exceptions
        const run_result = v8.ffi.v8_Script_Run_Safe(v8_ctx, compiled);
        defer v8.ffi.v8_FreeScriptRunResult(run_result);

        if (run_result.error_info) |err_info| {
            // At warn, not debug: evaluateScript runs host-injected code (the
            // WPT harness, its setup), never page scripts, so an exception here
            // is a runner-level failure - and the runner logs at warn, so a
            // debug line left it reported as a bare `error.RuntimeError`.
            log.warn("evaluateScript: script threw ({d} bytes of source)", .{script.len});
            if (err_info.message) |msg| {
                log.warn("Script runtime error: {s}", .{msg});
            }
            if (err_info.source_line) |line| {
                log.warn("  Source line: {s}", .{line});
            }
            if (err_info.resource_name) |name| {
                log.warn("  Resource: {s}:{d}:{d}", .{ name, err_info.line_number, err_info.column_number });
            }
            if (err_info.stack_trace) |stack| {
                log.warn("  Stack trace:\n{s}", .{stack});
            }
            return error.RuntimeError;
        }

        // Run microtasks
        v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

        return run_result.value;
    }

    /// Deinitialize the context
    ///
    /// This implements Chrome's context disposal sequence from LocalWindowProxy::DisposeContext:
    /// 1. Cancel all pending timers (prevents callbacks after disposal)
    /// 2. Clear singleton references
    /// 3. Remove from context manager (cleans up wrapper cache)
    /// 4. DetachGlobal() - break context/global link (Chrome pattern)
    /// 5. Exit context
    /// 6. ContextDisposedNotification() - hint GC (Chrome pattern)
    /// 7. Dispose context handle
    pub fn deinit(self: *Context) void {
        log.debug("\n[Context.deinit] === Destroying context ===\n", .{});
        log.debug("[Context.deinit] URL: {s}\n", .{self.url});
        log.debug("[Context.deinit] V8 Context: {?*}\n", .{self.v8_context});

        // Clean up threadlocal state that accumulates across context navigations.
        // These must be cleaned up to prevent state accumulation that causes
        // timeouts in sequential test execution.

        // Clean up custom elements threadlocal state (reactions_stack, element_reaction_queues)
        custom_elements.deinitThreadLocalState();

        // Clean up mutation observer threadlocal state (global_agent)
        mutation_observer_algorithms.resetAgent();

        // Clear instance lifecycle registry entries
        // (the registry itself persists but entries for this context's instances should be cleaned)
        instance_lifecycle.clearAll();

        // Clear timer interface and cancel all pending timers
        // This must happen before context manager deinit to prevent callbacks
        // from firing after the V8 context is disposed
        clearTimerInterface();

        // Clear iframe src load hook to prevent callbacks after context disposal
        impls.HTMLIFrameElement.setIframeSrcLoadHook(null);

        // NOTE: Do NOT explicitly deinit singleton instances here!
        // The context_manager.deinit() below cleans up the wrapper cache,
        // which calls gc.onObjectFreed() for each instance. If we deinit
        // instances here AND the wrapper cache also deinits them, we get
        // double-free crashes. Let the wrapper cache handle all cleanup.
        self.document_instance = null;
        self.navigator_instance = null;
        self.location_instance = null;
        self.history_instance = null;
        self.performance_instance = null;

        // Remove this context from the context manager (cleans up wrapper cache for this context)
        // NOTE: Use removeContext() instead of deinit() - deinit() destroys the entire
        // context manager which causes memory leaks when navigating between pages.
        // The context manager should persist across navigations; only individual contexts
        // should be removed.
        if (self.v8_context) |ctx| {
            context_manager.removeContext(ctx);

            // Chrome-style context disposal sequence:
            // Per Chrome's LocalWindowProxy::DisposeContext, we must:
            // 1. Detach global to break the context/global proxy link
            // 2. Exit the context
            // 3. Notify V8 that a context was disposed (helps GC)
            // 4. Release the persistent handle

            // Step 1: Detach global object from context
            // This breaks the link between the context and its global proxy,
            // preventing JavaScript from accessing the context's global scope
            v8.ffi.v8_Context_DetachGlobal(ctx);

            // Step 2: Exit context
            v8.ffi.v8_Context_Exit(ctx);

            // Step 3: Notify V8 that a context has been disposed
            // This hints to V8's garbage collector that context-associated objects
            // can be collected more eagerly. force_gc=true for aggressive cleanup
            // which is needed for sequential test execution.
            _ = v8.ffi.v8_Isolate_ContextDisposedNotification(self.isolate, true);

            // Step 4: Dispose the persistent context handle
            v8.ffi.v8_Context_Dispose(ctx);
        }

        self.allocator.free(self.url);
        self.initialized = false;
    }
};

// ============================================================================
// V8 Callback Implementations
// ============================================================================

/// setTimeout callback - schedules callback to run after delay using TimerManager
/// Schedule the single next-frame timer, if callbacks are waiting and none is
/// already pending. One timer per FRAME, never one per callback.
fn scheduleAnimationFrame() void {
    const state = if (animation_frames) |*s| s else return;
    if (state.timer_id != null) return;
    if (state.pending.items.len == 0) return;
    const timer = getTimerInterface() orelse return;
    const id = timer.setTimeout(FRAME_INTERVAL_MS, animationFrameHandler, null);
    // 0 is the failure sentinel; leaving timer_id null lets a later rAF retry.
    if (id != 0) state.timer_id = id;
}

/// Run one frame: the whole pending batch, in registration order, sharing one
/// timestamp.
fn animationFrameHandler(_: ?*anyopaque) void {
    const state = if (animation_frames) |*s| s else return;
    const allocator = current_allocator orelse return;

    // This timer has fired, so the slot is free for the next frame.
    state.timer_id = null;

    // TAKE the batch. Callbacks registered while it runs land in a fresh list
    // and run on a later frame, which the spec requires.
    var batch = state.pending;
    state.pending = .empty;
    defer batch.deinit(allocator);

    if (batch.items.len == 0) return;

    // Visible to cancelAnimationFrame while the batch runs.
    state.running = batch.items;
    defer if (animation_frames) |*s| {
        s.running = &.{};
    };

    const isolate = state.isolate;

    v8.isolate_ownership.assertOwned(isolate, "Context.animationFrameHandler");

    // Frame callbacks fire from the event loop: V8 has opened no HandleScope
    // and entered no context for them.
    const scope = v8.ffi.v8_HandleScope_New(isolate) orelse return;
    defer v8.ffi.v8_HandleScope_Dispose(scope);

    // ONE timestamp for the whole frame.
    const elapsed = clock.monotonicMillis() - animation_frame_origin_ms;
    const timestamp: f64 = @floatFromInt(if (elapsed < 0) 0 else elapsed);

    // v8_Number_New returns a Global<Number>* and the CALLER owns it.
    const ts_global = v8.ffi.v8_Number_New(isolate, timestamp);
    defer v8.ffi.v8_Global_Dispose(@ptrCast(ts_global));

    // BY POINTER, not by value. cancelAnimationFrame called from inside one of
    // these callbacks writes `cancelled` through `state.running`, which aliases
    // this same array - a by-value loop variable is a snapshot taken before that
    // write is read back, and the sibling runs anyway.
    for (batch.items) |*entry| {
        // This frame is the end of the entry's life either way, so its callback
        // Global is disposed whether it ran or was cancelled.
        defer entry.deinit();
        if (entry.cancelled) continue;
        runAnimationFrameCallback(entry, @ptrCast(ts_global));
    }

    v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

    // A callback may have asked for another frame.
    scheduleAnimationFrame();
}

/// Invoke one animation frame callback in the realm that registered it.
fn runAnimationFrameCallback(entry: *const AnimationFrameEntry, timestamp: *v8.ffi.Value) void {
    v8.ffi.v8_Context_Enter(entry.context);
    defer v8.ffi.v8_Context_Exit(entry.context);

    // v8_Context_Global allocates a Global<Object> the caller owns.
    const global = v8.ffi.v8_Context_Global(entry.context) orelse return;
    defer v8.ffi.v8_Global_Dispose(@ptrCast(global));

    invokeReporting(entry.context, entry.callback_fn, global, &.{timestamp});
}

/// requestAnimationFrame(callback) - HTML "animation frames", step 2 onwards.
fn requestAnimationFrameCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // A missing or non-callable argument is a TypeError per WebIDL, but the rest
    // of this file reports argument problems by returning the 0 sentinel rather
    // than throwing, and a lone thrower here would be the odd one out.
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        setIntegerReturn(info, isolate, 0);
        return;
    }

    // OWNED from here: every early return below must dispose it, and on success
    // ownership passes to the pending entry.
    const callback_value = info.get(0);
    if (!v8.ffi.v8_Value_IsFunction(callback_value)) {
        v8.ffi.v8_Global_Dispose(callback_value);
        setIntegerReturn(info, isolate, 0);
        return;
    }

    const allocator = current_allocator orelse {
        v8.ffi.v8_Global_Dispose(callback_value);
        setIntegerReturn(info, isolate, 0);
        return;
    };

    // The function's realm: this window's map of animation frame callbacks.
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        v8.ffi.v8_Global_Dispose(callback_value);
        setIntegerReturn(info, isolate, 0);
        return;
    };

    if (animation_frames == null) animation_frames = .{ .isolate = isolate };
    const state = &animation_frames.?;

    const handle = state.next_handle;
    state.pending.append(allocator, .{
        .handle = handle,
        .callback_fn = @ptrCast(callback_value),
        .context = context,
    }) catch {
        v8.ffi.v8_Global_Dispose(callback_value);
        v8.ffi.v8_Global_Dispose(@ptrCast(context));
        setIntegerReturn(info, isolate, 0);
        return;
    };
    state.next_handle += 1;

    scheduleAnimationFrame();

    setIntegerReturn(info, isolate, @intCast(handle));
}

/// `v8_Integer_New` allocates a Global and `SetReturnValue` only reads it into a
/// Local, so the caller still owns it. Wrapped because rAF has six return paths
/// and an undisposed one on each is how the 14,774 leaked `v8_Number_New`
/// handles in a single timers file got there.
fn setIntegerReturn(info: *const v8.ffi.FunctionCallbackInfo, isolate: *v8.ffi.Isolate, value: i32) void {
    const boxed = v8.ffi.v8_Integer_New(isolate, value);
    defer v8.ffi.v8_Global_Dispose(@ptrCast(boxed));
    info.setReturnValue(@ptrCast(boxed));
}

/// cancelAnimationFrame(handle). An unknown handle must do nothing.
fn cancelAnimationFrameCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (info.v8_FunctionCallbackInfo_Length() < 1) return;

    const state = if (animation_frames) |*s| s else return;

    const handle_value = info.get(0);
    defer v8.ffi.v8_Global_Dispose(handle_value);
    if (!v8.ffi.v8_Value_IsNumber(handle_value)) return;
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.ffi.v8_Global_Dispose(@ptrCast(context));
    const as_f64 = v8.ffi.v8_Value_NumberValue(handle_value, context);
    if (std.math.isNan(as_f64) or as_f64 < 1 or as_f64 > @as(f64, @floatFromInt(std.math.maxInt(u32)))) return;
    const handle: u32 = @intFromFloat(as_f64);

    // Mark rather than remove: the batch may already be running, and removing
    // from under the loop in animationFrameHandler would shift its indices.
    // The frame in progress first: a callback cancelling a sibling registered
    // for the same frame is the case `pending` alone cannot answer.
    //
    // A handle names a callback in THIS window's map only, so another
    // window's callback with that handle is not cancelled.
    for (state.running) |*entry| {
        if (entry.handle == handle and sameContext(entry.context, context)) {
            entry.cancelled = true;
            return;
        }
    }
    for (state.pending.items) |*entry| {
        if (entry.handle == handle and sameContext(entry.context, context)) {
            entry.cancelled = true;
            return;
        }
    }
}

/// setTimeout(handler, timeout, ...arguments)
fn setTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    timerInitializationFromCall(info, false);
}

/// clearTimeout(id) and clearInterval(id): one algorithm, "clear the timer
/// with id from the map of setTimeout and setInterval IDs", so either clears
/// either kind.
fn clearTimeoutCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    if (info.v8_FunctionCallbackInfo_Length() < 1) return;

    const id_value = info.get(0);
    defer v8.ffi.v8_Global_Dispose(id_value);
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.ffi.v8_Context_Dispose(context);

    // `optional long id = 0`: ToInt32, like the timeout - so "5" is 5, and
    // a throwing valueOf propagates.
    var id: i32 = 0;
    if (!v8.ffi.v8_Value_ToInt32(id_value, context, &id)) return;
    if (id <= 0) return;

    // The map, and nothing but the map, decides what an id names - and it is
    // THIS window's map: an id another window's timer holds names nothing
    // here. The function's realm is the window whose method this is.
    const map = if (timer_contexts) |*m| m else return;
    const wrapper = map.get(@intCast(id)) orelse return;
    if (!sameContext(wrapper.getData().v8_context, context)) return;
    unregisterTimerContext(@intCast(id));
}

/// setInterval(handler, timeout, ...arguments)
fn setIntervalCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    timerInitializationFromCall(info, true);
}

/// The binding of `long setTimeout(TimerHandler handler, optional long
/// timeout = 0, any... arguments)` and of setInterval: WebIDL argument
/// conversion, then the timer initialization steps.
///
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#timer-initialisation-steps
fn timerInitializationFromCall(info: *const v8.ffi.FunctionCallbackInfo, repeat: bool) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();
    const argc: usize = @intCast(@max(info.v8_FunctionCallbackInfo_Length(), 0));

    // `handler` is required: WebIDL throws a TypeError for a call without it.
    if (argc < 1) {
        return throwTypeError(isolate, info, if (repeat)
            "Failed to execute 'setInterval' on 'Window': 1 argument required, but only 0 present."
        else
            "Failed to execute 'setTimeout' on 'Window': 1 argument required, but only 0 present.");
    }

    // OWNED - handed to the timer below, disposed on every other way out.
    const context = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    var context_owned = true;
    defer if (context_owned) v8.ffi.v8_Context_Dispose(context);

    // TimerHandler is (TrustedScript or DOMString or Function). A callable
    // value is the Function member; anything else is converted by ToString
    // HERE, at the call - which runs script (evil-spec-example.any.js has a
    // toString() that itself calls setTimeout) and can throw. A null from
    // ToString means it threw: the exception is pending, and returning now
    // rethrows it to the caller.
    const handler_value = info.get(0);
    const handler: TimerHandler = if (v8.ffi.v8_Value_IsFunction(handler_value))
        .{ .function = @ptrCast(handler_value) }
    else blk: {
        defer v8.ffi.v8_Global_Dispose(handler_value);
        break :blk .{ .string = v8.ffi.v8_Value_ToString(handler_value, context) orelse return };
    };
    var handler_owned = true;
    defer if (handler_owned) handler.dispose();

    // `optional long timeout = 0` is ToInt32: ToNumber - script again, and
    // it can throw - then modulo 2^32, so 2**32 is 0 rather than 49 days.
    var timeout: i32 = 0;
    if (argc >= 2) {
        const timeout_value = info.get(1);
        defer v8.ffi.v8_Global_Dispose(timeout_value);
        if (!v8.ffi.v8_Value_IsUndefined(timeout_value) and
            !v8.ffi.v8_Value_ToInt32(timeout_value, context, &timeout)) return;
    }

    const timer = getTimerInterface() orelse return setIntegerReturn(info, isolate, 0);
    const allocator = current_allocator orelse return setIntegerReturn(info, isolate, 0);

    // `any... arguments`, for every run of a Function handler.
    const arguments = allocator.alloc(*v8.ffi.Value, argc -| 2) catch return setIntegerReturn(info, isolate, 0);
    for (arguments, 2..) |*argument, i| argument.* = info.get(@intCast(i));
    var arguments_owned = true;
    defer if (arguments_owned) {
        for (arguments) |argument| v8.ffi.v8_Global_Dispose(argument);
        allocator.free(arguments);
    };

    // Step 3: this timer's nesting level is one deeper than the running
    // task's, if that task is a timer's; 0 otherwise.
    const nesting = v8.native_timer.nesting_level;
    // Step 4: a negative timeout is 0.
    const timeout_ms: i64 = @max(timeout, 0);

    const wrapper = V8TimerCallback.create(allocator, if (repeat) &v8IntervalHandler else &v8TimerHandler, .{
        .handler = handler,
        .arguments = arguments,
        .isolate = isolate,
        .v8_context = context,
        .is_interval = repeat,
        .timeout_ms = timeout_ms,
        // Steps 9-10.
        .nesting_level = nesting + 1,
    }) catch return setIntegerReturn(info, isolate, 0);
    // The wrapper owns them now; destroyTimer releases them.
    context_owned = false;
    handler_owned = false;
    arguments_owned = false;

    // Step 5: the 4ms clamp past nesting level 5. Steps 11-14: schedule, and
    // return the id.
    const delay: u64 = @intCast(clampTimeout(timeout_ms, nesting));
    const id = scheduleTimer(timer, wrapper, delay) orelse return setIntegerReturn(info, isolate, 0);
    setIntegerReturn(info, isolate, @intCast(@as(u32, @truncate(id))));
}

/// addEventListener callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
fn addEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Return undefined by default
    const return_undefined = v8.ffi.v8_Undefined(isolate) orelse return;
    info.setReturnValue(return_undefined);

    // Get V8 context. Owned: once the listener's wrapper exists it owns the
    // handle (its `callback_context`, also the runtime wrapper's `engine_ctx`)
    // and releases it when the listener goes; until then every path releases
    // it here. Each one leaked kept the page's whole native context alive.
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    var listener_keeps_ctx = false;
    defer if (!listener_keeps_ctx) v8.ffi.v8_Context_Dispose(v8_ctx);

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse return;
    defer v8.ffi.v8_Object_Dispose(global);

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return;
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // `type` and `callback` are required.
    if (info.v8_FunctionCallbackInfo_Length() < 2) {
        return throwTypeError(isolate, info, "Failed to execute 'addEventListener' on 'EventTarget': 2 arguments required.");
    }

    const allocator = std.heap.page_allocator;
    var event_type = listenerType(isolate, info, v8_ctx, allocator) orelse return;
    defer event_type.deinit(allocator);
    var options = listenerOptions(info, isolate, v8_ctx, allocator);
    defer options.deinit(allocator);

    // Get callback argument (second arg)
    const callback_arg = info.v8_FunctionCallbackInfo_GetArgument(1);
    if (v8.ffi.v8_Value_IsNullOrUndefined(@ptrCast(callback_arg))) {
        v8.ffi.v8_Global_Dispose(@ptrCast(callback_arg));
        return;
    }

    // Create V8 CallbackWrapper from the callback value
    const v8_wrapper = v8.callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        v8_ctx,
        @ptrCast(callback_arg),
        "handleEvent",
    ) catch return orelse return;
    v8_wrapper.owns_callback_context = true;
    listener_keeps_ctx = true;

    // Create runtime.CallbackWrapper that wraps the V8 callback
    // (per conversions.zig pattern for proper engine interface setup)
    const runtime_wrapper = allocator.create(runtime.CallbackWrapper) catch {
        v8_wrapper.deinit();
        return;
    };
    runtime_wrapper.* = .{
        .engine_handle = v8_wrapper,
        .engine = &v8.v8_engine_interface,
        .engine_ctx = v8_ctx,
        .allocator = allocator,
    };

    // Call the EventTarget implementation with double-optional callback
    const EventTargetImpl = impls.EventTarget;
    EventTargetImpl.call_addEventListener(
        window_instance,
        event_type,
        @as(?*runtime.CallbackWrapper, runtime_wrapper),
        options.argument(),
    ) catch |err| {
        log.debug("[addEventListener] Error: {}\n", .{err});
        runtime_wrapper.deinit();
        allocator.destroy(runtime_wrapper);
    };
}

/// `DOMString type`, the first argument of add- and removeEventListener:
/// ToString, so `null` is the type "null" and "" is a type like any other.
/// Null when the conversion threw - a Symbol, or a toString() that throws -
/// with the exception pending.
fn listenerType(isolate: *v8.ffi.Isolate, info: *const v8.ffi.FunctionCallbackInfo, v8_ctx: *v8.ffi.Context, allocator: std.mem.Allocator) ?runtime.DOMString {
    const arg = info.get(0);
    defer v8.ffi.v8_Global_Dispose(arg);
    return v8.conversions.fromV8Value(runtime.DOMString, allocator, isolate, v8_ctx, arg) catch |err| {
        if (err != error.ExceptionPending) throwTypeError(isolate, info, "Failed to convert the event type to a string.");
        return null;
    };
}

/// The third argument of add- and removeEventListener: `options`, a boolean
/// (capture) or a dictionary, for EventTarget to flatten as the WebIDL
/// binding would hand it over. Owns the argument's handle, which EventTarget
/// only reads during the call.
const ListenerOptions = struct {
    handle: ?*v8.ffi.Value = null,
    value: ?runtime.JSValue = null,

    fn argument(self: *const ListenerOptions) webidl.Opt(runtime.JSValue) {
        return if (self.value) |v| webidl.Opt(runtime.JSValue).passed(v) else webidl.Opt(runtime.JSValue).notPassed();
    }

    fn deinit(self: *ListenerOptions, allocator: std.mem.Allocator) void {
        if (self.value) |*v| v.deinit(allocator);
        if (self.handle) |h| v8.ffi.v8_Global_Dispose(h);
    }
};

fn listenerOptions(info: *const v8.ffi.FunctionCallbackInfo, isolate: *v8.ffi.Isolate, v8_ctx: *v8.ffi.Context, allocator: std.mem.Allocator) ListenerOptions {
    if (info.v8_FunctionCallbackInfo_Length() < 3) return .{};
    const handle = info.get(2);
    const value = v8.conversions.fromV8Value(runtime.JSValue, allocator, isolate, v8_ctx, handle) catch null;
    return .{ .handle = handle, .value = value };
}

/// removeEventListener callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
fn removeEventListenerCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Return undefined by default
    const return_undefined = v8.ffi.v8_Undefined(isolate) orelse return;
    info.setReturnValue(return_undefined);

    // Get V8 context. Owned, and nothing keeps it: the wrapper built below
    // exists only to compare against, and removeEventListener frees it.
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.ffi.v8_Context_Dispose(v8_ctx);

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse return;
    defer v8.ffi.v8_Object_Dispose(global);

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return;
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // `type` and `callback` are required.
    if (info.v8_FunctionCallbackInfo_Length() < 2) {
        return throwTypeError(isolate, info, "Failed to execute 'removeEventListener' on 'EventTarget': 2 arguments required.");
    }

    const allocator = std.heap.page_allocator;
    var event_type = listenerType(isolate, info, v8_ctx, allocator) orelse return;
    defer event_type.deinit(allocator);
    var options = listenerOptions(info, isolate, v8_ctx, allocator);
    defer options.deinit(allocator);

    // Get callback argument (second arg)
    const callback_arg = info.v8_FunctionCallbackInfo_GetArgument(1);
    if (v8.ffi.v8_Value_IsNullOrUndefined(@ptrCast(callback_arg))) {
        v8.ffi.v8_Global_Dispose(@ptrCast(callback_arg));
        return;
    }

    // Create V8 CallbackWrapper from the callback value for comparison
    const v8_wrapper = v8.callback_wrapper_mod.createFromV8Value(
        allocator,
        isolate,
        v8_ctx,
        @ptrCast(callback_arg),
        "handleEvent",
    ) catch return orelse return;

    // Create runtime.CallbackWrapper that wraps the V8 callback
    const runtime_wrapper = allocator.create(runtime.CallbackWrapper) catch {
        v8_wrapper.deinit();
        return;
    };
    runtime_wrapper.* = .{
        .engine_handle = v8_wrapper,
        .engine = &v8.v8_engine_interface,
        .engine_ctx = v8_ctx,
        .allocator = allocator,
    };

    // Call the EventTarget implementation with double-optional callback
    const EventTargetImpl = impls.EventTarget;
    EventTargetImpl.call_removeEventListener(
        window_instance,
        event_type,
        @as(?*runtime.CallbackWrapper, runtime_wrapper),
        options.argument(),
    ) catch |err| {
        log.debug("[removeEventListener] Error: {}\n", .{err});
    };
    // Note: removeEventListener cleans up its own callback wrapper via deinit
}

/// dispatchEvent callback - delegates to EventTarget WebIDL implementation
/// Per DOM spec: https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
fn dispatchEventCallback(info: *const v8.ffi.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.v8_FunctionCallbackInfo_GetIsolate();

    // Get V8 context
    const v8_ctx = v8.ffi.v8_Isolate_GetCurrentContext(isolate) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Get global object (which has the window instance)
    const global = v8.ffi.v8_Context_Global(v8_ctx) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };

    // Get window instance from internal field 0
    const window_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const window_instance: *runtime.Instance = @ptrCast(@alignCast(window_ptr));

    // Need at least event argument
    if (info.v8_FunctionCallbackInfo_Length() < 1) {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    }

    // Get event argument (first arg)
    const event_arg = info.v8_FunctionCallbackInfo_GetArgument(0);
    if (!v8.ffi.v8_Value_IsObject(@ptrCast(event_arg))) {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    }

    // Get Event instance from internal field 0
    const event_obj: *v8.ffi.Object = @ptrCast(event_arg);
    const event_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(event_obj, 0) orelse {
        if (v8.ffi.v8_Boolean_New(isolate, true)) |result| {
            info.setReturnValue(result);
        }
        return;
    };
    const event_instance: *runtime.Instance = @ptrCast(@alignCast(event_ptr));

    // Call the EventTarget implementation
    const EventTargetImpl = impls.EventTarget;
    const result = EventTargetImpl.call_dispatchEvent(window_instance, event_instance) catch {
        if (v8.ffi.v8_Boolean_New(isolate, false)) |res| {
            info.setReturnValue(res);
        }
        return;
    };

    // Return result
    if (v8.ffi.v8_Boolean_New(isolate, result)) |res| {
        info.setReturnValue(res);
    }
}

/// Helper to throw TypeError
fn throwTypeError(isolate: *v8.ffi.Isolate, info: *const v8.ffi.FunctionCallbackInfo, msg: []const u8) void {
    _ = info;
    // Both are owned Globals; ThrowException takes its own reference.
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, msg.ptr, @intCast(msg.len)) orelse return;
    defer v8.ffi.v8_String_Dispose(error_msg);
    const error_val = v8.ffi.v8_Exception_TypeError(@ptrCast(error_msg)) orelse return;
    defer v8.ffi.v8_Global_Dispose(error_val);
    v8.ffi.v8_Isolate_ThrowException(isolate, error_val);
}

/// Helper to reject a promise with TypeError
fn rejectWithTypeError(isolate: *v8.ffi.Isolate, v8_ctx: *v8.ffi.Context, resolver: *v8.ffi.PromiseResolver, msg: []const u8) void {
    const error_msg = v8.ffi.v8_String_NewFromUtf8(isolate, msg.ptr, @intCast(msg.len)) orelse return;
    const error_val = v8.ffi.v8_Exception_TypeError(@ptrCast(error_msg)) orelse return;
    _ = v8.ffi.v8_PromiseResolver_Reject(resolver, v8_ctx, error_val);
}
