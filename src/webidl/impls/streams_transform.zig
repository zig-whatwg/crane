//! Transform streams: the internal slots and abstract operations of WHATWG
//! Streams § 6 (TransformStream, TransformStreamDefaultController), and
//! § 9.3's "set up a TransformStream" for other specifications.
//!
//! The writable side is a WritableStream whose sink is this file's default
//! sink algorithms (§ 6.4.3); the readable side is a ReadableStream whose
//! source is the default source algorithms (§ 6.4.4). Step numbers are the
//! spec's.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");
const srd = @import("streams_readable.zig");

const Value = js.Value;
const Realm = js.Realm;
const Deferred = js.Deferred;

// ============================================================================
// Internal slots
// ============================================================================

/// § 6.2.2 TransformStream internal slots.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    /// [[backpressure]]; null is the spec's initial undefined.
    backpressure: ?bool = null,
    backpressure_change_promise: ?Deferred = null,
    controller: ?*runtime.Instance = null,
    readable: ?*runtime.Instance = null,
    writable: ?*runtime.Instance = null,
    /// The startPromise both sides' start algorithms return.
    start_promise: ?Deferred = null,

    pub fn deinit(self: *Stream) void {
        if (self.backpressure_change_promise) |d| d.deinit();
        if (self.start_promise) |d| d.deinit();
        self.allocator.destroy(self);
    }
};

/// The transformer's algorithms (§ 6.3.2 [[transformAlgorithm]] etc.).
/// Each returns an owned promise.
pub const Transformer = struct {
    ctx: ?*anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        transform: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, chunk: Value) js.Error!Value,
        flush: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value,
        cancel: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value,
        deinit: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator) void,
    };
};

/// § 6.3.2 TransformStreamDefaultController internal slots.
pub const Controller = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    /// Null once ClearAlgorithms has run.
    transformer: ?Transformer,
    finish_promise: ?Deferred = null,

    pub fn deinit(self: *Controller) void {
        clearAlgorithms(self);
        if (self.finish_promise) |d| d.deinit();
        self.allocator.destroy(self);
    }
};

pub fn streamOf(instance: *runtime.Instance) ?*Stream {
    const state = instance.stateAs(interfaces.TransformStream.State) orelse return null;
    return state.own._internal;
}

pub fn controllerOf(instance: *runtime.Instance) ?*Controller {
    const state = instance.stateAs(interfaces.TransformStreamDefaultController.State) orelse return null;
    return state.own._internal;
}

fn streamSlots(instance: *runtime.Instance) *Stream {
    return streamOf(instance).?;
}

// ============================================================================
// Transformer from an author object (§ 6.4.2 SetUpTransformStreamDefault-
// ControllerFromTransformer steps 2-7)
// ============================================================================

/// The Transformer dictionary, converted, plus the object itself as the
/// callbacks' "callback this value".
pub const JsTransformer = struct {
    this: ?Value = null,
    start: ?Value = null,
    transform: ?Value = null,
    flush: ?Value = null,
    cancel: ?Value = null,

    fn release(self: *JsTransformer) void {
        js.disposeOptional(&self.this);
        js.disposeOptional(&self.start);
        js.disposeOptional(&self.transform);
        js.disposeOptional(&self.flush);
        js.disposeOptional(&self.cancel);
    }

    fn deinitErased(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *JsTransformer = @ptrCast(@alignCast(ctx.?));
        self.release();
        allocator.destroy(self);
    }

    fn transformErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, chunk: Value) js.Error!Value {
        const self: *JsTransformer = @ptrCast(@alignCast(ctx.?));
        // Step 5: invoke transform with « chunk, controller ».
        const f = self.transform orelse return defaultTransform(realm, controller, chunk);
        return realm.promiseCall(f, self.this, &.{ chunk, try realm.wrap(controller) });
    }

    fn flushErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value {
        const self: *JsTransformer = @ptrCast(@alignCast(ctx.?));
        // Steps 3 and 6: invoke flush with « controller ».
        const f = self.flush orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(f, self.this, &.{try realm.wrap(controller)});
    }

    fn cancelErased(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
        const self: *JsTransformer = @ptrCast(@alignCast(ctx.?));
        // Steps 4 and 7: invoke cancel with « reason ».
        const f = self.cancel orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(f, self.this, &.{reason});
    }

    pub const vtable = Transformer.VTable{
        .transform = transformErased,
        .flush = flushErased,
        .cancel = cancelErased,
        .deinit = deinitErased,
    };
};

