//! Writable streams: the internal slots and abstract operations of
//! WHATWG Streams § 5 (WritableStream, WritableStreamDefaultWriter,
//! WritableStreamDefaultController).
//!
//! The spec's abstract operations reach across all three classes' slots, so
//! they live here, once, and the three impl files are thin IDL shells over
//! them - no impl calls another impl. Step numbers are the spec's.
//!
//! Values and promises go through `streams_js.zig`; see its header for the
//! one-handle-kind rule and why the objects reactions point at stay valid.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const js = @import("streams_js.zig");

const Value = js.Value;
const Realm = js.Realm;
const Deferred = js.Deferred;

// ============================================================================
// Internal slots
// ============================================================================

pub const StreamState = enum { writable, closed, erroring, errored };

/// § 5.2.2 "pending abort request"
pub const PendingAbortRequest = struct {
    promise: Deferred,
    /// Owned.
    reason: Value,
    was_already_erroring: bool,
};

/// § 5.2.2 WritableStream internal slots.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    state: StreamState = .writable,
    /// [[storedError]], owned.
    stored_error: ?Value = null,
    writer: ?*runtime.Instance = null,
    controller: ?*runtime.Instance = null,
    in_flight_write_request: ?Deferred = null,
    close_request: ?Deferred = null,
    in_flight_close_request: ?Deferred = null,
    pending_abort_request: ?PendingAbortRequest = null,
    write_requests: std.ArrayList(Deferred) = .empty,
    backpressure: bool = false,
    /// The last promise handed to script that nothing else keeps; see `give`.
    returned: ?Value = null,

    pub fn deinit(self: *Stream) void {
        js.disposeOptional(&self.stored_error);
        if (self.in_flight_write_request) |d| d.deinit();
        if (self.close_request) |d| d.deinit();
        if (self.in_flight_close_request) |d| d.deinit();
        if (self.pending_abort_request) |r| {
            r.promise.deinit();
            js.dispose(r.reason);
        }
        for (self.write_requests.items) |d| d.deinit();
        self.write_requests.deinit(self.allocator);
        js.disposeOptional(&self.returned);
        self.allocator.destroy(self);
    }
};

/// § 5.3.2 WritableStreamDefaultWriter internal slots.
pub const Writer = struct {
    allocator: std.mem.Allocator,
    stream: ?*runtime.Instance = null,
    closed_promise: ?Deferred = null,
    ready_promise: ?Deferred = null,
    returned: ?Value = null,

    pub fn deinit(self: *Writer) void {
        if (self.closed_promise) |d| d.deinit();
        if (self.ready_promise) |d| d.deinit();
        js.disposeOptional(&self.returned);
        self.allocator.destroy(self);
    }
};

/// The underlying sink's algorithms (§ 5.4.2 [[writeAlgorithm]] etc.): either
/// author callbacks (`UnderlyingSink`) or engine-provided ones.
pub const Sink = struct {
    ctx: ?*anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// startAlgorithm. Its completion is returned as-is: a throw is the
        /// setup's abrupt completion. Both arms owned.
        start: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!js.Completion,
        /// writeAlgorithm, closeAlgorithm, abortAlgorithm: owned promises.
        write: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, chunk: Value) js.Error!Value,
        close: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value,
        abort: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value,
        /// Release what `ctx` owns. Runs once, at ClearAlgorithms or teardown.
        deinit: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator) void,
    };
};

/// [[strategySizeAlgorithm]]
pub const SizeAlgorithm = union(enum) {
    /// ExtractSizeAlgorithm without strategy["size"]: returns 1.
    one,
    /// strategy["size"], owned.
    callback: Value,
    /// Set to undefined by ClearAlgorithms.
    cleared,
};

pub const QueueEntry = union(enum) {
    chunk: struct { value: Value, size: f64 },
    close_sentinel,
};

/// § 5.4.2 WritableStreamDefaultController internal slots.
pub const Controller = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    /// Null once ClearAlgorithms has run.
    sink: ?Sink,
    size_algorithm: SizeAlgorithm = .one,
    strategy_hwm: f64,
    queue: std.ArrayList(QueueEntry) = .empty,
    queue_total_size: f64 = 0,
    started: bool = false,
    abort_controller: ?*runtime.Instance = null,
    /// Strong Globals for the AbortController's and its signal's wrappers.
    /// Neither is a streams-graph object, so without these a collected
    /// `controller.signal` wrapper would free a signal this controller still
    /// signals.
    abort_keepalive: [2]?Value = .{ null, null },

    pub fn deinit(self: *Controller) void {
        clearAlgorithms(self);
        resetQueue(self);
        self.queue.deinit(self.allocator);
        for (&self.abort_keepalive) |*k| js.disposeOptional(k);
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Slot access (brand-checked)
// ============================================================================

pub fn streamOf(instance: *runtime.Instance) ?*Stream {
    const state = instance.stateAs(interfaces.WritableStream.State) orelse return null;
    return state.own._internal;
}

pub fn writerOf(instance: *runtime.Instance) ?*Writer {
    const state = instance.stateAs(interfaces.WritableStreamDefaultWriter.State) orelse return null;
    return state.own._internal;
}

pub fn controllerOf(instance: *runtime.Instance) ?*Controller {
    const state = instance.stateAs(interfaces.WritableStreamDefaultController.State) orelse return null;
    return state.own._internal;
}

fn streamSlots(instance: *runtime.Instance) *Stream {
    return streamOf(instance).?;
}

fn controllerSlots(instance: *runtime.Instance) *Controller {
    return controllerOf(instance).?;
}

/// Hand `value` (owned) to script as a return value. The binding reads the
/// handle synchronously and never disposes it, so the slot keeps it until the
/// next return replaces it or the object is torn down.
pub fn give(slot: *?Value, value: Value) runtime.JSValue {
    js.disposeOptional(slot);
    slot.* = value;
    return js.toReturn(value);
}

// ============================================================================
// Underlying sink from an author object (§ 5.4.4 SetUpWritableStreamDefault-
// ControllerFromUnderlyingSink steps 2-9)
// ============================================================================

/// The UnderlyingSink dictionary (§ 5.2.3), converted, plus the object itself
/// as the callbacks' "callback this value".
pub const UnderlyingSink = struct {
    this: ?Value = null,
    start: ?Value = null,
    write: ?Value = null,
    close: ?Value = null,
    abort: ?Value = null,

    fn release(self: *UnderlyingSink) void {
        js.disposeOptional(&self.this);
        js.disposeOptional(&self.start);
        js.disposeOptional(&self.write);
        js.disposeOptional(&self.close);
        js.disposeOptional(&self.abort);
    }

    fn deinitErased(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *UnderlyingSink = @ptrCast(@alignCast(ctx.?));
        self.release();
        allocator.destroy(self);
    }

    fn startErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!js.Completion {
        const self: *UnderlyingSink = @ptrCast(@alignCast(ctx.?));
        // Step 2: an algorithm that returns undefined.
        const start_fn = self.start orelse return .{ .normal = try realm.undefinedValue() };
        // Step 6: invoke start with « controller », exception behavior
        // "rethrow", callback this value underlyingSink.
        return realm.call(start_fn, self.this, &.{try realm.wrap(controller)});
    }

    fn writeErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, chunk: Value) js.Error!Value {
        const self: *UnderlyingSink = @ptrCast(@alignCast(ctx.?));
        // Step 3: an algorithm that returns a promise resolved with undefined.
        const write_fn = self.write orelse return realm.promiseResolvedWithUndefined();
        // Step 7: invoke write with « chunk, controller ».
        return realm.promiseCall(write_fn, self.this, &.{ chunk, try realm.wrap(controller) });
    }

    fn closeErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value {
        _ = controller;
        const self: *UnderlyingSink = @ptrCast(@alignCast(ctx.?));
        // Steps 4 and 8: invoke close with « ».
        const close_fn = self.close orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(close_fn, self.this, &.{});
    }

    fn abortErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value {
        _ = controller;
        const self: *UnderlyingSink = @ptrCast(@alignCast(ctx.?));
        // Steps 5 and 9: invoke abort with « reason ».
        const abort_fn = self.abort orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(abort_fn, self.this, &.{reason});
    }

    const vtable = Sink.VTable{
        .start = startErased,
        .write = writeErased,
        .close = closeErased,
        .abort = abortErased,
        .deinit = deinitErased,
    };
};

