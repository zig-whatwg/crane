//! Transferable streams: the transfer steps and transfer-receiving steps of
//! ReadableStream, WritableStream and TransformStream (WHATWG Streams 4.2.6,
//! 5.2.5, 6.2.5) and the cross-realm transforms they are made of (8.2).
//! Every carrier reaches them through dom.transferables, the one shared
//! transfer step; step numbers are the spec's.
//!
//! A transferred stream is an identity transform with its two halves in two
//! realms - possibly two agents on two threads - joined by a MessageChannel:
//! the sending realm pipes the original into a cross-realm writable on
//! port1; port2 travels as the data holder's [[port]] (its channel end,
//! dom.port_channels.TransferDataHolder), and the receiving realm sets up a
//! cross-realm readable on it (and the other way round for a WritableStream).
//!
//! The ports are real MessagePorts that script never sees, as in Blink
//! (core/streams/transferable_streams.cc: CreateCrossRealmTransformWritable /
//! ...Readable over a MessagePort, with native message and messageerror
//! listeners) and WebKit (Modules/streams/StreamTransferUtilities.cpp:
//! CrossRealmReadableStreamSource / CrossRealmWritableStreamSink, each
//! holding its MessagePort and installing a native message handler): every
//! message goes the message port post message steps' way - serialized in the
//! sending realm, queued on the entangled end, deserialized by the receiving
//! port's own task (a failure is its messageerror) - and the port's handlers
//! are native steps (dom.message_ports.NativeReceiver) instead of event
//! listeners.
//!
//! Lifetime, Blink's model (its CrossRealmTransform classes Trace() the port
//! and the controller; MessagePort::HasPendingActivity keeps a started,
//! entangled port): a port whose queue is enabled and which is entangled is
//! kept while its channel lives (MessagePort's pending activity, HTML 9.4.6),
//! and keeps the controller its handler runs through a traced edge; the
//! controller keeps the port the same way (js.slot.port,
//! js.slot.cross_realm_controller), so a stream script dropped is collected
//! with its port once the port is disentangled. The native state both sides
//! share - the port, the controller, a writable's backpressurePromise - is
//! an `Endpoint`, counted: one reference for the stream's algorithms (given
//! back by ClearAlgorithms or the controller's teardown), one for the port
//! (given back when it goes), one per reaction in flight. Neither side reads
//! the other in its teardown, so a realm's end may free them in any order.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const sw = @import("streams_writable.zig");
const st = @import("streams_transform.zig");
const message_ports = @import("message_ports.zig");
const port_channels = @import("port_channels.zig");

const Value = js.Value;
const Realm = js.Realm;
const Deferred = js.Deferred;
const End = port_channels.End;
const TransferDataHolder = port_channels.TransferDataHolder;

// ============================================================================
// The transfer steps (4.2.6, 5.2.5, 6.2.5)
// ============================================================================

/// Whether `instance` is a stream - a transferable object (HTML 2.7.8 step
/// 2.1). Its [[Detached]] is asked by `transfer`, at step 5.2's place.
pub fn transferableState(instance: *runtime.Instance) runtime.TransferableState {
    if (srd.streamOf(instance) != null or sw.streamOf(instance) != null or st.streamOf(instance) != null) return .transferable;
    return .not_transferable;
}

/// StructuredSerializeWithTransfer steps 5.2-5.6 for a stream in the
/// transfer list, in `realm` (the current realm): refused when detached
/// (5.2), its interface's transfer steps (5.5), and [[Detached]] set (5.6).
/// error.DataCloneError for anything that is not a stream or that its steps
/// refuse.
pub fn transfer(realm_ctx: runtime.Context, instance: *runtime.Instance) !TransferDataHolder {
    const realm = Realm.ofContext(realm_ctx) catch return error.DataCloneError;
    if (srd.streamOf(instance)) |stream| {
        if (stream.detached) return error.DataCloneError;
        const end = try transferReadable(realm, instance);
        stream.detached = true;
        return .{ .readable_stream = end };
    }
    if (sw.streamOf(instance)) |stream| {
        if (stream.detached) return error.DataCloneError;
        const end = try transferWritable(realm, instance);
        stream.detached = true;
        return .{ .writable_stream = end };
    }
    if (st.streamOf(instance)) |stream| {
        if (stream.detached) return error.DataCloneError;
        const holder = try transferTransform(realm, stream);
        stream.detached = true;
        return holder;
    }
    return error.DataCloneError;
}