/// Step 2: the default transformAlgorithm - enqueue the chunk unchanged.
fn defaultTransform(realm: Realm, controller: *runtime.Instance, chunk: Value) js.Error!Value {
    // 2.1 Let result be TransformStreamDefaultControllerEnqueue(controller, chunk).
    if (try controllerEnqueueCompletion(realm, controller, chunk)) |e| {
        defer js.dispose(e);
        // 2.2 An abrupt completion is a rejected promise.
        return realm.promiseRejectedWith(e);
    }
    // 2.3
    return realm.promiseResolvedWithUndefined();
}

/// Convert `transformer` to the Transformer dictionary (members in
/// lexicographic order: cancel, flush, readableType, start, transform,
/// writableType). Steps 3-4 of the constructor: a present readableType or
/// writableType is a RangeError.
pub fn convertTransformer(realm: Realm, allocator: std.mem.Allocator, object: ?Value) js.Error!*JsTransformer {
    const dict = try allocator.create(JsTransformer);
    dict.* = .{};
    errdefer {
        dict.release();
        allocator.destroy(dict);
    }
    const obj = object orelse return dict;
    dict.this = try js.clone(obj);
    if (!js.isObject(obj)) return dict;
    dict.cancel = try js.getCallbackMember(realm, obj, "cancel");
    dict.flush = try js.getCallbackMember(realm, obj, "flush");
    if (try js.getMember(realm, obj, "readableType")) |v| {
        js.dispose(v);
        const e = try realm.rangeError("Invalid readableType specified");
        defer js.dispose(e);
        return realm.throwValue(e);
    }
    dict.start = try js.getCallbackMember(realm, obj, "start");
    dict.transform = try js.getCallbackMember(realm, obj, "transform");
    if (try js.getMember(realm, obj, "writableType")) |v| {
        js.dispose(v);
        const e = try realm.rangeError("Invalid writableType specified");
        defer js.dispose(e);
        return realm.throwValue(e);
    }
    return dict;
}

// ============================================================================
// § 6.4.1 Working with transform streams
// ============================================================================

pub fn newStream(ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.TransformStream.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Stream);
    slots.* = .{ .allocator = ctx.allocator };
    instance.getState(interfaces.TransformStream.State).own._internal = slots;
    return instance;
}

/// InitializeTransformStream(stream, startPromise, writableHighWaterMark,
/// writableSizeAlgorithm, readableHighWaterMark, readableSizeAlgorithm).
/// `start_promise` becomes the stream's.
pub fn initialize(
    realm: Realm,
    stream_instance: *runtime.Instance,
    start_promise: Deferred,
    writable_hwm: f64,
    writable_size: sw.SizeAlgorithm,
    readable_hwm: f64,
    readable_size: sw.SizeAlgorithm,
) !void {
    const stream = streamSlots(stream_instance);
    stream.start_promise = start_promise;
    // The stream is wrapped first: both sides point at it through their
    // algorithms, and the wrapper cache keeps it for the realm.
    _ = try realm.wrap(stream_instance);
    // Steps 1-5: the writable side, whose sink is this stream.
    stream.writable = try sw.createWritableStream(realm, stream_instance.ctx, .{ .ctx = stream_instance, .vtable = &sink_vtable }, writable_hwm, writable_size);
    // Steps 6-8: the readable side, whose source is this stream.
    stream.readable = try srd.createReadableStream(realm, stream_instance.ctx, .{ .ctx = stream_instance, .vtable = &source_vtable }, readable_hwm, readable_size);
    // Steps 9-10: backpressure starts undefined and is set to true.
    stream.backpressure = null;
    setBackpressure(realm, stream, true);
    // Step 11: Set stream.[[controller]] to undefined.
    stream.controller = null;
}

/// TransformStreamError(stream, e)
pub fn errorStream(realm: Realm, stream_instance: *runtime.Instance, e: Value) void {
    const stream = streamSlots(stream_instance);
    // Step 1: Perform ! ReadableStreamDefaultControllerError(stream.[[readable]].[[controller]], e).
    if (stream.readable) |r| srd.defaultControllerError(realm, srd.streamOf(r).?.controller.?, e);
    // Step 2: Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, e).
    errorWritableAndUnblockWrite(realm, stream_instance, e);
}