/// Convert `underlyingSink` (§ 5.2.4 constructor steps 1-3) to the
/// UnderlyingSink dictionary - WebIDL § 3.2.18: members in lexicographic
/// order (abort, close, start, type, write), each read with Get, undefined
/// meaning absent, callback members required to be callable.
/// On error.ExceptionPending the exception is already thrown.
pub fn convertUnderlyingSink(realm: Realm, allocator: std.mem.Allocator, object: ?Value) js.Error!*UnderlyingSink {
    const dict = try allocator.create(UnderlyingSink);
    dict.* = .{};
    errdefer {
        dict.release();
        allocator.destroy(dict);
    }
    // Step 1: a missing underlyingSink is null, and null converts to the
    // default dictionary.
    const obj = object orelse return dict;
    dict.this = try js.clone(obj);
    if (!js.isObject(obj)) return dict;

    dict.abort = try js.getCallbackMember(realm, obj, "abort");
    dict.close = try js.getCallbackMember(realm, obj, "close");
    dict.start = try js.getCallbackMember(realm, obj, "start");
    // Step 3: if underlyingSinkDict["type"] exists, throw a RangeError.
    if (try js.getMember(realm, obj, "type")) |type_value| {
        js.dispose(type_value);
        const err = try realm.rangeError("WritableStream type must be undefined");
        defer js.dispose(err);
        return realm.throwValue(err);
    }
    dict.write = try js.getCallbackMember(realm, obj, "write");
    return dict;
}

pub fn sinkFromUnderlyingSink(dict: *UnderlyingSink) Sink {
    return .{ .ctx = dict, .vtable = &UnderlyingSink.vtable };
}

// ============================================================================
// Queuing strategy (§ 7.4 / § 8.1)
// ============================================================================

/// ExtractHighWaterMark(strategy, defaultHWM)
pub fn extractHighWaterMark(strategy: dictionaries.QueuingStrategy, default_hwm: f64) error{RangeError}!f64 {
    // Step 1: If strategy["highWaterMark"] does not exist, return defaultHWM.
    const hwm = strategy.highWaterMark orelse return default_hwm;
    // Step 3: If highWaterMark is NaN or highWaterMark < 0, throw a RangeError.
    if (std.math.isNan(hwm) or hwm < 0) return error.RangeError;
    return hwm;
}

/// ExtractSizeAlgorithm(strategy). `size` is the dictionary's callback
/// member: a tagged Global the conversion layer made for this call, which
/// nothing else disposes - so it is taken over here.
pub fn extractSizeAlgorithm(strategy: dictionaries.QueuingStrategy) js.Error!SizeAlgorithm {
    const size = strategy.size orelse return .one;
    const untagged = @import("v8").pointer_tag.untagPointer(@ptrCast(size));
    const global: Value = @ptrCast(@alignCast(@constCast(untagged.ptr)));
    return .{ .callback = try js.clone(global) };
}

/// IsNonNegativeNumber(v), for a size already known to be a Number.
fn isNonNegativeNumber(v: f64) bool {
    return !std.math.isNan(v) and v >= 0;
}

fn resetQueue(controller: *Controller) void {
    for (controller.queue.items) |entry| switch (entry) {
        .chunk => |c| js.dispose(c.value),
        .close_sentinel => {},
    };
    controller.queue.clearRetainingCapacity();
    controller.queue_total_size = 0;
}

/// DequeueValue(container)
fn dequeueValue(controller: *Controller) QueueEntry {
    // Steps 1-3: remove the first value-with-size.
    const entry = controller.queue.orderedRemove(0);
    // Step 4: subtract its size.
    const size = switch (entry) {
        .chunk => |c| c.size,
        .close_sentinel => 0,
    };
    controller.queue_total_size -= size;
    // Step 5: rounding errors can leave the total a hair below zero.
    if (controller.queue_total_size < 0) controller.queue_total_size = 0;
    return entry;
}

// ============================================================================
// § 5.5.1 Working with writable streams
// ============================================================================

/// InitializeWritableStream(stream): a new instance with fresh slots.
pub fn newStream(ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.WritableStream.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Stream);
    // Steps 1-4: writable, every slot undefined, no write requests, no
    // backpressure.
    slots.* = .{ .allocator = ctx.allocator };
    instance.getState(interfaces.WritableStream.State).own._internal = slots;
    return instance;
}