/// ReadableStream's transfer steps (4.2.6), given `value`: dataHolder's
/// [[port]], the channel end of port2. OWNED by the caller.
fn transferReadable(realm: Realm, value: *runtime.Instance) !*End {
    // 1. If ! IsReadableStreamLocked(value) is true, throw a DataCloneError.
    if (srd.isLocked(srd.streamOf(value).?)) return error.DataCloneError;
    // 2-4. port1 and port2, new MessagePorts of the current realm, entangled:
    // a new channel's two ends.
    const channel = try port_channels.Channel.create(realm.ctx.allocator);
    const port2 = channel.end(1);
    errdefer port2.discard();
    // 5-6. writable, a new WritableStream, and
    // SetUpCrossRealmTransformWritable(writable, port1).
    const writable = try setUpCrossRealmTransformWritable(realm, channel.end(0));
    // 7-8. promise = ! ReadableStreamPipeTo(value, writable, false, false,
    // false); promise.[[PromiseIsHandled]] = true.
    const promise = try srd.pipeTo(realm, value, writable, false, false, false, null);
    engine.markPromiseAsHandled(realm.ctx, promise.value);
    js.dispose(promise);
    // 9. dataHolder.[[port]] = ! StructuredSerializeWithTransfer(port2,
    // « port2 »): all it carries is port2's end - its queue and its
    // entanglement - as a MessagePort's transfer steps ship it. Port2 needs
    // no MessagePort object of its own here: one made and transferred in the
    // same step is detached before anything can reach it.
    return port2;
}

/// WritableStream's transfer steps (5.2.5), given `value`: dataHolder's
/// [[port]]. OWNED by the caller.
fn transferWritable(realm: Realm, value: *runtime.Instance) !*End {
    // 1. If ! IsWritableStreamLocked(value) is true, throw a DataCloneError.
    if (sw.isLocked(sw.streamOf(value).?)) return error.DataCloneError;
    // 2-4. port1 and port2, entangled.
    const channel = try port_channels.Channel.create(realm.ctx.allocator);
    const port2 = channel.end(1);
    errdefer port2.discard();
    // 5-6. readable, a new ReadableStream, and
    // SetUpCrossRealmTransformReadable(readable, port1).
    const readable = try setUpCrossRealmTransformReadable(realm, channel.end(0));
    // 7-8. promise = ! ReadableStreamPipeTo(readable, value, false, false,
    // false); promise.[[PromiseIsHandled]] = true.
    const promise = try srd.pipeTo(realm, readable, value, false, false, false, null);
    engine.markPromiseAsHandled(realm.ctx, promise.value);
    js.dispose(promise);
    // 9. dataHolder.[[port]]: port2's end.
    return port2;
}

/// TransformStream's transfer steps (6.2.5), given `stream`'s slots.
fn transferTransform(realm: Realm, stream: *st.Stream) !TransferDataHolder {
    // 1-2. readable and writable, its two sides.
    const readable = stream.readable orelse return error.DataCloneError;
    const writable = stream.writable orelse return error.DataCloneError;
    const readable_slots = srd.streamOf(readable).?;
    const writable_slots = sw.streamOf(writable).?;
    // 3-4. Either side locked is a DataCloneError - both are checked before
    // either is transferred, so neither gets locked by a refused transfer.
    if (srd.isLocked(readable_slots)) return error.DataCloneError;
    if (sw.isLocked(writable_slots)) return error.DataCloneError;
    // 5. dataHolder.[[readable]] = ! StructuredSerializeWithTransfer(readable,
    // « readable »): the side's own transfer, [[Detached]] included. A side
    // transferred before, whose pipe has since let it go, is detached.
    if (readable_slots.detached or writable_slots.detached) return error.DataCloneError;
    const readable_end = try transferReadable(realm, readable);
    readable_slots.detached = true;
    errdefer readable_end.discard();
    // 6. dataHolder.[[writable]], the same for writable.
    const writable_end = try transferWritable(realm, writable);
    writable_slots.detached = true;
    return .{ .transform_stream = .{ .readable = readable_end, .writable = writable_end } };
}

