//! Implementation for WindowOrWorkerGlobalScope interface

const std = @import("std");
const runtime = @import("runtime");
const html_core = @import("html_core");
const global_settings = @import("dom").global_settings;
const streams_js = @import("streams_js.zig");
const same_object = @import("same_object.zig");
const fetch_body = @import("fetch_body.zig");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const WindowOrWorkerGlobalScope = interfaces.WindowOrWorkerGlobalScope;

pub const State = WindowOrWorkerGlobalScope.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // TODO: Clean up your instance resources here
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// Getter for origin
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    // "return this's relevant settings object's origin, serialized."
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    return settings.origin(instance);
}

/// Getter for isSecureContext
pub fn get_isSecureContext(instance: *runtime.Instance) anyerror!bool {
    // "return true if this's relevant settings object is a secure context"
    const settings = global_settings.of(instance) orelse return false;
    return settings.is_secure_context(instance);
}

/// Getter for crossOriginIsolated
pub fn get_crossOriginIsolated(instance: *runtime.Instance) anyerror!bool {
    // "return this's relevant settings object's cross-origin isolated
    // capability."
    const settings = global_settings.of(instance) orelse return false;
    return settings.cross_origin_isolated(instance);
}

/// Getter for indexedDB
pub fn get_indexedDB(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const indexed_db = settings.indexed_db orelse return error.NotImplemented;
    return indexed_db(instance);
}