/// IsWritableStreamLocked(stream)
pub fn isLocked(stream: *Stream) bool {
    return stream.writer != null;
}

/// AcquireWritableStreamDefaultWriter(stream)
pub fn acquireWriter(realm: Realm, stream_instance: *runtime.Instance) !*runtime.Instance {
    // Step 1: Let writer be a new WritableStreamDefaultWriter.
    const writer = try newWriter(stream_instance.ctx);
    errdefer runtime.Instance.deinit(writer);
    // Step 2: Perform ? SetUpWritableStreamDefaultWriter(writer, stream).
    try setUpWriter(realm, writer, stream_instance);
    return writer;
}

pub fn newWriter(ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.WritableStreamDefaultWriter.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Writer);
    slots.* = .{ .allocator = ctx.allocator };
    instance.getState(interfaces.WritableStreamDefaultWriter.State).own._internal = slots;
    return instance;
}

/// SetUpWritableStreamDefaultWriter(writer, stream)
pub fn setUpWriter(realm: Realm, writer_instance: *runtime.Instance, stream_instance: *runtime.Instance) !void {
    const writer = writerOf(writer_instance).?;
    const stream = streamSlots(stream_instance);
    // Step 1: If ! IsWritableStreamLocked(stream) is true, throw a TypeError.
    if (isLocked(stream)) return error.TypeError;
    // Step 2: Set writer.[[stream]] to stream.
    writer.stream = stream_instance;
    // Step 3: Set stream.[[writer]] to writer.
    stream.writer = writer_instance;
    // Step 4: Let state be stream.[[state]].
    switch (stream.state) {
        // Step 5
        .writable => {
            // 5.1-5.2: a pending ready promise under backpressure, else resolved.
            writer.ready_promise = if (!closeQueuedOrInFlight(stream) and stream.backpressure)
                try Deferred.init(realm)
            else
                try Deferred.initResolved(realm);
            // 5.3
            writer.closed_promise = try Deferred.init(realm);
        },
        // Step 6
        .erroring => {
            // 6.1-6.2
            writer.ready_promise = try Deferred.initRejected(realm, stream.stored_error.?);
            writer.ready_promise.?.markHandled();
            // 6.3
            writer.closed_promise = try Deferred.init(realm);
        },
        // Step 7
        .closed => {
            writer.ready_promise = try Deferred.initResolved(realm);
            writer.closed_promise = try Deferred.initResolved(realm);
        },
        // Step 8
        .errored => {
            // 8.2-8.6
            const stored_error = stream.stored_error.?;
            writer.ready_promise = try Deferred.initRejected(realm, stored_error);
            writer.ready_promise.?.markHandled();
            writer.closed_promise = try Deferred.initRejected(realm, stored_error);
            writer.closed_promise.?.markHandled();
        },
    }
}

/// WritableStreamAbort(stream, reason). Returns an owned promise.
pub fn abort(realm: Realm, stream_instance: *runtime.Instance, reason_in: Value) js.Error!Value {
    const stream = streamSlots(stream_instance);
    // Step 1: If state is "closed" or "errored", return a promise resolved
    // with undefined.
    if (stream.state == .closed or stream.state == .errored) return realm.promiseResolvedWithUndefined();
    // Step 2: Signal abort on stream.[[controller]].[[abortController]] with
    // reason.
    signalAbort(realm, controllerSlots(stream.controller.?), reason_in);
    // Step 3-4: re-check - signalling abort ran author code.
    const state = stream.state;
    if (state == .closed or state == .errored) return realm.promiseResolvedWithUndefined();
    // Step 5: If a pending abort request exists, return its promise.
    if (stream.pending_abort_request) |request| return js.clone(request.promise.promise);
    // Step 6: Assert: state is "writable" or "erroring".
    // Steps 7-8: an abort of a stream already erroring does not replace its
    // error: the reason becomes undefined.
    const was_already_erroring = state == .erroring;
    const reason = if (was_already_erroring) try realm.undefinedValue() else try js.clone(reason_in);
    errdefer js.dispose(reason);
    // Step 9: Let promise be a new promise.
    const promise = try Deferred.init(realm);
    // Step 10: Set stream.[[pendingAbortRequest]].
    stream.pending_abort_request = .{ .promise = promise, .reason = reason, .was_already_erroring = was_already_erroring };
    // Step 11: If wasAlreadyErroring is false, perform ! WritableStreamStartErroring(stream, reason).
    if (!was_already_erroring) startErroring(realm, stream_instance, reason);
    // Step 12: Return promise.
    return js.clone(promise.promise);
}

/// WritableStreamClose(stream). Returns an owned promise.
pub fn close(realm: Realm, stream_instance: *runtime.Instance) js.Error!Value {
    const stream = streamSlots(stream_instance);
    // Steps 1-2: closed or errored streams reject with a TypeError.
    if (stream.state == .closed or stream.state == .errored)
        return realm.promiseRejectedWithTypeError("The stream is closed or errored");
    // Steps 3-4: Assert: writable or erroring, and no close queued or in flight.
    // Step 5: Let promise be a new promise.
    const promise = try Deferred.init(realm);
    // Step 6: Set stream.[[closeRequest]] to promise.
    stream.close_request = promise;
    // Steps 7-8: a close releases backpressure on the writer.
    if (stream.writer) |writer_instance| {
        if (stream.backpressure and stream.state == .writable) {
            if (writerOf(writer_instance).?.ready_promise) |ready| ready.resolveUndefined(realm);
        }
    }
    // Step 9: Perform ! WritableStreamDefaultControllerClose(stream.[[controller]]).
    controllerClose(realm, stream.controller.?);
    // Step 10: Return promise.
    return js.clone(promise.promise);
}

// ============================================================================
// § 5.5.2 Interfacing with controllers
// ============================================================================

/// WritableStreamAddWriteRequest(stream). Returns an owned promise.
fn addWriteRequest(realm: Realm, stream: *Stream) js.Error!Value {
    // Steps 1-2: Assert: locked and writable.
    // Step 3: Let promise be a new promise.
    const promise = try Deferred.init(realm);
    errdefer promise.deinit();
    // Step 4: Append promise to stream.[[writeRequests]].
    try stream.write_requests.append(stream.allocator, promise);
    // Step 5: Return promise.
    return js.clone(promise.promise);
}

/// WritableStreamCloseQueuedOrInFlight(stream)
pub fn closeQueuedOrInFlight(stream: *const Stream) bool {
    return stream.close_request != null or stream.in_flight_close_request != null;
}