// ============================================================================
// The transfer-receiving steps
// ============================================================================

/// ReadableStream's transfer-receiving steps (4.2.6) in `realm_ctx` (the
/// current realm), given dataHolder.[[port]] (`end`, taken - also on
/// failure): value, a new ReadableStream of the realm, wrapped.
pub fn receiveReadable(realm_ctx: runtime.Context, end: *End) !*runtime.Instance {
    const realm = Realm.ofContext(realm_ctx) catch |err| {
        end.discard();
        return err;
    };
    // 1-2. port = StructuredDeserializeWithTransfer(dataHolder.[[port]],
    // the current realm).[[Deserialized]]: a MessagePort of this realm on the
    // end (made by SetUpCrossRealmTransformReadable, which listens on it).
    // 3. Perform ! SetUpCrossRealmTransformReadable(value, port).
    return setUpCrossRealmTransformReadable(realm, end);
}

/// WritableStream's transfer-receiving steps (5.2.5): value, a new
/// WritableStream of the realm on dataHolder.[[port]] (`end`, taken).
pub fn receiveWritable(realm_ctx: runtime.Context, end: *End) !*runtime.Instance {
    const realm = Realm.ofContext(realm_ctx) catch |err| {
        end.discard();
        return err;
    };
    // 1-3, as ReadableStream's, with SetUpCrossRealmTransformWritable.
    return setUpCrossRealmTransformWritable(realm, end);
}

/// TransformStream's transfer-receiving steps (6.2.5), given
/// dataHolder.[[readable]] and [[writable]] (both taken).
pub fn receiveTransform(realm_ctx: runtime.Context, readable_end: *End, writable_end: *End) !*runtime.Instance {
    // 1. readableRecord: the readable side, received in the current realm.
    const readable = receiveReadable(realm_ctx, readable_end) catch |err| {
        writable_end.discard();
        return err;
    };
    // 2. writableRecord: the writable side.
    const writable = try receiveWritable(realm_ctx, writable_end);
    // 3-5. value's [[readable]] and [[writable]] are the two; backpressure,
    // its promise and the controller undefined.
    return st.newWithSides(realm_ctx, readable, writable);
}

// ============================================================================
// Cross-realm transforms (8.2)
// ============================================================================