/// TransformStreamErrorWritableAndUnblockWrite(stream, e)
fn errorWritableAndUnblockWrite(realm: Realm, stream_instance: *runtime.Instance, e: Value) void {
    const stream = streamSlots(stream_instance);
    // Step 1: Perform ! TransformStreamDefaultControllerClearAlgorithms(stream.[[controller]]).
    if (stream.controller) |c| clearAlgorithms(controllerOf(c).?);
    // Step 2: Perform ! WritableStreamDefaultControllerErrorIfNeeded(stream.[[writable]].[[controller]], e).
    if (stream.writable) |w| sw.controllerErrorIfNeeded(realm, sw.streamOf(w).?.controller.?, e);
    // Step 3: Perform ! TransformStreamUnblockWrite(stream).
    unblockWrite(realm, stream);
}

/// TransformStreamSetBackpressure(stream, backpressure)
fn setBackpressure(realm: Realm, stream: *Stream, backpressure: bool) void {
    // Step 2: resolve the current change promise.
    if (stream.backpressure_change_promise) |d| {
        d.resolveUndefined(realm);
        d.deinit();
    }
    // Step 3: Set stream.[[backpressureChangePromise]] to a new promise.
    stream.backpressure_change_promise = Deferred.init(realm) catch null;
    // Step 4
    stream.backpressure = backpressure;
}

/// TransformStreamUnblockWrite(stream)
fn unblockWrite(realm: Realm, stream: *Stream) void {
    if (stream.backpressure == true) setBackpressure(realm, stream, false);
}

// ============================================================================
// § 6.4.2 Default controllers
// ============================================================================

pub fn newController(ctx: runtime.Context, stream_instance: *runtime.Instance, transformer: Transformer) !*runtime.Instance {
    const instance = try interfaces.TransformStreamDefaultController.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Controller);
    slots.* = .{ .allocator = ctx.allocator, .stream = stream_instance, .transformer = transformer };
    instance.getState(interfaces.TransformStreamDefaultController.State).own._internal = slots;
    return instance;
}

/// SetUpTransformStreamDefaultController(stream, controller, ...)
pub fn setUpController(realm: Realm, stream_instance: *runtime.Instance, controller_instance: *runtime.Instance) !void {
    _ = try realm.wrap(controller_instance);
    // Steps 3-7: link them; the algorithms are in the controller's slots.
    streamSlots(stream_instance).controller = controller_instance;
}

/// TransformStreamDefaultControllerClearAlgorithms(controller)
fn clearAlgorithms(c: *Controller) void {
    if (c.transformer) |t| t.vtable.deinit(t.ctx, c.allocator);
    c.transformer = null;
}

/// TransformStreamDefaultControllerEnqueue(controller, chunk), returning its
/// abrupt completion's value (owned) instead of throwing it.
pub fn controllerEnqueueCompletion(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) js.Error!?Value {
    const c = controllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    // Step 2: Let readableController be stream.[[readable]].[[controller]].
    const readable_controller = srd.streamOf(stream.readable.?).?.controller.?;
    // Step 3: a readable side that cannot take a chunk is a TypeError.
    if (!srd.defaultCanCloseOrEnqueue(srd.defaultControllerOf(readable_controller).?)) {
        return try realm.typeError("Readable side is not in a state that permits enqueue");
    }
    // Step 4: Let enqueueResult be ReadableStreamDefaultControllerEnqueue(readableController, chunk).
    if (try srd.defaultControllerEnqueueCompletion(realm, readable_controller, chunk)) |e| {
        defer js.dispose(e);
        // 5.1 Perform ! TransformStreamErrorWritableAndUnblockWrite(stream, enqueueResult.[[Value]]).
        errorWritableAndUnblockWrite(realm, c.stream, e);
        // 5.2 Throw stream.[[readable]].[[storedError]].
        const stored = srd.streamOf(stream.readable.?).?.stored_error orelse return try js.clone(e);
        return try js.clone(stored);
    }
    // Steps 6-7: publish backpressure.
    const backpressure = srd.defaultHasBackpressure(srd.defaultControllerOf(readable_controller).?);
    if (stream.backpressure == null or backpressure != stream.backpressure.?) setBackpressure(realm, stream, true);
    return null;
}