/// WritableStreamDealWithRejection(stream, error)
fn dealWithRejection(realm: Realm, stream_instance: *runtime.Instance, err: Value) void {
    const stream = streamSlots(stream_instance);
    // Step 2: If state is "writable", start erroring and return.
    if (stream.state == .writable) {
        startErroring(realm, stream_instance, err);
        return;
    }
    // Step 3: Assert: state is "erroring".
    // Step 4: Perform ! WritableStreamFinishErroring(stream).
    finishErroring(realm, stream_instance);
}

/// WritableStreamFinishErroring(stream)
fn finishErroring(realm: Realm, stream_instance: *runtime.Instance) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-2: Assert: erroring, and no operation marked in flight.
    // Step 3: Set stream.[[state]] to "errored".
    stream.state = .errored;
    // Step 4: Perform ! stream.[[controller]].[[ErrorSteps]]().
    errorSteps(controllerSlots(stream.controller.?));
    // Step 5: Let storedError be stream.[[storedError]].
    const stored_error = stream.stored_error.?;
    // Step 6: Reject every write request with storedError.
    for (stream.write_requests.items) |request| {
        request.reject(realm, stored_error);
        request.deinit();
    }
    // Step 7: Set stream.[[writeRequests]] to an empty list.
    stream.write_requests.clearRetainingCapacity();
    // Step 8: If there is no pending abort request, reject the close and
    // closed promises and return.
    const abort_request = stream.pending_abort_request orelse {
        rejectCloseAndClosedPromiseIfNeeded(realm, stream);
        return;
    };
    // Steps 9-10: take the abort request.
    stream.pending_abort_request = null;
    // Step 11: an abort of a stream that was already erroring rejects with
    // the stored error.
    if (abort_request.was_already_erroring) {
        abort_request.promise.reject(realm, stored_error);
        abort_request.promise.deinit();
        js.dispose(abort_request.reason);
        rejectCloseAndClosedPromiseIfNeeded(realm, stream);
        return;
    }
    // Step 12: Let promise be ! stream.[[controller]].[[AbortSteps]](reason).
    const promise = abortSteps(realm, stream.controller.?, abort_request.reason) catch {
        abort_request.promise.deinit();
        js.dispose(abort_request.reason);
        return;
    };
    defer js.dispose(promise);
    js.dispose(abort_request.reason);
    // Steps 13-14: settle the abort request's promise with the abort
    // algorithm's outcome, then reject the close and closed promises.
    const reaction = stream.allocator.create(AbortReaction) catch {
        abort_request.promise.deinit();
        return;
    };
    reaction.* = .{ .stream_instance = stream_instance, .request = abort_request.promise };
    realm.react(promise, AbortReaction, reaction, AbortReaction.onFulfilled, AbortReaction.onRejected) catch {
        abort_request.promise.deinit();
        stream.allocator.destroy(reaction);
    };
}

const AbortReaction = struct {
    stream_instance: *runtime.Instance,
    request: Deferred,

    fn finish(self: *AbortReaction, outcome: ?Value) void {
        const stream = streamSlots(self.stream_instance);
        const realm = Realm.of(self.stream_instance) catch return;
        // 13.1 resolve / 14.1 reject the abort request's promise.
        if (outcome) |reason| self.request.reject(realm, reason) else self.request.resolveUndefined(realm);
        self.request.deinit();
        // 13.2 / 14.2
        rejectCloseAndClosedPromiseIfNeeded(realm, stream);
        stream.allocator.destroy(self);
    }

    fn onFulfilled(self: *AbortReaction, _: Value) void {
        self.finish(null);
    }

    fn onRejected(self: *AbortReaction, reason: Value) void {
        self.finish(reason);
    }
};

/// WritableStreamFinishInFlightClose(stream)
fn finishInFlightClose(realm: Realm, stream_instance: *runtime.Instance) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-3: resolve and clear the in-flight close request.
    const request = stream.in_flight_close_request.?;
    stream.in_flight_close_request = null;
    request.resolveUndefined(realm);
    request.deinit();
    // Step 4-5: Assert: writable or erroring.
    // Step 6: An erroring stream that closes anyway drops its error and
    // resolves a pending abort.
    if (stream.state == .erroring) {
        js.disposeOptional(&stream.stored_error);
        if (stream.pending_abort_request) |abort_request| {
            stream.pending_abort_request = null;
            abort_request.promise.resolveUndefined(realm);
            abort_request.promise.deinit();
            js.dispose(abort_request.reason);
        }
    }
    // Step 7: Set stream.[[state]] to "closed".
    stream.state = .closed;
    // Steps 8-9: resolve the writer's closed promise.
    if (stream.writer) |writer_instance| {
        if (writerOf(writer_instance).?.closed_promise) |closed| closed.resolveUndefined(realm);
    }
}

/// WritableStreamFinishInFlightCloseWithError(stream, error)
fn finishInFlightCloseWithError(realm: Realm, stream_instance: *runtime.Instance, err: Value) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-3: reject and clear the in-flight close request.
    const request = stream.in_flight_close_request.?;
    stream.in_flight_close_request = null;
    request.reject(realm, err);
    request.deinit();
    // Step 5: reject a pending abort with the same error.
    if (stream.pending_abort_request) |abort_request| {
        stream.pending_abort_request = null;
        abort_request.promise.reject(realm, err);
        abort_request.promise.deinit();
        js.dispose(abort_request.reason);
    }
    // Step 6: Perform ! WritableStreamDealWithRejection(stream, error).
    dealWithRejection(realm, stream_instance, err);
}

/// WritableStreamFinishInFlightWrite(stream)
fn finishInFlightWrite(realm: Realm, stream: *Stream) void {
    // Steps 1-3: resolve and clear the in-flight write request.
    const request = stream.in_flight_write_request.?;
    stream.in_flight_write_request = null;
    request.resolveUndefined(realm);
    request.deinit();
}

/// WritableStreamFinishInFlightWriteWithError(stream, error)
fn finishInFlightWriteWithError(realm: Realm, stream_instance: *runtime.Instance, err: Value) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-3: reject and clear the in-flight write request.
    const request = stream.in_flight_write_request.?;
    stream.in_flight_write_request = null;
    request.reject(realm, err);
    request.deinit();
    // Step 5: Perform ! WritableStreamDealWithRejection(stream, error).
    dealWithRejection(realm, stream_instance, err);
}