/// What a cross-realm transform's algorithms and its port's handlers share.
/// Thread-affine: the realm's own thread is the only one that touches it.
const Endpoint = struct {
    allocator: Allocator,
    side: Side,
    /// One for the algorithms, one for the port, one per reaction in flight.
    refs: u32 = 1,
    /// The port the transform listens and posts on - null once it is gone
    /// (`portReleased`): collected with its stream, or its realm ended.
    port: ?*runtime.Instance = null,
    /// The stream's controller, from the moment the controller takes the
    /// algorithms over (`attach`).
    controller: ?*runtime.Instance = null,
    controller_generation: u64 = 0,
    /// SetUpCrossRealmTransformWritable's backpressurePromise; null is
    /// undefined. A writable's only.
    backpressure: ?Deferred = null,

    const Side = enum { readable, writable };

    fn create(allocator: Allocator, side: Side) !*Endpoint {
        const self = try allocator.create(Endpoint);
        self.* = .{ .allocator = allocator, .side = side };
        return self;
    }

    fn retain(self: *Endpoint) *Endpoint {
        self.refs += 1;
        return self;
    }

    fn release(self: *Endpoint) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        if (self.backpressure) |deferred| deferred.deinit();
        self.allocator.destroy(self);
    }

    /// The controller, while it is the one `attach` saw: its realm's end may
    /// have freed it (a teardown net - the port keeps it from the collector).
    fn liveController(self: *Endpoint) ?*runtime.Instance {
        const controller = self.controller orelse return null;
        if (runtime.SlabAllocator.generationOf(controller) != self.controller_generation) return null;
        return controller;
    }

    fn receiver(self: *Endpoint) message_ports.NativeReceiver {
        return .{ .ctx = self, .message = onMessage, .message_error = onMessageError, .released = portReleased };
    }

    /// "Disentangle port."
    fn disentangle(self: *Endpoint) void {
        if (self.port) |port| message_ports.disentangle(port);
    }

    /// PackAndPostMessage(port, type, value): its abrupt completion's value
    /// (owned), or null on a normal completion.
    fn packAndPostMessage(self: *Endpoint, realm: Realm, type_name: []const u8, value: runtime.JSValue) js.Error!?Value {
        // 4. targetPort: none once the port is gone - with its stream, so
        // nothing could see this completion either way.
        const port = self.port orelse return null;
        // 1-3. message = OrdinaryObjectCreate(null) with own data properties
        // type and value. Its prototype here is %Object.prototype%
        // (createDictionaryObject, whose members are CreateDataProperty'd):
        // the object never reaches script - the post below serializes its own
        // properties at once, and the receiving handler reads only those - so
        // no step can tell the two apart.
        const message = engine.createDictionaryObject(realm.ctx, &.{
            .{ .name = "type", .value = runtime.JSValue.fromStringRef(type_name) },
            .{ .name = "value", .value = value },
        }) catch |err| return js.fromEngineError(err);
        defer message.release();
        // 5-6. The message port post message steps providing targetPort,
        // message and «[ "transfer" -> « » ]»; a throw is the completion's.
        var post: Post = .{ .port = port, .message = message.value };
        const thrown = engine.completionOf(realm.ctx, Post.steps, &post) catch |err| return js.fromEngineError(err);
        const exception = thrown orelse return null;
        return Value{ .value = exception.take(), .realm = realm.ctx };
    }

    /// PackAndPostMessageHandlingError(port, type, value).
    fn packAndPostMessageHandlingError(self: *Endpoint, realm: Realm, type_name: []const u8, value: runtime.JSValue) js.Error!?Value {
        // 1. Let result be PackAndPostMessage(port, type, value).
        const result = try self.packAndPostMessage(realm, type_name, value);
        // 2. If result is an abrupt completion, perform !
        // CrossRealmTransformSendError(port, result.[[Value]]).
        if (result) |e| self.sendError(realm, e.value);
        // 3. Return result as a completion record.
        return result;
    }

    /// CrossRealmTransformSendError(port, error): PackAndPostMessage(port,
    /// "error", error), its result discarded.
    fn sendError(self: *Endpoint, realm: Realm, err: runtime.JSValue) void {
        const result = self.packAndPostMessage(realm, "error", err) catch return;
        if (result) |e| js.dispose(e);
    }
};

/// The message port post message steps from the transform's port, as steps
/// engine.completionOf runs.
const Post = struct {
    port: *runtime.Instance,
    message: runtime.JSValue,

    fn steps(data: ?*anyopaque) engine.Error!void {
        const self: *Post = @ptrCast(@alignCast(data.?));
        message_ports.post(self.port, self.message) catch |err| return switch (err) {
            error.DataCloneError => error.DataCloneError,
            error.ExceptionPending => error.ExceptionPending,
            error.OutOfMemory => error.OutOfMemory,
            error.TypeError => error.TypeError,
            else => error.OperationFailed,
        };
    }
};

/// The port is gone: it lets go of the endpoint.
fn portReleased(ctx: *anyopaque) void {
    const self: *Endpoint = @ptrCast(@alignCast(ctx));
    self.port = null;
    self.release();
}

/// SetUpCrossRealmTransformReadable(stream, port) on a new stream of
/// `realm`, its port a new MessagePort of the realm on `end` (taken, also on
/// failure). The stream is wrapped.
fn setUpCrossRealmTransformReadable(realm: Realm, end: *End) !*runtime.Instance {
    const endpoint = Endpoint.create(realm.ctx.allocator, .readable) catch |err| {
        end.discard();
        return err;
    };
    // 3-5. The port's message and messageerror handlers, and its port
    // message queue enabled. Blink orders these steps differently too
    // (CreateReadableStream): no handler can run before this returns - a
    // message is a task of its own.
    const port = message_ports.hidden(realm.ctx, @ptrCast(end), endpoint.retain().receiver()) catch |err| {
        endpoint.refs -= 1;
        endpoint.release();
        return err;
    };
    endpoint.port = port;
    // 1-2, 6-10. InitializeReadableStream(stream), a new controller, and
    // SetUpReadableStreamDefaultController(stream, controller, the
    // algorithms below, 0, size 1). The algorithms' reference is the
    // endpoint's first; CreateReadableStream gives it back on failure.
    return srd.createReadableStream(realm, realm.ctx, .{ .ctx = endpoint, .vtable = &source_vtable }, 0, .one) catch |err| {
        // The port, entangled and enabled, would be kept for its channel.
        message_ports.disentangle(port);
        return err;
    };
}