/// TransformStreamDefaultControllerError(controller, e)
pub fn controllerError(realm: Realm, controller_instance: *runtime.Instance, e: Value) void {
    errorStream(realm, controllerOf(controller_instance).?.stream, e);
}

/// TransformStreamDefaultControllerPerformTransform(controller, chunk). Owned promise.
fn performTransform(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) js.Error!Value {
    const c = controllerOf(controller_instance).?;
    // Step 1: Let transformPromise be the result of the transform algorithm.
    const transform_promise = blk: {
        const t = c.transformer orelse break :blk try realm.promiseResolvedWithUndefined();
        break :blk try t.vtable.transform(t.ctx, realm, controller_instance, chunk);
    };
    defer js.dispose(transform_promise);
    // Step 2: react with rejection steps that error the stream and rethrow.
    const holder = try c.allocator.create(TransformReaction);
    holder.* = .{ .deferred = try Deferred.init(realm), .stream = c.stream, .allocator = c.allocator, .realm = realm };
    const result = try js.clone(holder.deferred.promise);
    realm.react(transform_promise, TransformReaction, holder, TransformReaction.fulfilled, TransformReaction.rejected) catch {
        holder.deferred.resolveUndefined(realm);
        holder.finish();
    };
    return result;
}

const TransformReaction = struct {
    deferred: Deferred,
    stream: *runtime.Instance,
    allocator: std.mem.Allocator,
    realm: Realm,

    fn finish(self: *TransformReaction) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    fn fulfilled(self: *TransformReaction, _: Value) void {
        self.deferred.resolveUndefined(self.realm);
        self.finish();
    }

    fn rejected(self: *TransformReaction, r: Value) void {
        // 2.1 Perform ! TransformStreamError(controller.[[stream]], r).
        errorStream(self.realm, self.stream, r);
        // 2.2 Throw r.
        self.deferred.reject(self.realm, r);
        self.finish();
    }
};

/// TransformStreamDefaultControllerTerminate(controller)
pub fn controllerTerminate(realm: Realm, controller_instance: *runtime.Instance) js.Error!void {
    const c = controllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    // Steps 2-3: close the readable side.
    srd.defaultControllerClose(realm, srd.streamOf(stream.readable.?).?.controller.?);
    // Steps 4-5: error the writable side with a TypeError.
    const e = try realm.typeError("TransformStream terminated");
    defer js.dispose(e);
    errorWritableAndUnblockWrite(realm, c.stream, e);
}

/// ReadableStreamDefaultControllerGetDesiredSize of the readable side.
pub fn controllerDesiredSize(controller_instance: *runtime.Instance) ?f64 {
    const c = controllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    const readable_controller = srd.streamOf(stream.readable.?).?.controller.?;
    return srd.defaultGetDesiredSize(srd.defaultControllerOf(readable_controller).?);
}

// ============================================================================
// § 6.4.3 Default sinks and § 6.4.4 default sources
// ============================================================================

fn startAlgorithm(ctx: ?*anyopaque, _: Realm, _: *runtime.Instance) js.Error!js.Completion {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    // InitializeTransformStream step 1: an algorithm that returns startPromise.
    const d = streamSlots(stream_instance).start_promise.?;
    return .{ .normal = try js.clone(d.promise) };
}

/// TransformStreamDefaultSinkWriteAlgorithm(stream, chunk)
fn sinkWrite(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, chunk: Value) js.Error!Value {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    const stream = streamSlots(stream_instance);
    // Step 2
    const controller = stream.controller.?;
    // Step 3: wait out backpressure first.
    if (stream.backpressure == true) {
        const change = stream.backpressure_change_promise.?;
        const wait = try stream.allocator.create(BackpressureWait);
        wait.* = .{ .deferred = try Deferred.init(realm), .stream = stream_instance, .controller = controller, .chunk = try js.clone(chunk), .allocator = stream.allocator, .realm = realm };
        const result = try js.clone(wait.deferred.promise);
        realm.react(change.promise, BackpressureWait, wait, BackpressureWait.fulfilled, BackpressureWait.rejected) catch {
            wait.finish();
        };
        return result;
    }
    // Step 4
    return performTransform(realm, controller, chunk);
}