/// WritableStreamHasOperationMarkedInFlight(stream)
fn hasOperationMarkedInFlight(stream: *const Stream) bool {
    return stream.in_flight_write_request != null or stream.in_flight_close_request != null;
}

/// WritableStreamMarkCloseRequestInFlight(stream)
fn markCloseRequestInFlight(stream: *Stream) void {
    stream.in_flight_close_request = stream.close_request;
    stream.close_request = null;
}

/// WritableStreamMarkFirstWriteRequestInFlight(stream)
fn markFirstWriteRequestInFlight(stream: *Stream) void {
    stream.in_flight_write_request = stream.write_requests.orderedRemove(0);
}

/// WritableStreamRejectCloseAndClosedPromiseIfNeeded(stream)
fn rejectCloseAndClosedPromiseIfNeeded(realm: Realm, stream: *Stream) void {
    // Step 1: Assert: stream.[[state]] is "errored".
    const stored_error = stream.stored_error orelse return;
    // Step 2: reject and clear a queued close request.
    if (stream.close_request) |request| {
        stream.close_request = null;
        request.reject(realm, stored_error);
        request.deinit();
    }
    // Steps 3-4: reject the writer's closed promise, marked handled.
    if (stream.writer) |writer_instance| {
        if (writerOf(writer_instance).?.closed_promise) |closed| {
            closed.reject(realm, stored_error);
            closed.markHandled();
        }
    }
}

/// WritableStreamStartErroring(stream, reason)
fn startErroring(realm: Realm, stream_instance: *runtime.Instance, reason: Value) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-4: Assert: no stored error, writable, has a controller.
    const controller = controllerSlots(stream.controller.?);
    // Step 5: Set stream.[[state]] to "erroring".
    stream.state = .erroring;
    // Step 6: Set stream.[[storedError]] to reason.
    js.disposeOptional(&stream.stored_error);
    stream.stored_error = js.clone(reason) catch null;
    // Steps 7-8: reject the writer's ready promise.
    if (stream.writer) |writer_instance| writerEnsureReadyPromiseRejected(realm, writerOf(writer_instance).?, reason);
    // Step 9: finish erroring now when nothing is in flight and the sink has
    // started.
    if (!hasOperationMarkedInFlight(stream) and controller.started) finishErroring(realm, stream_instance);
}

/// WritableStreamUpdateBackpressure(stream, backpressure)
fn updateBackpressure(realm: Realm, stream: *Stream, backpressure: bool) void {
    // Steps 1-2: Assert: writable, no close queued or in flight.
    // Steps 3-4: a change of backpressure replaces or resolves the ready
    // promise.
    if (stream.writer) |writer_instance| {
        if (backpressure != stream.backpressure) {
            const writer = writerOf(writer_instance).?;
            if (backpressure) {
                // 4.1: Set writer.[[readyPromise]] to a new promise.
                if (Deferred.init(realm)) |fresh| {
                    if (writer.ready_promise) |old| old.deinit();
                    writer.ready_promise = fresh;
                } else |_| {}
            } else {
                // 4.2: Resolve writer.[[readyPromise]] with undefined.
                if (writer.ready_promise) |ready| ready.resolveUndefined(realm);
            }
        }
    }
    // Step 5: Set stream.[[backpressure]] to backpressure.
    stream.backpressure = backpressure;
}

// ============================================================================
// § 5.5.3 Writers
// ============================================================================

/// WritableStreamDefaultWriterAbort(writer, reason)
pub fn writerAbort(realm: Realm, writer: *Writer, reason: Value) js.Error!Value {
    // Steps 1-3: Return ! WritableStreamAbort(stream, reason).
    return abort(realm, writer.stream.?, reason);
}

/// WritableStreamDefaultWriterClose(writer)
pub fn writerClose(realm: Realm, writer: *Writer) js.Error!Value {
    // Steps 1-3: Return ! WritableStreamClose(stream).
    return close(realm, writer.stream.?);
}

/// WritableStreamDefaultWriterCloseWithErrorPropagation(writer)
pub fn writerCloseWithErrorPropagation(realm: Realm, writer: *Writer) js.Error!Value {
    const stream = streamSlots(writer.stream.?);
    // Step 4: already closing or closed: resolved.
    if (closeQueuedOrInFlight(stream) or stream.state == .closed) return realm.promiseResolvedWithUndefined();
    // Step 5: errored: rejected with the stored error.
    if (stream.state == .errored) return realm.promiseRejectedWith(stream.stored_error.?);
    // Steps 6-7: Return ! WritableStreamDefaultWriterClose(writer).
    return writerClose(realm, writer);
}

/// WritableStreamDefaultWriterEnsureClosedPromiseRejected(writer, error)
fn writerEnsureClosedPromiseRejected(realm: Realm, writer: *Writer, err: Value) void {
    // Steps 1-2: reject a pending promise, else replace it with a rejected one.
    if (writer.closed_promise != null and writer.closed_promise.?.isPending()) {
        writer.closed_promise.?.reject(realm, err);
    } else if (Deferred.initRejected(realm, err)) |fresh| {
        if (writer.closed_promise) |old| old.deinit();
        writer.closed_promise = fresh;
    } else |_| {}
    // Step 3: Set [[PromiseIsHandled]] to true.
    if (writer.closed_promise) |closed| closed.markHandled();
}

/// WritableStreamDefaultWriterEnsureReadyPromiseRejected(writer, error)
fn writerEnsureReadyPromiseRejected(realm: Realm, writer: *Writer, err: Value) void {
    // Steps 1-2: reject a pending promise, else replace it with a rejected one.
    if (writer.ready_promise != null and writer.ready_promise.?.isPending()) {
        writer.ready_promise.?.reject(realm, err);
    } else if (Deferred.initRejected(realm, err)) |fresh| {
        if (writer.ready_promise) |old| old.deinit();
        writer.ready_promise = fresh;
    } else |_| {}
    // Step 3: Set [[PromiseIsHandled]] to true.
    if (writer.ready_promise) |ready| ready.markHandled();
}

/// WritableStreamDefaultWriterGetDesiredSize(writer)
pub fn writerGetDesiredSize(writer: *Writer) ?f64 {
    const stream = streamSlots(writer.stream.?);
    // Step 3: errored or erroring: null.
    if (stream.state == .errored or stream.state == .erroring) return null;
    // Step 4: closed: 0.
    if (stream.state == .closed) return 0;
    // Step 5: Return ! WritableStreamDefaultControllerGetDesiredSize(controller).
    return getDesiredSize(controllerSlots(stream.controller.?));
}