/// SetUpCrossRealmTransformWritable(stream, port) on a new stream of
/// `realm`, its port on `end` (taken, also on failure). Wrapped.
fn setUpCrossRealmTransformWritable(realm: Realm, end: *End) !*runtime.Instance {
    const endpoint = Endpoint.create(realm.ctx.allocator, .writable) catch |err| {
        end.discard();
        return err;
    };
    // 3. Let backpressurePromise be a new promise.
    endpoint.backpressure = Deferred.init(realm) catch |err| {
        end.discard();
        endpoint.release();
        return err;
    };
    // 4-6. The port's handlers, and its port message queue enabled.
    const port = message_ports.hidden(realm.ctx, @ptrCast(end), endpoint.retain().receiver()) catch |err| {
        endpoint.refs -= 1;
        endpoint.release();
        return err;
    };
    endpoint.port = port;
    // 1-2, 7-12. InitializeWritableStream(stream), a new controller, and
    // SetUpWritableStreamDefaultController(stream, controller, the
    // algorithms below, 1, size 1).
    return sw.createWritableStream(realm, realm.ctx, .{ .ctx = endpoint, .vtable = &sink_vtable }, 1, .one) catch |err| {
        message_ports.disentangle(port);
        return err;
    };
}

/// The controller takes the algorithms over: it and the port keep each
/// other (see the file's header), and the port's handlers reach the
/// controller from here on.
fn attach(ctx: ?*anyopaque, controller: *runtime.Instance) void {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    self.controller = controller;
    self.controller_generation = runtime.SlabAllocator.generationOf(controller);
    const port = self.port orelse return;
    engine.traceChild(controller, port, js.slot.port);
    engine.traceChild(port, controller, js.slot.cross_realm_controller);
}

/// The algorithms are cleared, or their controller is gone.
fn algorithmsDeinit(ctx: ?*anyopaque, _: Allocator) void {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    self.release();
}

/// startAlgorithm (both sides): returns undefined.
fn startAlgorithm(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
    return .{ .normal = try realm.undefinedValue() };
}

// ----------------------------------------------------------------------------
// The port's handlers
// ----------------------------------------------------------------------------

const MessageType = enum { chunk, close, @"error", pull };

/// A message's type and value (SetUpCrossRealmTransformReadable step 3.1-3.5,
/// ...Writable step 4.1-4.5). Null for a message that is not one the other
/// side's transform posts: the spec asserts it never happens, and asks
/// implementations to handle the assertions' failure, as the input may come
/// from an untrusted context - Blink ignores such a message
/// (CrossRealmTransformMessageListener::Invoke: "Invalid message from peer
/// ignored"), as this does.
fn readMessage(realm: Realm, data: runtime.JSValue) ?struct { kind: MessageType, value: engine.Owned } {
    // 2. Assert: data is an Object.
    if (engine.typeOf(realm.ctx, data) != .object) return null;
    // 3. Let type be ! Get(data, "type").
    const type_value = engine.getProperty(realm.ctx, data, "type") catch return null;
    defer type_value.release();
    // 5. Assert: type is a String.
    if (engine.typeOf(realm.ctx, type_value.value) != .string) return null;
    var buffer: [64]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const type_name = engine.convertToDOMString(realm.ctx, type_value.value, fixed.allocator()) catch return null;
    const kind = std.meta.stringToEnum(MessageType, type_name) orelse return null;
    // 4. Let value be ! Get(data, "value").
    const value = engine.getProperty(realm.ctx, data, "value") catch return null;
    return .{ .kind = kind, .value = value };
}