const BackpressureWait = struct {
    deferred: Deferred,
    stream: *runtime.Instance,
    controller: *runtime.Instance,
    chunk: Value,
    allocator: std.mem.Allocator,
    realm: Realm,

    fn finish(self: *BackpressureWait) void {
        js.dispose(self.chunk);
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    /// 3.3 fulfillment steps.
    fn fulfilled(self: *BackpressureWait, _: Value) void {
        defer self.finish();
        const realm = self.realm;
        const writable = sw.streamOf(streamSlots(self.stream).writable.?).?;
        // 3.3.3 erroring: throw its stored error.
        if (writable.state == .erroring) {
            self.deferred.reject(realm, writable.stored_error.?);
            return;
        }
        // 3.3.5 Return ! TransformStreamDefaultControllerPerformTransform(controller, chunk).
        const p = performTransform(realm, self.controller, self.chunk) catch {
            self.deferred.resolveUndefined(realm);
            return;
        };
        defer js.dispose(p);
        self.deferred.resolve(realm, p);
    }

    fn rejected(self: *BackpressureWait, r: Value) void {
        self.deferred.reject(self.realm, r);
        self.finish();
    }
};

/// TransformStreamDefaultSinkAbortAlgorithm(stream, reason)
fn sinkAbort(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    return finishWith(realm, stream_instance, .abort, reason);
}

/// TransformStreamDefaultSinkCloseAlgorithm(stream)
fn sinkClose(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    return finishWith(realm, stream_instance, .close, null);
}

/// TransformStreamDefaultSourceCancelAlgorithm(stream, reason)
fn sourceCancel(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    return finishWith(realm, stream_instance, .cancel, reason);
}

/// TransformStreamDefaultSourcePullAlgorithm(stream)
fn sourcePull(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
    const stream_instance: *runtime.Instance = @ptrCast(@alignCast(ctx.?));
    const stream = streamSlots(stream_instance);
    // Step 3: Perform ! TransformStreamSetBackpressure(stream, false).
    setBackpressure(realm, stream, false);
    // Step 4: Return stream.[[backpressureChangePromise]].
    return js.clone(stream.backpressure_change_promise.?.promise);
}

const FinishKind = enum { abort, close, cancel };

/// The three algorithms that settle controller.[[finishPromise]]: the sink's
/// abort (§ 6.4.3) and close, and the source's cancel (§ 6.4.4).
fn finishWith(realm: Realm, stream_instance: *runtime.Instance, kind: FinishKind, reason: ?Value) js.Error!Value {
    const stream = streamSlots(stream_instance);
    const c = controllerOf(stream.controller.?).?;
    // Step 2: already finishing: the same promise.
    if (c.finish_promise) |f| return js.clone(f.promise);
    // Step 4: Let controller.[[finishPromise]] be a new promise.
    c.finish_promise = try Deferred.init(realm);
    // Step 5: Let the algorithm's promise be the result of cancel or flush.
    const p = blk: {
        const t = c.transformer orelse break :blk try realm.promiseResolvedWithUndefined();
        break :blk switch (kind) {
            .abort, .cancel => try t.vtable.cancel(t.ctx, realm, stream.controller.?, reason.?),
            .close => try t.vtable.flush(t.ctx, realm, stream.controller.?),
        };
    };
    defer js.dispose(p);
    // Step 6: Perform ! TransformStreamDefaultControllerClearAlgorithms(controller).
    clearAlgorithms(c);
    // Step 7: react.
    const reaction = try stream.allocator.create(FinishReaction);
    reaction.* = .{ .stream = stream_instance, .kind = kind, .reason = if (reason) |r| try js.clone(r) else null, .allocator = stream.allocator, .realm = realm };
    realm.react(p, FinishReaction, reaction, FinishReaction.fulfilled, FinishReaction.rejected) catch reaction.finish();
    // Step 8: Return controller.[[finishPromise]].
    return js.clone(c.finish_promise.?.promise);
}

const FinishReaction = struct {
    stream: *runtime.Instance,
    kind: FinishKind,
    reason: ?Value,
    allocator: std.mem.Allocator,
    realm: Realm,

    fn finish(self: *FinishReaction) void {
        js.disposeOptional(&self.reason);
        self.allocator.destroy(self);
    }

    fn finishPromise(self: *FinishReaction) ?Deferred {
        const stream = streamSlots(self.stream);
        return controllerOf(stream.controller.?).?.finish_promise;
    }

    /// 7.1: the algorithm's promise was fulfilled.
    fn fulfilled(self: *FinishReaction, _: Value) void {
        defer self.finish();
        const realm = self.realm;
        const stream = streamSlots(self.stream);
        const finish_promise = self.finishPromise() orelse return;
        switch (self.kind) {
            .abort, .close => {
                const readable = srd.streamOf(stream.readable.?).?;
                // 7.1.1 An errored readable side rejects with its error.
                if (readable.state == .errored) return finish_promise.reject(realm, readable.stored_error.?);
                // 7.1.2 Otherwise error (abort) or close (close) it, and resolve.
                const readable_controller = readable.controller.?;
                if (self.kind == .abort) {
                    srd.defaultControllerError(realm, readable_controller, self.reason.?);
                } else {
                    srd.defaultControllerClose(realm, readable_controller);
                }
                finish_promise.resolveUndefined(realm);
            },
            .cancel => {
                const writable = sw.streamOf(stream.writable.?).?;
                // 7.1.1 An errored writable side rejects with its error.
                if (writable.state == .errored) return finish_promise.reject(realm, writable.stored_error.?);
                // 7.1.2 Otherwise error it if needed, unblock, and resolve.
                sw.controllerErrorIfNeeded(realm, writable.controller.?, self.reason.?);
                unblockWrite(realm, stream);
                finish_promise.resolveUndefined(realm);
            },
        }
    }

    /// 7.2: the algorithm's promise was rejected with r.
    fn rejected(self: *FinishReaction, r: Value) void {
        defer self.finish();
        const realm = self.realm;
        const stream = streamSlots(self.stream);
        const finish_promise = self.finishPromise() orelse return;
        switch (self.kind) {
            .abort, .close => srd.defaultControllerError(realm, srd.streamOf(stream.readable.?).?.controller.?, r),
            .cancel => {
                sw.controllerErrorIfNeeded(realm, sw.streamOf(stream.writable.?).?.controller.?, r);
                unblockWrite(realm, stream);
            },
        }
        finish_promise.reject(realm, r);
    }
};

const sink_vtable = sw.Sink.VTable{
    .start = startAlgorithm,
    .write = sinkWrite,
    .close = sinkClose,
    .abort = sinkAbort,
    .deinit = noDeinit,
};

const source_vtable = srd.Source.VTable{
    .start = startAlgorithm,
    .pull = sourcePull,
    .cancel = sourceCancel,
    .deinit = noDeinit,
};

fn noDeinit(_: ?*anyopaque, _: std.mem.Allocator) void {}

// ============================================================================
// § 9.3 "Set up a TransformStream" for other specifications
// ============================================================================

/// Set up a new TransformStream whose algorithms are `transformer`'s: HWM 1
/// and 0, size 1, startPromise resolved with undefined. The stream is
/// wrapped, so the wrapper cache owns it.
pub fn setUp(realm: Realm, ctx: runtime.Context, transformer: Transformer) !*runtime.Instance {
    const stream_instance = try newStream(ctx);
    // Step 8: Let startPromise be a promise resolved with undefined.
    const start = try Deferred.initResolved(realm);
    // Step 9: InitializeTransformStream(stream, startPromise, 1, size 1, 0, size 1).
    try initialize(realm, stream_instance, start, 1, .one, 0, .one);
    // Steps 10-11: a new controller with the given algorithms.
    const controller = try newController(ctx, stream_instance, transformer);
    try setUpController(realm, stream_instance, controller);
    return stream_instance;
}

/// "Enqueue" `chunk` into a TransformStream (§ 9.3). Returns the abrupt
/// completion's value (owned), if any.
pub fn enqueue(realm: Realm, stream_instance: *runtime.Instance, chunk: Value) js.Error!?Value {
    return controllerEnqueueCompletion(realm, streamSlots(stream_instance).controller.?, chunk);
}