/// WritableStreamDefaultWriterRelease(writer)
pub fn writerRelease(realm: Realm, writer_instance: *runtime.Instance) void {
    const writer = writerOf(writer_instance).?;
    // Steps 1-3: Assert: stream is not undefined and stream.[[writer]] is writer.
    const stream = streamSlots(writer.stream.?);
    // Step 4: Let releasedError be a new TypeError.
    const released_error = realm.typeError("Writer was released") catch return;
    defer js.dispose(released_error);
    // Steps 5-6
    writerEnsureReadyPromiseRejected(realm, writer, released_error);
    writerEnsureClosedPromiseRejected(realm, writer, released_error);
    // Step 7: Set stream.[[writer]] to undefined.
    stream.writer = null;
    // Step 8: Set writer.[[stream]] to undefined.
    writer.stream = null;
}

/// WritableStreamDefaultWriterWrite(writer, chunk). Returns an owned promise.
pub fn writerWrite(realm: Realm, writer: *Writer, chunk: Value) js.Error!Value {
    // Step 1: Let stream be writer.[[stream]].
    const stream_instance = writer.stream.?;
    const stream = streamSlots(stream_instance);
    // Step 3: Let controller be stream.[[controller]].
    const controller_instance = stream.controller.?;
    // Step 4: Let chunkSize be ! WritableStreamDefaultControllerGetChunkSize(controller, chunk).
    const chunk_size = getChunkSize(realm, controller_instance, chunk);
    // Step 5: The size algorithm can release the writer.
    if (writer.stream != stream_instance) return realm.promiseRejectedWithTypeError("Writer was released while writing");
    // Step 7: errored: rejected with the stored error.
    if (stream.state == .errored) return realm.promiseRejectedWith(stream.stored_error.?);
    // Step 8: closing or closed: rejected with a TypeError.
    if (closeQueuedOrInFlight(stream) or stream.state == .closed)
        return realm.promiseRejectedWithTypeError("The stream is closing or closed");
    // Step 9: erroring: rejected with the stored error.
    if (stream.state == .erroring) return realm.promiseRejectedWith(stream.stored_error.?);
    // Step 10: Assert: state is "writable".
    // Step 11: Let promise be ! WritableStreamAddWriteRequest(stream).
    const promise = try addWriteRequest(realm, stream);
    // Step 12: Perform ! WritableStreamDefaultControllerWrite(controller, chunk, chunkSize).
    controllerWrite(realm, controller_instance, chunk, chunk_size);
    // Step 13: Return promise.
    return promise;
}

// ============================================================================
// § 5.5.4 Default controllers
// ============================================================================

pub fn newController(ctx: runtime.Context, stream_instance: *runtime.Instance, sink: Sink, hwm: f64, size: SizeAlgorithm) !*runtime.Instance {
    const instance = try interfaces.WritableStreamDefaultController.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Controller);
    slots.* = .{
        .allocator = ctx.allocator,
        .stream = stream_instance,
        .sink = sink,
        .size_algorithm = size,
        .strategy_hwm = hwm,
    };
    instance.getState(interfaces.WritableStreamDefaultController.State).own._internal = slots;
    return instance;
}

/// SetUpWritableStreamDefaultController(stream, controller, startAlgorithm,
/// writeAlgorithm, closeAlgorithm, abortAlgorithm, highWaterMark,
/// sizeAlgorithm). The algorithms and strategy are already in the
/// controller's slots (newController). A throwing startAlgorithm is thrown
/// into script and reported as error.ExceptionPending.
pub fn setUpController(realm: Realm, stream_instance: *runtime.Instance, controller_instance: *runtime.Instance) js.Error!void {
    const stream = streamSlots(stream_instance);
    const controller = controllerSlots(controller_instance);
    // Wrap now: the wrapper is what start() receives, and wrapping registers
    // the controller with the wrapper cache, which holds it until teardown.
    _ = try realm.wrap(controller_instance);
    // Steps 3-4: link stream and controller.
    stream.controller = controller_instance;
    // Step 5: Perform ! ResetQueue(controller).
    resetQueue(controller);
    // Step 6: Set controller.[[abortController]] to a new AbortController.
    controller.abort_controller = interfaces.AbortController.call_constructor(controller_instance.ctx) catch null;
    if (controller.abort_controller) |ac| {
        if (realm.wrap(ac)) |w| controller.abort_keepalive[0] = js.clone(w) catch null else |_| {}
        if (interfaces.AbortController.get_signal(ac)) |signal| {
            if (realm.wrap(signal)) |w| controller.abort_keepalive[1] = js.clone(w) catch null else |_| {}
        } else |_| {}
    }
    // Step 7: Set controller.[[started]] to false.
    controller.started = false;
    // Steps 8-12: strategy and algorithms are already in place.
    // Steps 13-14: publish the initial backpressure.
    updateBackpressure(realm, stream, getBackpressure(controller));
    // Step 15: Let startResult be the result of performing startAlgorithm.
    // (This may throw an exception.)
    const sink = controller.sink.?;
    const start_result = try sink.vtable.start(sink.ctx, realm, controller_instance);
    const start_value = switch (start_result) {
        .normal => |v| v,
        .thrown => |e| {
            defer js.dispose(e);
            return realm.throwValue(e);
        },
    };
    defer js.dispose(start_value);
    // Step 16: Let startPromise be a promise resolved with startResult.
    const start_promise = try realm.promiseResolvedWith(start_value);
    defer js.dispose(start_promise);
    // Steps 17-18
    try realm.react(start_promise, runtime.Instance, controller_instance, onStartFulfilled, onStartRejected);
}

fn onStartFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const controller = controllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 17.1 Assert: stream is writable or erroring.
    // 17.2 Set controller.[[started]] to true.
    controller.started = true;
    // 17.3 Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller).
    advanceQueueIfNeeded(realm, controller_instance);
}

fn onStartRejected(controller_instance: *runtime.Instance, reason: Value) void {
    const controller = controllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 18.1 Assert: stream is writable or erroring.
    // 18.2 Set controller.[[started]] to true.
    controller.started = true;
    // 18.3 Perform ! WritableStreamDealWithRejection(stream, r).
    dealWithRejection(realm, controller.stream, reason);
}

/// WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller)
fn advanceQueueIfNeeded(realm: Realm, controller_instance: *runtime.Instance) void {
    const controller = controllerSlots(controller_instance);
    const stream = streamSlots(controller.stream);
    // Step 2: If controller.[[started]] is false, return.
    if (!controller.started) return;
    // Step 3: If stream.[[inFlightWriteRequest]] is not undefined, return.
    if (stream.in_flight_write_request != null) return;
    // Steps 4-5: Assert: state is not "closed" or "errored".
    // Step 6: erroring: finish erroring and return.
    if (stream.state == .erroring) {
        finishErroring(realm, controller.stream);
        return;
    }
    // Step 7: If controller.[[queue]] is empty, return.
    if (controller.queue.items.len == 0) return;
    // Steps 8-10: process the value at the head of the queue.
    switch (controller.queue.items[0]) {
        .close_sentinel => processClose(realm, controller_instance),
        .chunk => |c| processWrite(realm, controller_instance, c.value),
    }
}

/// WritableStreamDefaultControllerClearAlgorithms(controller)
pub fn clearAlgorithms(controller: *Controller) void {
    // Steps 1-3: drop the write, close and abort algorithms.
    if (controller.sink) |sink| sink.vtable.deinit(sink.ctx, controller.allocator);
    controller.sink = null;
    // Step 4: drop the size algorithm.
    switch (controller.size_algorithm) {
        .callback => |c| js.dispose(c),
        else => {},
    }
    controller.size_algorithm = .cleared;
}

/// WritableStreamDefaultControllerClose(controller)
fn controllerClose(realm: Realm, controller_instance: *runtime.Instance) void {
    const controller = controllerSlots(controller_instance);
    // Step 1: Perform ! EnqueueValueWithSize(controller, close sentinel, 0).
    controller.queue.append(controller.allocator, .close_sentinel) catch return;
    // Step 2: Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller).
    advanceQueueIfNeeded(realm, controller_instance);
}

/// WritableStreamDefaultControllerError(controller, error)
pub fn controllerError(realm: Realm, controller_instance: *runtime.Instance, err: Value) void {
    const controller = controllerSlots(controller_instance);
    // Step 2: Assert: stream.[[state]] is "writable".
    // Step 3: Perform ! WritableStreamDefaultControllerClearAlgorithms(controller).
    clearAlgorithms(controller);
    // Step 4: Perform ! WritableStreamStartErroring(stream, error).
    startErroring(realm, controller.stream, err);
}

/// WritableStreamDefaultControllerErrorIfNeeded(controller, error)
pub fn controllerErrorIfNeeded(realm: Realm, controller_instance: *runtime.Instance, err: Value) void {
    const controller = controllerSlots(controller_instance);
    if (streamSlots(controller.stream).state == .writable) controllerError(realm, controller_instance, err);
}

/// WritableStreamDefaultControllerGetBackpressure(controller)
fn getBackpressure(controller: *Controller) bool {
    return getDesiredSize(controller) <= 0;
}

/// WritableStreamDefaultControllerGetChunkSize(controller, chunk)
fn getChunkSize(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) f64 {
    const controller = controllerSlots(controller_instance);
    const size_fn = switch (controller.size_algorithm) {
        .one => return 1,
        // Step 1: undefined once cleared; the stream is no longer writable.
        .cleared => return 1,
        .callback => |c| c,
    };
    // Step 2: Let returnValue be the result of performing the size algorithm.
    const completion = realm.call(size_fn, null, &.{chunk}) catch return 1;
    defer completion.deinit();
    switch (completion) {
        .normal => |v| return toNumber(realm, v),
        // Step 3: an abrupt completion errors the stream and counts as 1.
        .thrown => |e| {
            controllerErrorIfNeeded(realm, controller_instance, e);
            return 1;
        },
    }
}

/// The size callback's return value as a WebIDL `unrestricted double`.
/// Known gap: V8's ToNumber on an object whose valueOf throws leaves that
/// exception pending rather than completing abruptly into step 3 above.
fn toNumber(realm: Realm, value: Value) f64 {
    return @import("v8").ffi.v8_Value_NumberValue(value, realm.context);
}

/// WritableStreamDefaultControllerGetDesiredSize(controller)
fn getDesiredSize(controller: *const Controller) f64 {
    return controller.strategy_hwm - controller.queue_total_size;
}

/// WritableStreamDefaultControllerProcessClose(controller)
fn processClose(realm: Realm, controller_instance: *runtime.Instance) void {
    const controller = controllerSlots(controller_instance);
    const stream_instance = controller.stream;
    const stream = streamSlots(stream_instance);
    // Step 2: Perform ! WritableStreamMarkCloseRequestInFlight(stream).
    markCloseRequestInFlight(stream);
    // Step 3: Perform ! DequeueValue(controller).
    _ = dequeueValue(controller);
    // Step 4: Assert: controller.[[queue]] is empty.
    // Step 5: Let sinkClosePromise be the result of performing the close algorithm.
    const sink_close_promise = blk: {
        const sink = controller.sink orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk sink.vtable.close(sink.ctx, realm, controller_instance);
    } catch return;
    defer js.dispose(sink_close_promise);
    // Step 6: Perform ! WritableStreamDefaultControllerClearAlgorithms(controller).
    clearAlgorithms(controller);
    // Steps 7-8
    realm.react(sink_close_promise, runtime.Instance, stream_instance, onSinkCloseFulfilled, onSinkCloseRejected) catch {};
}

fn onSinkCloseFulfilled(stream_instance: *runtime.Instance, _: Value) void {
    const realm = Realm.of(stream_instance) catch return;
    // 7.1 Perform ! WritableStreamFinishInFlightClose(stream).
    finishInFlightClose(realm, stream_instance);
}

fn onSinkCloseRejected(stream_instance: *runtime.Instance, reason: Value) void {
    const realm = Realm.of(stream_instance) catch return;
    // 8.1 Perform ! WritableStreamFinishInFlightCloseWithError(stream, reason).
    finishInFlightCloseWithError(realm, stream_instance, reason);
}