/// The port's message handler (SetUpCrossRealmTransformReadable step 3,
/// ...Writable step 4), with the data of the message, in the port's realm.
fn onMessage(ctx: *anyopaque, data: runtime.JSValue) void {
    const self: *Endpoint = @ptrCast(@alignCast(ctx));
    _ = self.retain();
    defer self.release();
    const controller = self.liveController() orelse return;
    const realm = Realm.of(controller) catch return;
    const message = readMessage(realm, data) orelse return;
    defer message.value.release();
    const value: Value = .{ .value = message.value.value, .realm = realm.ctx };
    switch (self.side) {
        .readable => switch (message.kind) {
            // 3.6 chunk: ! ReadableStreamDefaultControllerEnqueue(controller,
            // value) - its size algorithm is 1, so it completes normally.
            .chunk => if (srd.defaultControllerEnqueueCompletion(realm, controller, value) catch null) |e| js.dispose(e),
            // 3.7 close: ! ReadableStreamDefaultControllerClose(controller);
            // disentangle port.
            .close => {
                srd.defaultControllerClose(realm, controller);
                self.disentangle();
            },
            // 3.8 error: ! ReadableStreamDefaultControllerError(controller,
            // value); disentangle port.
            .@"error" => {
                srd.defaultControllerError(realm, controller, value);
                self.disentangle();
            },
            .pull => {},
        },
        .writable => switch (message.kind) {
            // 4.6 pull: resolve backpressurePromise, if any, and make it
            // undefined.
            .pull => resolveBackpressure(self, realm),
            // 4.7 error: ! WritableStreamDefaultControllerErrorIfNeeded(
            // controller, value), then the same for backpressurePromise.
            .@"error" => {
                sw.controllerErrorIfNeeded(realm, controller, value);
                resolveBackpressure(self, realm);
            },
            .chunk, .close => {},
        },
    }
}

/// The port's messageerror handler (SetUpCrossRealmTransformReadable step 4,
/// ...Writable step 5).
fn onMessageError(ctx: *anyopaque) void {
    const self: *Endpoint = @ptrCast(@alignCast(ctx));
    _ = self.retain();
    defer self.release();
    const controller = self.liveController() orelse return;
    const realm = Realm.of(controller) catch return;
    // 1. Let error be a new "DataCloneError" DOMException.
    const created = engine.createDOMException(realm.ctx, "DataCloneError", "The message could not be deserialized.") catch return;
    defer created.release();
    const err: Value = .{ .value = created.value, .realm = realm.ctx };
    // 2. Perform ! CrossRealmTransformSendError(port, error).
    self.sendError(realm, err.value);
    // 3. Error the controller with error.
    switch (self.side) {
        .readable => srd.defaultControllerError(realm, controller, err),
        .writable => sw.controllerErrorIfNeeded(realm, controller, err),
    }
    // 4. Disentangle port.
    self.disentangle();
}

// ----------------------------------------------------------------------------
// The readable side's algorithms (SetUpCrossRealmTransformReadable 6-10)
// ----------------------------------------------------------------------------

const source_vtable = srd.Source.VTable{
    .start = startAlgorithm,
    .pull = sourcePull,
    .cancel = sourceCancel,
    .deinit = algorithmsDeinit,
    .attach = attach,
};

/// 7. pullAlgorithm.
fn sourcePull(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    // 7.1 Perform ! PackAndPostMessage(port, "pull", undefined).
    if (try self.packAndPostMessage(realm, "pull", .undefined)) |e| js.dispose(e);
    // 7.2 Return a promise resolved with undefined.
    return realm.promiseResolvedWithUndefined();
}

/// 8. cancelAlgorithm, given reason.
fn sourceCancel(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    // 8.1 Let result be PackAndPostMessageHandlingError(port, "error", reason).
    const result = try self.packAndPostMessageHandlingError(realm, "error", reason.value);
    // 8.2 Disentangle port.
    self.disentangle();
    // 8.3-8.4 A promise rejected with an abrupt completion's value, or
    // resolved with undefined - not waiting for the remote source's cancel.
    if (result) |e| {
        defer js.dispose(e);
        return realm.promiseRejectedWith(e);
    }
    return realm.promiseResolvedWithUndefined();
}

// ----------------------------------------------------------------------------
// The writable side's algorithms (SetUpCrossRealmTransformWritable 7-12)
// ----------------------------------------------------------------------------

const sink_vtable = sw.Sink.VTable{
    .start = startAlgorithm,
    .write = sinkWrite,
    .close = sinkClose,
    .abort = sinkAbort,
    .deinit = algorithmsDeinit,
    .attach = attach,
};

/// "Resolve backpressurePromise with undefined; set it to undefined", when
/// it is not undefined (4.6.1, 4.7.2).
fn resolveBackpressure(self: *Endpoint, realm: Realm) void {
    const deferred = self.backpressure orelse return;
    self.backpressure = null;
    deferred.resolveUndefined(realm);
    deferred.deinit();
}