/// Getter for trustedTypes
pub fn get_trustedTypes(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for performance
pub fn get_performance(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const performance = settings.performance orelse return error.NotImplemented;
    return performance(instance);
}

/// Getter for caches
pub fn get_caches(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const settings = global_settings.of(instance) orelse return error.InvalidStateError;
    const caches = settings.caches orelse return error.NotImplemented;
    return caches(instance);
}

/// Getter for scheduler
pub fn get_scheduler(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Getter for crypto
pub fn get_crypto(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented;
}

/// Operation: reportError
pub fn call_reportError(instance: *runtime.Instance, e: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = e;
    return error.NotImplemented;
}

/// Operation: setInterval
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-setinterval
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in interval registry with Global handle
/// 3. Dispose Global handle when interval is cleared via clearInterval
/// 4. Handle repeating invocation pattern
pub fn call_setInterval(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: atob
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-atob
pub fn call_atob(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.ByteString {
    // Freed by the binding.
    return html_core.base64_utility.atob(instance.ctx.allocator, data.asSlice());
}

/// Operation: btoa
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#dom-btoa
pub fn call_btoa(instance: *runtime.Instance, data: runtime.DOMString) anyerror!runtime.DOMString {
    // Freed by the binding.
    return runtime.DOMString.initOwned(try html_core.base64_utility.btoa(instance.ctx.allocator, data.asSlice()));
}

/// Operation: createImageBitmap
pub fn call_createImageBitmap(instance: *runtime.Instance, image: typedefs.ImageBitmapSource, options: webidl.Opt(dictionaries.ImageBitmapOptions)) anyerror!runtime.JSValue {
    _ = instance;
    _ = image;
    _ = options;
    return error.NotImplemented;
}

/// Operation: clearInterval
pub fn call_clearInterval(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: queueMicrotask
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-queuemicrotask
///
/// "Queue a microtask to invoke callback with « » and "report"."
pub fn call_queueMicrotask(instance: *runtime.Instance, callback: callbacks.VoidFunction) anyerror!void {
    // The binding hands the callback over: take it before anything can fail.
    const function = engine.takeCallbackFunction(@ptrCast(callback));
    const task = instance.ctx.allocator.create(Microtask) catch {
        function.release();
        return error.OutOfMemory;
    };
    task.* = .{ .callback = function, .realm = instance.ctx, .allocator = instance.ctx.allocator };
    engine.queueMicrotask(instance.ctx, Microtask.run, task) catch |err| {
        task.deinit();
        return err;
    };
}

/// A queueMicrotask() callback waiting for its microtask. A realm torn down
/// meanwhile runs nothing: invoking a callback in it fails, and the task is
/// let go.
const Microtask = struct {
    /// OWNED.
    callback: engine.CallbackFunction,
    realm: runtime.Context,
    allocator: std.mem.Allocator,

    fn run(data: ?*anyopaque) void {
        const self: *Microtask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        const completion = engine.invokeCallbackFunction(self.realm, &self.callback, .undefined, &.{}, .{
            .report = .{ .report = reportException, .host = self.realm },
        }) catch return;
        switch (completion) {
            inline else => |value| value.release(),
        }
    }

    fn deinit(self: *Microtask) void {
        self.callback.release();
        self.allocator.destroy(self);
    }
};

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's associated realm - or else the queueing global's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const queued_in: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse queued_in;
    const record = realm.getRealm() orelse return;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
    const extracted: runtime.ErrorInfo = .{
        .message = info.message,
        .filename = info.filename,
        .lineno = info.lineno,
        .colno = info.colno,
        .error_value = if (info.error_value == .undefined) null else info.error_value,
    };
    _ = @import("html").report_exception.reportErrorInfo(global, &extracted, .{});
}

/// Operation: structuredClone
/// Spec: https://html.spec.whatwg.org/multipage/structured-data.html#dom-structuredclone
///
/// 1. Let serialized be ? StructuredSerializeWithTransfer(value,
///    options["transfer"]).
/// 2. Let deserializeRecord be ? StructuredDeserializeWithTransfer(
///    serialized, this's relevant realm).
/// 3. Return deserializeRecord.[[Deserialized]].
///
/// Deviation: a platform object in the transfer list (a MessagePort) is a
/// DataCloneError here - its transfer steps are MessagePort's, which
/// postMessage runs and structuredClone does not yet.
pub fn call_structuredClone(instance: *runtime.Instance, value: runtime.JSValue, options: webidl.Opt(dictionaries.StructuredSerializeOptions)) anyerror!runtime.JSValue {
    const allocator = instance.ctx.allocator;
    const transfer: []const runtime.JSValue = if (options.was_passed) (options.value.transfer orelse &.{}) else &.{};
    // Step 1.
    var serialized = try engine.structuredSerializeWithTransfer(instance.ctx, value, transfer, notTransferable, null, allocator);
    defer serialized.deinit(allocator);
    // Steps 2-3.
    const deserialized = try engine.structuredDeserializeWithTransfer(instance.ctx, serialized.serialized, serialized.array_buffers);
    return deserialized.take();
}

/// structuredClone transfers no platform object (see its deviation).
fn notTransferable(_: ?*anyopaque, _: *runtime.Instance) runtime.TransferableState {
    return .not_transferable;
}

/// Operation: setTimeout
/// Spec: https://html.spec.whatwg.org/multipage/timers-and-user-prompts.html#dom-settimeout
///
/// TODO: When implementing, the handler MUST be stored as a V8 Global handle
/// if handler.function is a JavaScript callback. See:
/// - tmp/analysis/CALLBACK_STORAGE.md for the pattern
/// - src/webidl/impls/WebSocket.zig for example usage of OptionalGlobalHandle
///
/// Implementation requirements:
/// 1. For handler.function variant, create Global handle
/// 2. Store in timer registry with Global handle
/// 3. Dispose Global handle when timer fires or is cleared via clearTimeout
/// 4. Handle one-shot invocation (unlike setInterval)
pub fn call_setTimeout(instance: *runtime.Instance, handler: typedefs.TimerHandler, timeout: webidl.Opt(i32), arguments: []const runtime.JSValue) anyerror!i32 {
    _ = instance;
    _ = handler;
    _ = timeout;
    _ = arguments;
    return error.NotImplemented;
}

/// Operation: clearTimeout
pub fn call_clearTimeout(instance: *runtime.Instance, id: webidl.Opt(i32)) anyerror!void {
    _ = instance;
    _ = id;
    return error.NotImplemented;
}

/// Operation: fetch
///
/// The fetch runs on the event loop (`fetch.algorithms.AsyncFetch`): this
/// returns p at once, and the fetch task that settles it runs on a later turn.
/// It used to run the whole fetch inside this call, blocked in
/// `curl_easy_perform`, and everything on the thread waited with it.
pub fn call_fetch(instance: *runtime.Instance, input: typedefs.RequestInfo, init_data: webidl.Opt(dictionaries.RequestInit)) anyerror!runtime.JSValue {
    const fetch = @import("fetch");
    const fetch_objects = @import("dom").fetch_objects;
    const abort_algorithms = @import("dom").abort_algorithms;
    const allocator = instance.ctx.allocator;

    // One call, from the moment the fetch starts until it is entirely over:
    // the fetch's client, the task that settles p, and the abort steps on
    // requestObject's signal - which outlive p's settling, since the body is
    // still arriving and an abort then errors it.
    //
    // Two things hold it, each letting go once: the fetch, until it is over
    // (`finished`), gone (`gone`) or aborted; and the settle task, from
    // `done` until it runs (or its `drop`). The last to let go frees it.
    const Call = struct {
        allocator: std.mem.Allocator,
        /// The relevant realm's runtime context. A page that ends RETIRES its
        /// context rather than freeing it, and empties it - `engine_ctx`
        /// becomes null - which is how `alive` tells that the realm is gone.
        ctx: runtime.Context,
        /// p's capability, this call's until p is settled or its realm is
        /// gone. Keeping it keeps p, and so the realm, alive while the fetch
        /// is in flight.
        capability: engine.PromiseCapability,
        outcome: ?(fetch.algorithms.FetchError!fetch.algorithms.FetchResult) = null,
        /// The fetch, from start until it ends (`done` or `gone`) or is
        /// aborted.
        in_flight: ?*fetch.algorithms.AsyncFetch = null,
        /// requestObject's signal while this call's abort steps are on it,
        /// as (address, slab generation).
        signal: ?*runtime.Instance = null,
        signal_generation: u64 = 0,
        /// Keeps that signal alive for as long as this call. requestObject
        /// goes when fetch() returns, and with it its own pin, but DOM
        /// § 3.3.1: a signal with source signals and abort algorithms must
        /// not be collected - `controller.abort()` reaches the abort steps
        /// through it. The generation check stays for a pin that could not
        /// be taken (no isolate).
        signal_pin: same_object.Pin = .{},
        /// Step 9's locallyAborted.
        locally_aborted: bool = false,
        /// p is settled (or never will be), and its resolver released.
        settled: bool = false,
        /// The fetch holds this call, until it lets go.
        fetch_holds: bool = true,
        /// A settle task holds this call, until it runs.
        task_holds: bool = false,
        /// While requestObject's body is read from its stream to be sent:
        /// the read, and the request waiting for its bytes. The fetch
        /// starts once they are all read (`uploadRead`). Until then the
        /// read stands for the fetch in `fetch_holds`.
        upload: ?*fetch_body.ReadAll = null,
        pending_request: ?*fetch.internal.InternalRequest = null,

        const Self = @This();

        fn client(self: *Self) fetch.algorithms.AsyncFetch.Client {
            return .{ .context = self, .done = done, .alive = alive, .gone = gone, .finished = finished };
        }

        fn alive(context: *anyopaque) bool {
            const self: *Self = @ptrCast(@alignCast(context));
            return self.ctx.engine_ctx != null;
        }

        /// The realm went away with the fetch in flight; the fetch has been
        /// terminated. Nothing is left to settle.
        fn gone(context: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.in_flight = null;
            self.fetch_holds = false;
            self.maybeRelease();
        }

        /// The fetch is over - its body ended, or nobody read it - after p
        /// was settled. An abort now has nothing to abort.
        fn finished(context: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.in_flight = null;
            self.fetch_holds = false;
            self.maybeRelease();
        }

        /// Fetch has its response: queue the fetch task that runs
        /// processResponse (step 12) - a global task on the networking task
        /// source, given relevantRealm's global object. A window's realm has
        /// an event loop. A worker's has none of its own and runs its tasks
        /// as timers on the page's, so its task is one; a realm with neither
        /// is in the event loop's network step already, a task boundary, and
        /// settles now.
        fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
            const self: *Self = @ptrCast(@alignCast(context));
            // The fetch is still this call's: its body is arriving, and the
            // abort steps can still end it.
            self.outcome = outcome;
            self.task_holds = true;
            if (self.ctx.getOptionalEventLoop()) |loop| {
                loop.queueTask(.{ .callback = settle, .context = self, .drop = drop });
                return;
            }
            if (self.ctx.getOptionalTimer()) |timer| {
                if (timer.setTimeout(0, settle, self) != 0) return;
            }
            settle(self);
        }

        /// The fetch task: HTML "queue a global task", its run side - it runs
        /// in the realm, which ends it (a worker's end of task too).
        fn settle(context: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            // The realm can end while the task waits in the queue. And
            // processResponse step 1: if locallyAborted is true, abort these
            // steps - the abort steps settled p already.
            if (!alive(self) or self.locally_aborted) return self.taskDone();
            // An error means the steps never ran (the realm is gone): the
            // task is over either way.
            engine.runTaskInRealm(self.ctx, settleSteps, self) catch {};
            self.taskDone();
        }

        fn settleSteps(data: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(data.?));
            self.processResponse();
        }

        /// processResponse, given fetch's outcome.
        fn processResponse(self: *Self) void {
            const outcome = self.outcome orelse return;
            self.outcome = null;
            var result = outcome catch return self.rejectTypeError("Failed to fetch");
            result.timing_info.deinit();
            const response = result.response;

            // Step 3: a network error rejects p with a TypeError.
            if (response.response_type == .@"error") {
                response.deinit();
                return self.rejectTypeError("Failed to fetch");
            }

            // Step 4: responseObject is the result of creating a Response
            // object given response, "immutable" and relevantRealm.
            const response_object = interfaces.Response.call_constructor(self.ctx, webidl.Opt(?typedefs.BodyInit).notPassed(), webidl.Opt(dictionaries.ResponseInit).notPassed()) catch {
                response.deinit();
                return self.rejectTypeError("Failed to fetch");
            };
            if (!fetch_objects.adoptResponse(response_object, @ptrCast(response), .immutable)) {
                response.deinit();
                return self.rejectTypeError("Failed to fetch");
            }
            // The abort steps name responseObject from here: an abort after
            // this errors its body (step 11.4's "abort the fetch() call",
            // step 5) - also once this call is over, so the response carries
            // the signal itself.
            if (self.liveSignal()) |signal| _ = fetch_objects.followSignal(response_object, signal);

            // Step 5: resolve p with responseObject - its wrapper in its
            // relevant realm.
            engine.resolvePromise(&self.capability, .{ .instance = response_object }) catch {};
            self.settleResolver();
        }

        /// p is settled: its capability has done its job. Holding it longer
        /// keeps p, and through it the realm, for nothing.
        fn settleResolver(self: *Self) void {
            if (self.settled) return;
            self.settled = true;
            engine.releasePromiseCapability(&self.capability);
        }

        fn rejectTypeError(self: *Self, message: []const u8) void {
            if (self.settled) return;
            const reason = engine.createSimpleException(self.ctx, .TypeError, message) catch return self.settleResolver();
            defer reason.release();
            engine.rejectPromise(&self.capability, reason.value) catch {};
            self.settleResolver();
        }

        /// Step 11's abort steps, run when requestObject's signal is
        /// aborted - from script (`controller.abort()`), or from a task
        /// (`AbortSignal.timeout()`), either way inside the realm.
        fn aborted(context: *anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context));
            const signal = self.liveSignal();
            // The signal empties its abort algorithms as it runs them, so
            // there is nothing to remove from it any more.
            self.signal = null;

            // Step 11.1: Set locallyAborted to true.
            self.locally_aborted = true;

            // Step 11.4's "abort the fetch() call", step 2: cancel request's
            // body with the reason, while it is being read to be sent - the
            // stream's source hears it at once. (A body of bytes has nothing
            // script can see to cancel.)
            if (self.upload) |u| {
                self.upload = null;
                if (self.pending_request) |r| r.deinit();
                self.pending_request = null;
                const cancel_realm = streams_js.Realm.ofContext(self.ctx) catch null;
                const reason: ?streams_js.Value = if (signal) |s| blk: {
                    const value = interfaces.AbortSignal.get_reason(s) catch break :blk null;
                    const r = cancel_realm orelse break :blk null;
                    break :blk r.fromRuntime(value) catch null;
                } else null;
                if (reason) |r| {
                    defer streams_js.dispose(r);
                    u.cancel(r);
                } else if (cancel_realm) |r| {
                    const undef = r.undefinedValue() catch null;
                    if (undef) |v| {
                        defer streams_js.dispose(v);
                        u.cancel(v);
                    }
                }
                self.fetch_holds = false;
            }

            // Step 11.3: Abort controller with the signal's abort reason -
            // the fetch ends here, its transfer cancelled, and a body still
            // arriving errors with that reason: step 11.4's "abort the
            // fetch() call" step 5, "error response's body with error", once
            // responseObject exists, reaches the body's stream through its
            // pipe.
            if (self.in_flight) |f| {
                self.in_flight = null;
                f.terminateWith(self.abortFailure(signal));
                self.fetch_holds = false;
            }

            // Step 11.4, step 1: reject p with the reason - a no-op once p
            // is settled.
            if (!self.settled) {
                if (signal) |s| self.rejectWithAbortReason(s);
            }
            self.maybeRelease();
        }

        /// The failure a body errors with when the fetch is aborted: the
        /// signal's abort reason, held for as long as the body needs it.
        fn abortFailure(self: *Self, signal: ?*runtime.Instance) fetch.algorithms.async_fetch.Failure {
            const s = signal orelse return .{ .kind = .aborted };
            const reason_value = interfaces.AbortSignal.get_reason(s) catch return .{ .kind = .aborted };
            const held = fetch_body.AbortReason.create(self.ctx, reason_value) orelse return .{ .kind = .aborted };
            return .{ .kind = .aborted, .reason = held, .release_reason = fetch_body.AbortReason.release };
        }

        fn rejectWithAbortReason(self: *Self, signal: *runtime.Instance) void {
            const reason_value = interfaces.AbortSignal.get_reason(signal) catch return;
            engine.rejectPromise(&self.capability, reason_value) catch {};
        }

        fn liveSignal(self: *const Self) ?*runtime.Instance {
            const signal = self.signal orelse return null;
            if (runtime.SlabAllocator.generationOf(signal) != self.signal_generation) return null;
            return signal;
        }

        /// requestObject's body is read: it is the request's body now, and
        /// the fetch starts.
        fn uploadRead(context: *anyopaque, bytes: []const u8) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.upload = null;
            const request = self.pending_request orelse return self.startFailed();
            self.pending_request = null;
            const body = fetch.internal.Body.fromBytes(self.allocator, bytes) catch {
                request.deinit();
                return self.startFailed();
            };
            if (request.body) |old| switch (old) {
                .body => |b| b.deinit(),
                .bytes => {},
            };
            request.body = .{ .body = body };
            // The fetch owns the request from here, and frees it on failure.
            self.in_flight = fetch.algorithms.AsyncFetch.startStreaming(self.allocator, request, .{}, fetch.network.scheduler.threadScheduler(), self.client()) catch
                return self.startFailed();
        }

        /// requestObject's body could not be read - its stream errored, or a
        /// chunk was no Uint8Array: a network error. Or the read was dropped
        /// (`e` null): the realm is going, its stream torn down, and nothing
        /// may be made in it - p is let go unsettled, as `gone` does.
        fn uploadFailed(context: *anyopaque, e: ?streams_js.Value) void {
            const self: *Self = @ptrCast(@alignCast(context));
            self.upload = null;
            if (self.pending_request) |r| r.deinit();
            self.pending_request = null;
            if (e == null) {
                self.settleResolver();
                self.fetch_holds = false;
                return self.maybeRelease();
            }
            self.startFailed();
        }

        /// The fetch never started: p rejects with a TypeError, as for a
        /// network error, and the fetch lets go of this call.
        fn startFailed(self: *Self) void {
            self.rejectTypeError("Failed to fetch");
            self.fetch_holds = false;
            self.maybeRelease();
        }

        /// A task that will never run: its loop is going.
        fn drop(context: ?*anyopaque) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            self.taskDone();
        }

        fn taskDone(self: *Self) void {
            self.task_holds = false;
            // A response the task did not adopt goes: its body with it,
            // which lets the transfer go too.
            if (self.outcome) |outcome| {
                self.outcome = null;
                var result = outcome catch null;
                if (result) |*r| r.deinit();
            }
            self.settleResolver();
            self.maybeRelease();
        }

        fn maybeRelease(self: *Self) void {
            if (self.fetch_holds or self.task_holds) return;
            if (self.liveSignal()) |signal| abort_algorithms.remove(signal, self);
            self.signal = null;
            self.signal_pin.release();
            if (self.outcome) |outcome| {
                var result = outcome catch null;
                if (result) |*r| r.deinit();
            }
            self.settleResolver();
            self.allocator.destroy(self);
        }
    };

    // Step 8: relevantRealm, this's relevant realm.
    const realm = try streams_js.Realm.of(instance);

    // Step 1: Let p be a new promise.
    var capability = try engine.createPromise(instance.ctx);
    // What this call returns: p, held now, before anything can settle p and
    // release the capability (and its view of p) - a body read to the end
    // inside this call does. Handed to the binding with the result; kept, it
    // pinned the page.
    const p = engine.retainValue(instance.ctx, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    errdefer p.release();
    // The capability is released here unless the fetch takes it.
    var capability_taken = false;
    defer if (!capability_taken) engine.releasePromiseCapability(&capability);

    // Step 2: Let requestObject be the result of invoking the initial value
    // of Request as constructor with input and init. If this throws, reject
    // p with it and return p.
    //
    // The binding converted `init` before this call, so a throwing getter in
    // it has already propagated from fetch(), before p existed. Deviation: it
    // should reject p.
    const request_object = interfaces.Request.call_constructor(instance.ctx, input, init_data) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => {
            rejectWithTypeError(instance.ctx, &capability, "Failed to execute 'fetch': the Request could not be constructed.");
            return p.take();
        },
    };
    // Nothing script can see holds requestObject, unless its signal's
    // listeners wrapped it; it goes when the call does.
    const request_generation = runtime.SlabAllocator.generationOf(request_object);
    defer request_object.releaseIfUnwrapped(request_generation);

    // Step 3: Let request be requestObject's request.
    const request: *fetch.internal.InternalRequest = @ptrCast(@alignCast(fetch_objects.requestOf(request_object) orelse return error.InvalidStateError));

    // Step 4: If requestObject's signal is aborted, abort the fetch() call
    // with p, request, null, and the signal's abort reason, and return p.
    const signal = try interfaces.Request.get_signal(request_object);
    if (try interfaces.AbortSignal.get_aborted(signal)) {
        const reason = try realm.fromRuntime(try interfaces.AbortSignal.get_reason(signal));
        defer streams_js.dispose(reason);
        // "Abort the fetch() call" step 1: reject p; step 2: cancel
        // request's body, if it is readable.
        engine.rejectPromise(&capability, reason.value) catch {};
        if (fetch_objects.requestBodyStream(request_object)) |stream| fetch_body.cancelStream(realm, stream, reason);
        return p.take();
    }

    // Steps 5-6: no ServiceWorkerGlobalScope exists here.
    // Steps 9-11 are added to requestObject's signal below, once the fetch -
    // step 12's controller - exists for them to abort. Nothing can run in
    // between.

    // Step 12: fetch request. The fetch outlives this call, and requestObject
    // may not, so it fetches a clone: nothing script can observe tells the
    // two apart, since the fetch changes only request's current URL.
    const fetched_request = try request.clone();
    const call = allocator.create(Call) catch {
        fetched_request.deinit();
        return error.OutOfMemory;
    };
    call.* = .{ .allocator = allocator, .ctx = instance.ctx, .capability = capability };
    // Only HTTP(S) transmits a request body (HTTP-network fetch); a data:,
    // blob: or about: fetch never reads it, so neither does this - a stream
    // that never closes must not hold such a fetch up.
    const url = fetched_request.getUrl();
    const transmits_body = std.ascii.startsWithIgnoreCase(url, "http:") or std.ascii.startsWithIgnoreCase(url, "https:");
    const body_stream = if (transmits_body) fetch_objects.requestBodyStream(request_object) else null;
    if (body_stream) |stream| {
        // The body's bytes are only in its stream: read them first (the
        // read starts below, once the abort steps can reach it).
        call.pending_request = fetched_request;
        call.upload = fetch_body.ReadAll.start(allocator, realm, stream, call, Call.uploadRead, Call.uploadFailed) catch {
            fetched_request.deinit();
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
    } else {
        call.in_flight = fetch.algorithms.AsyncFetch.startStreaming(allocator, fetched_request, .{}, fetch.network.scheduler.threadScheduler(), call.client()) catch {
            // The fetch owned the request, and freed it.
            allocator.destroy(call);
            rejectWithTypeError(instance.ctx, &capability, "Failed to fetch");
            return p.take();
        };
    }
    capability_taken = true;

    // Step 11: Add the abort steps to requestObject's signal. Without them
    // the call still settles; it just cannot be aborted.
    if (abort_algorithms.add(signal, .{ .ctx = call, .run = Call.aborted })) {
        call.signal = signal;
        call.signal_generation = runtime.SlabAllocator.generationOf(signal);
        call.signal_pin.hold(signal);
    } else |err| {
        std.log.scoped(.fetch).warn("fetch(): abort steps not added: {s}", .{@errorName(err)});
    }

    // Read the body to send. It may be read - and the fetch started, or p
    // rejected and the call freed - before this returns: `call` is not
    // touched after.
    if (call.upload) |u| u.begin();

    // Step 13.
    return p.take();
}

fn rejectWithTypeError(realm: runtime.Context, capability: *engine.PromiseCapability, message: []const u8) void {
    const reason = engine.createSimpleException(realm, .TypeError, message) catch return;
    defer reason.release();
    engine.rejectPromise(capability, reason.value) catch {};
}