/// WritableStreamDefaultControllerProcessWrite(controller, chunk)
fn processWrite(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) void {
    const controller = controllerSlots(controller_instance);
    const stream = streamSlots(controller.stream);
    // Step 2: Perform ! WritableStreamMarkFirstWriteRequestInFlight(stream).
    markFirstWriteRequestInFlight(stream);
    // Step 3: Let sinkWritePromise be the result of performing the write
    // algorithm, passing in chunk.
    const sink_write_promise = blk: {
        const sink = controller.sink orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk sink.vtable.write(sink.ctx, realm, controller_instance, chunk);
    } catch return;
    defer js.dispose(sink_write_promise);
    // Steps 4-5
    realm.react(sink_write_promise, runtime.Instance, controller_instance, onSinkWriteFulfilled, onSinkWriteRejected) catch {};
}

fn onSinkWriteFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const controller = controllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    const stream = streamSlots(controller.stream);
    // 4.1 Perform ! WritableStreamFinishInFlightWrite(stream).
    finishInFlightWrite(realm, stream);
    // 4.2-4.3 Let state be stream.[[state]]; assert writable or erroring.
    const state = stream.state;
    // 4.4 Perform ! DequeueValue(controller).
    switch (dequeueValue(controller)) {
        .chunk => |c| js.dispose(c.value),
        .close_sentinel => {},
    }
    // 4.5 Publish backpressure while still writable and not closing.
    if (!closeQueuedOrInFlight(stream) and state == .writable) {
        updateBackpressure(realm, stream, getBackpressure(controller));
    }
    // 4.6 Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller).
    advanceQueueIfNeeded(realm, controller_instance);
}

fn onSinkWriteRejected(controller_instance: *runtime.Instance, reason: Value) void {
    const controller = controllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 5.1 If stream.[[state]] is "writable", clear the algorithms.
    if (streamSlots(controller.stream).state == .writable) clearAlgorithms(controller);
    // 5.2 Perform ! WritableStreamFinishInFlightWriteWithError(stream, reason).
    finishInFlightWriteWithError(realm, controller.stream, reason);
}

/// WritableStreamDefaultControllerWrite(controller, chunk, chunkSize)
fn controllerWrite(realm: Realm, controller_instance: *runtime.Instance, chunk: Value, chunk_size: f64) void {
    const controller = controllerSlots(controller_instance);
    // Step 1: Let enqueueResult be EnqueueValueWithSize(controller, chunk, chunkSize).
    // EnqueueValueWithSize steps 2-3: a size that is negative, NaN or +∞ is a
    // RangeError.
    if (!isNonNegativeNumber(chunk_size) or std.math.isInf(chunk_size)) {
        // Step 2: an abrupt completion errors the stream if needed.
        const err = realm.rangeError("The chunk size must be a finite, non-negative number") catch return;
        defer js.dispose(err);
        controllerErrorIfNeeded(realm, controller_instance, err);
        return;
    }
    const value = js.clone(chunk) catch return;
    controller.queue.append(controller.allocator, .{ .chunk = .{ .value = value, .size = chunk_size } }) catch {
        js.dispose(value);
        return;
    };
    controller.queue_total_size += chunk_size;
    // Steps 3-4: publish backpressure while writable and not closing.
    const stream = streamSlots(controller.stream);
    if (!closeQueuedOrInFlight(stream) and stream.state == .writable) {
        updateBackpressure(realm, stream, getBackpressure(controller));
    }
    // Step 5: Perform ! WritableStreamDefaultControllerAdvanceQueueIfNeeded(controller).
    advanceQueueIfNeeded(realm, controller_instance);
}

/// [[AbortSteps]](reason) - § 5.4.4. Returns an owned promise.
fn abortSteps(realm: Realm, controller_instance: *runtime.Instance, reason: Value) js.Error!Value {
    const controller = controllerSlots(controller_instance);
    // Step 1: Let result be the result of performing the abort algorithm.
    const result = blk: {
        const sink = controller.sink orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk sink.vtable.abort(sink.ctx, realm, controller_instance, reason);
    };
    // Step 2: Perform ! WritableStreamDefaultControllerClearAlgorithms(controller).
    clearAlgorithms(controller);
    // Step 3: Return result.
    return result;
}

/// [[ErrorSteps]]() - § 5.4.4: Perform ! ResetQueue(this).
fn errorSteps(controller: *Controller) void {
    resetQueue(controller);
}

/// Signal abort on controller.[[abortController]] with reason (DOM § 3.2).
fn signalAbort(realm: Realm, controller: *Controller, reason: Value) void {
    const ac = controller.abort_controller orelse return;
    // The signal keeps the reason; hand it its own handle.
    const owned = js.clone(reason) catch return;
    _ = realm;
    const arg = webidl.Opt(runtime.JSValue).passed(.{ .handle = .{ .ptr = @ptrCast(owned), .handle_scope = .global } });
    interfaces.AbortController.call_abort(ac, arg) catch {};
}

// ============================================================================
// CreateWritableStream (§ 5.5.1), for engine-provided sinks
// ============================================================================

/// CreateWritableStream(startAlgorithm, writeAlgorithm, closeAlgorithm,
/// abortAlgorithm, highWaterMark, sizeAlgorithm). The stream is wrapped
/// before it is returned, so the wrapper cache owns it like one script made.
pub fn createWritableStream(realm: Realm, ctx: runtime.Context, sink: Sink, hwm: f64, size: SizeAlgorithm) !*runtime.Instance {
    // Steps 2-3: Let stream be a new WritableStream; InitializeWritableStream.
    const stream_instance = try newStream(ctx);
    _ = try realm.wrap(stream_instance);
    // Steps 4-5: a new controller, set up with the given algorithms.
    const controller_instance = try newController(ctx, stream_instance, sink, hwm, size);
    try setUpController(realm, stream_instance, controller_instance);
    return stream_instance;
}

/// Algorithms for a sink that accepts everything and does nothing: start
/// returns undefined and every other algorithm a promise resolved with
/// undefined. Used where the engine has no sink yet.
pub const noop_sink = Sink{ .ctx = null, .vtable = &noop_vtable };

const noop_vtable = Sink.VTable{
    .start = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
            return .{ .normal = try realm.undefinedValue() };
        }
    }.f,
    .write = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance, _: Value) js.Error!Value {
            return realm.promiseResolvedWithUndefined();
        }
    }.f,
    .close = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
            return realm.promiseResolvedWithUndefined();
        }
    }.f,
    .abort = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance, _: Value) js.Error!Value {
            return realm.promiseResolvedWithUndefined();
        }
    }.f,
    .deinit = struct {
        fn f(_: ?*anyopaque, _: std.mem.Allocator) void {}
    }.f,
};