/// 8. writeAlgorithm, given chunk.
fn sinkWrite(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, chunk: Value) js.Error!Value {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    // 8.1 If backpressurePromise is undefined, set it to a promise resolved
    // with undefined.
    if (self.backpressure == null) self.backpressure = try Deferred.initResolved(realm);
    // 8.2 Return the result of reacting to backpressurePromise with the
    // fulfillment steps below: the reaction's own promise, settled by them.
    // The chunk is held until they run (WebKit's sink keeps it strongly over
    // the wait, CrossRealmWritableStreamSink::write; Blink's DoWriteOnResolve
    // traces it).
    const held_chunk = try js.clone(chunk);
    const result = Deferred.init(realm) catch |err| {
        js.dispose(held_chunk);
        return err;
    };
    const task = self.allocator.create(WriteTask) catch |err| {
        result.deinit();
        js.dispose(held_chunk);
        return err;
    };
    task.* = .{ .endpoint = self.retain(), .chunk = held_chunk, .result = result };
    const promise = js.clone(result.promise) catch |err| {
        task.finish();
        return err;
    };
    realm.react(self.backpressure.?.promise, WriteTask, task, WriteTask.fulfilled, WriteTask.rejected, WriteTask.finish) catch |err| {
        js.dispose(promise);
        task.finish();
        return err;
    };
    return promise;
}

/// A write waiting for backpressurePromise (8.2): the chunk, and the promise
/// the write algorithm returned.
const WriteTask = struct {
    endpoint: *Endpoint,
    /// Owned.
    chunk: Value,
    result: Deferred,

    /// 8.2.1-8.2.4, the fulfillment steps.
    fn fulfilled(task: *WriteTask, settled: Value) void {
        defer task.finish();
        const self = task.endpoint;
        const realm = Realm.ofContext(settled.realm) catch return;
        // 8.2.1 Set backpressurePromise to a new promise.
        if (self.backpressure) |old| old.deinit();
        self.backpressure = Deferred.init(realm) catch null;
        // 8.2.2 Let result be PackAndPostMessageHandlingError(port, "chunk",
        // chunk).
        const result = self.packAndPostMessageHandlingError(realm, "chunk", task.chunk.value) catch return;
        // 8.2.3 An abrupt completion: disentangle port; a promise rejected
        // with its value.
        if (result) |e| {
            defer js.dispose(e);
            self.disentangle();
            task.result.reject(realm, e);
            return;
        }
        // 8.2.4 Otherwise a promise resolved with undefined.
        task.result.resolveUndefined(realm);
    }

    /// No rejection steps: the reaction's promise is rejected with the
    /// reason (backpressurePromise is only ever resolved).
    fn rejected(task: *WriteTask, reason: Value) void {
        defer task.finish();
        const realm = Realm.ofContext(reason.realm) catch return;
        task.result.reject(realm, reason);
    }

    /// The end of the wait, run or not (its realm ended first, or the
    /// promise was collected unsettled).
    fn finish(task: *WriteTask) void {
        const self = task.endpoint;
        js.dispose(task.chunk);
        task.result.deinit();
        self.allocator.destroy(task);
        self.release();
    }
};

/// 9. closeAlgorithm.
fn sinkClose(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    // 9.1 Perform ! PackAndPostMessage(port, "close", undefined).
    if (try self.packAndPostMessage(realm, "close", .undefined)) |e| js.dispose(e);
    // 9.2 Disentangle port.
    self.disentangle();
    // 9.3 Return a promise resolved with undefined.
    return realm.promiseResolvedWithUndefined();
}

/// 10. abortAlgorithm, given reason.
fn sinkAbort(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
    const self: *Endpoint = @ptrCast(@alignCast(ctx.?));
    // 10.1 Let result be PackAndPostMessageHandlingError(port, "error", reason).
    const result = try self.packAndPostMessageHandlingError(realm, "error", reason.value);
    // 10.2 Disentangle port.
    self.disentangle();
    // 10.3-10.4
    if (result) |e| {
        defer js.dispose(e);
        return realm.promiseRejectedWith(e);
    }
    return realm.promiseResolvedWithUndefined();
}
