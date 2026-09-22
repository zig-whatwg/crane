//! Readable streams: the internal slots and abstract operations of WHATWG
//! Streams § 4 - ReadableStream, its two readers, its two controllers and
//! ReadableStreamBYOBRequest - plus ReadableStreamPipeTo, the tees and async
//! iteration.
//!
//! The spec's abstract operations reach across all of these classes' slots,
//! so they live here, once, and the impl files are thin IDL shells over them;
//! no impl calls another impl. Step numbers are the spec's.
//!
//! Values and promises go through `streams_js.zig`; see its header for the
//! one-handle-kind rule. Writable-side operations used by pipeTo come from
//! `streams_writable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");
/// DOM § 3.3's hook: pipeTo adds an abort algorithm to its signal.
const abort_algorithms = @import("dom").abort_algorithms;

const Value = js.Value;
const Realm = js.Realm;
const Deferred = js.Deferred;
const ViewKind = js.ViewKind;

// ============================================================================
// Internal slots
// ============================================================================

pub const StreamState = enum { readable, closed, errored };

/// § 4.2.2 ReadableStream internal slots.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    state: StreamState = .readable,
    /// [[storedError]], owned.
    stored_error: ?Value = null,
    /// A ReadableStreamDefaultReader or ReadableStreamBYOBReader instance.
    reader: ?*runtime.Instance = null,
    /// A ReadableStreamDefaultController or ReadableByteStreamController instance.
    controller: ?*runtime.Instance = null,
    disturbed: bool = false,
    returned: ?Value = null,

    pub fn deinit(self: *Stream) void {
        js.disposeOptional(&self.stored_error);
        js.disposeOptional(&self.returned);
        self.allocator.destroy(self);
    }
};

/// § 4.4.2 read request: exactly one of the steps runs, once, and it owns
/// `ctx` from then on. `drop` releases `ctx` when none will (teardown).
pub const ReadRequest = struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        chunk: *const fn (ctx: *anyopaque, realm: Realm, chunk: Value) void,
        close: *const fn (ctx: *anyopaque, realm: Realm) void,
        err: *const fn (ctx: *anyopaque, realm: Realm, e: Value) void,
        drop: *const fn (ctx: *anyopaque) void,
    };
};

/// § 4.5.2 read-into request. `close` receives a view or undefined.
pub const ReadIntoRequest = struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        chunk: *const fn (ctx: *anyopaque, realm: Realm, chunk: Value) void,
        close: *const fn (ctx: *anyopaque, realm: Realm, chunk: ?Value) void,
        err: *const fn (ctx: *anyopaque, realm: Realm, e: Value) void,
        drop: *const fn (ctx: *anyopaque) void,
    };
};

pub const ReaderKind = enum { default, byob };

/// § 4.3.2 / 4.4.2 / 4.5.2 reader internal slots, for both reader classes.
pub const Reader = struct {
    allocator: std.mem.Allocator,
    kind: ReaderKind,
    stream: ?*runtime.Instance = null,
    closed_promise: ?Deferred = null,
    read_requests: std.ArrayList(ReadRequest) = .empty,
    read_into_requests: std.ArrayList(ReadIntoRequest) = .empty,
    returned: ?Value = null,

    pub fn deinit(self: *Reader) void {
        for (self.read_requests.items) |r| r.vtable.drop(r.ctx);
        self.read_requests.deinit(self.allocator);
        for (self.read_into_requests.items) |r| r.vtable.drop(r.ctx);
        self.read_into_requests.deinit(self.allocator);
        if (self.closed_promise) |d| d.deinit();
        js.disposeOptional(&self.returned);
        self.allocator.destroy(self);
    }
};

/// The underlying source's algorithms (§ 4.6.2 [[pullAlgorithm]] etc.):
/// author callbacks or engine-provided ones.
pub const Source = struct {
    ctx: ?*anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// startAlgorithm; a throw is the setup's abrupt completion. Both arms owned.
        start: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!js.Completion,
        /// pullAlgorithm and cancelAlgorithm: owned promises.
        pull: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value,
        cancel: *const fn (ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value,
        deinit: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator) void,
    };
};

pub const QueueItem = struct { value: Value, size: f64 };

/// § 4.6.2 ReadableStreamDefaultController internal slots.
pub const DefaultController = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    /// [[pullAlgorithm]] and [[cancelAlgorithm]]; null once cleared.
    source: ?Source,
    size_algorithm: sw.SizeAlgorithm = .one,
    strategy_hwm: f64,
    queue: std.ArrayList(QueueItem) = .empty,
    queue_total_size: f64 = 0,
    started: bool = false,
    close_requested: bool = false,
    pull_again: bool = false,
    pulling: bool = false,

    pub fn deinit(self: *DefaultController) void {
        defaultClearAlgorithms(self);
        defaultResetQueue(self);
        self.queue.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

pub const ReaderType = enum { default, byob, none };

/// § 4.7.2 pull-into descriptor.
pub const PullInto = struct {
    /// Owned ArrayBuffer.
    buffer: Value,
    buffer_byte_length: usize,
    byte_offset: usize,
    byte_length: usize,
    bytes_filled: usize,
    minimum_fill: usize,
    element_size: usize,
    view_kind: ViewKind,
    reader_type: ReaderType,
};

/// § 4.7.2 readable byte stream queue entry.
pub const ByteEntry = struct {
    /// Owned ArrayBuffer.
    buffer: Value,
    byte_offset: usize,
    byte_length: usize,
};

/// § 4.7.2 ReadableByteStreamController internal slots.
pub const ByteController = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    source: ?Source,
    strategy_hwm: f64,
    queue: std.ArrayList(ByteEntry) = .empty,
    queue_total_size: usize = 0,
    started: bool = false,
    close_requested: bool = false,
    pull_again: bool = false,
    pulling: bool = false,
    auto_allocate_chunk_size: ?u64 = null,
    byob_request: ?*runtime.Instance = null,
    pending_pull_intos: std.ArrayList(PullInto) = .empty,

    pub fn deinit(self: *ByteController) void {
        byteClearAlgorithms(self);
        byteResetQueue(self);
        self.queue.deinit(self.allocator);
        for (self.pending_pull_intos.items) |p| js.dispose(p.buffer);
        self.pending_pull_intos.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// § 4.8.2 ReadableStreamBYOBRequest internal slots.
pub const ByobRequest = struct {
    allocator: std.mem.Allocator,
    controller: ?*runtime.Instance = null,
    /// [[view]], owned; null once invalidated.
    view: ?Value = null,

    pub fn deinit(self: *ByobRequest) void {
        js.disposeOptional(&self.view);
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Slot access (brand-checked)
// ============================================================================

pub fn streamOf(instance: *runtime.Instance) ?*Stream {
    const state = instance.stateAs(interfaces.ReadableStream.State) orelse return null;
    return state.own._internal;
}

pub fn readerOf(instance: *runtime.Instance) ?*Reader {
    if (instance.stateAs(interfaces.ReadableStreamDefaultReader.State)) |st| return st.own._internal;
    if (instance.stateAs(interfaces.ReadableStreamBYOBReader.State)) |st| return st.own._internal;
    return null;
}

pub fn defaultControllerOf(instance: *runtime.Instance) ?*DefaultController {
    const state = instance.stateAs(interfaces.ReadableStreamDefaultController.State) orelse return null;
    return state.own._internal;
}

pub fn byteControllerOf(instance: *runtime.Instance) ?*ByteController {
    const state = instance.stateAs(interfaces.ReadableByteStreamController.State) orelse return null;
    return state.own._internal;
}

pub fn byobRequestOf(instance: *runtime.Instance) ?*ByobRequest {
    const state = instance.stateAs(interfaces.ReadableStreamBYOBRequest.State) orelse return null;
    return state.own._internal;
}

fn streamSlots(instance: *runtime.Instance) *Stream {
    return streamOf(instance).?;
}

fn readerSlots(instance: *runtime.Instance) *Reader {
    return readerOf(instance).?;
}

// ============================================================================
// Underlying source from an author object
// (§ 4.9.4 SetUpReadableStreamDefaultControllerFromUnderlyingSource steps 2-7,
//  § 4.9.5 SetUpReadableByteStreamControllerFromUnderlyingSource steps 2-8)
// ============================================================================

/// The UnderlyingSource dictionary (§ 4.2.3), converted, plus the object
/// itself as the callbacks' "callback this value".
pub const UnderlyingSource = struct {
    this: ?Value = null,
    start: ?Value = null,
    pull: ?Value = null,
    cancel: ?Value = null,
    /// type is "bytes".
    bytes: bool = false,
    auto_allocate_chunk_size: ?u64 = null,

    fn release(self: *UnderlyingSource) void {
        js.disposeOptional(&self.this);
        js.disposeOptional(&self.start);
        js.disposeOptional(&self.pull);
        js.disposeOptional(&self.cancel);
    }

    fn deinitErased(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *UnderlyingSource = @ptrCast(@alignCast(ctx.?));
        self.release();
        allocator.destroy(self);
    }

    fn startErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!js.Completion {
        const self: *UnderlyingSource = @ptrCast(@alignCast(ctx.?));
        // An algorithm that returns undefined, unless start exists: invoke it
        // with « controller » and callback this value underlyingSource.
        const start_fn = self.start orelse return .{ .normal = try realm.undefinedValue() };
        return realm.call(start_fn, self.this, &.{try realm.wrap(controller)});
    }

    fn pullErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance) js.Error!Value {
        const self: *UnderlyingSource = @ptrCast(@alignCast(ctx.?));
        const pull_fn = self.pull orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(pull_fn, self.this, &.{try realm.wrap(controller)});
    }

    fn cancelErased(ctx: ?*anyopaque, realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value {
        _ = controller;
        const self: *UnderlyingSource = @ptrCast(@alignCast(ctx.?));
        const cancel_fn = self.cancel orelse return realm.promiseResolvedWithUndefined();
        return realm.promiseCall(cancel_fn, self.this, &.{reason});
    }

    const vtable = Source.VTable{
        .start = startErased,
        .pull = pullErased,
        .cancel = cancelErased,
        .deinit = deinitErased,
    };
};

/// Convert `underlyingSource` to the UnderlyingSource dictionary (WebIDL
/// § 3.2.18: members in lexicographic order - autoAllocateChunkSize, cancel,
/// pull, start, type - each read with Get, undefined meaning absent).
pub fn convertUnderlyingSource(realm: Realm, allocator: std.mem.Allocator, object: ?Value) js.Error!*UnderlyingSource {
    const dict = try allocator.create(UnderlyingSource);
    dict.* = .{};
    errdefer {
        dict.release();
        allocator.destroy(dict);
    }
    const obj = object orelse return dict;
    dict.this = try js.clone(obj);
    if (!js.isObject(obj)) return dict;

    // [EnforceRange] unsigned long long autoAllocateChunkSize
    if (try js.getMember(realm, obj, "autoAllocateChunkSize")) |v| {
        defer js.dispose(v);
        const n = @import("v8").ffi.v8_Value_NumberValue(v, realm.context);
        // [EnforceRange]: NaN and ±∞ throw; then truncate; out of range throws.
        if (std.math.isNan(n) or std.math.isInf(n)) return throwTypeError(realm, "autoAllocateChunkSize is not a finite number");
        const t = @trunc(n);
        if (t < 0 or t > 9007199254740991) return throwTypeError(realm, "autoAllocateChunkSize is out of range");
        dict.auto_allocate_chunk_size = @intFromFloat(t);
    }
    dict.cancel = try js.getCallbackMember(realm, obj, "cancel");
    dict.pull = try js.getCallbackMember(realm, obj, "pull");
    dict.start = try js.getCallbackMember(realm, obj, "start");
    // ReadableStreamType type: an enum value, so ToString then match.
    if (try js.getMember(realm, obj, "type")) |v| {
        defer js.dispose(v);
        const ffi = @import("v8").ffi;
        const str = ffi.v8_Value_ToString(v, realm.context) orelse return error.ExceptionPending;
        defer ffi.v8_String_Dispose(str);
        var buf: [8]u8 = undefined;
        const len = ffi.v8_String_Utf8Length(str);
        const is_bytes = len == 5 and blk: {
            _ = ffi.v8_String_WriteUtf8(str, &buf, 5);
            break :blk std.mem.eql(u8, buf[0..5], "bytes");
        };
        if (!is_bytes) return throwTypeError(realm, "The type of an underlying source must be \"bytes\"");
        dict.bytes = true;
    }
    return dict;
}

fn throwTypeError(realm: Realm, message: []const u8) js.Error {
    const err = realm.typeError(message) catch |e| return e;
    defer js.dispose(err);
    return realm.throwValue(err);
}

pub fn sourceFromUnderlyingSource(dict: *UnderlyingSource) Source {
    return .{ .ctx = dict, .vtable = &UnderlyingSource.vtable };
}

// ============================================================================
// Queue-with-sizes (§ 8.1) for the default controller
// ============================================================================

fn defaultResetQueue(c: *DefaultController) void {
    for (c.queue.items) |item| js.dispose(item.value);
    c.queue.clearRetainingCapacity();
    c.queue_total_size = 0;
}

fn byteResetQueue(c: *ByteController) void {
    for (c.queue.items) |entry| js.dispose(entry.buffer);
    c.queue.clearRetainingCapacity();
    c.queue_total_size = 0;
}

// ============================================================================
// § 4.9.1 Working with readable streams
// ============================================================================

/// InitializeReadableStream(stream) on a new instance.
pub fn newStream(ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.ReadableStream.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Stream);
    // Steps 1-3: readable, no reader, no stored error, not disturbed.
    slots.* = .{ .allocator = ctx.allocator };
    instance.getState(interfaces.ReadableStream.State).own._internal = slots;
    return instance;
}

/// IsReadableStreamLocked(stream)
pub fn isLocked(stream: *const Stream) bool {
    return stream.reader != null;
}

/// AcquireReadableStreamDefaultReader(stream)
pub fn acquireDefaultReader(realm: Realm, stream_instance: *runtime.Instance) !*runtime.Instance {
    const reader = try newReader(stream_instance.ctx, .default);
    errdefer runtime.Instance.deinit(reader);
    try setUpDefaultReader(realm, reader, stream_instance);
    return reader;
}

/// AcquireReadableStreamBYOBReader(stream)
pub fn acquireByobReader(realm: Realm, stream_instance: *runtime.Instance) !*runtime.Instance {
    const reader = try newReader(stream_instance.ctx, .byob);
    errdefer runtime.Instance.deinit(reader);
    try setUpByobReader(realm, reader, stream_instance);
    return reader;
}

pub fn newReader(ctx: runtime.Context, kind: ReaderKind) !*runtime.Instance {
    const instance = switch (kind) {
        .default => try interfaces.ReadableStreamDefaultReader.init(ctx.allocator, ctx),
        .byob => try interfaces.ReadableStreamBYOBReader.init(ctx.allocator, ctx),
    };
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(Reader);
    slots.* = .{ .allocator = ctx.allocator, .kind = kind };
    switch (kind) {
        .default => instance.getState(interfaces.ReadableStreamDefaultReader.State).own._internal = slots,
        .byob => instance.getState(interfaces.ReadableStreamBYOBReader.State).own._internal = slots,
    }
    return instance;
}

/// CreateReadableStream(startAlgorithm, pullAlgorithm, cancelAlgorithm,
/// highWaterMark, sizeAlgorithm). Wrapped before it is returned, so the
/// wrapper cache owns it like one script made.
pub fn createReadableStream(realm: Realm, ctx: runtime.Context, source: Source, hwm: f64, size: sw.SizeAlgorithm) !*runtime.Instance {
    // Steps 4-5: a new, initialized ReadableStream.
    const stream_instance = try newStream(ctx);
    _ = try realm.wrap(stream_instance);
    // Steps 6-7: a new controller, set up with the given algorithms.
    const controller = try newDefaultController(ctx, stream_instance, source, hwm, size);
    try setUpDefaultController(realm, stream_instance, controller);
    return stream_instance;
}

/// CreateReadableByteStream(startAlgorithm, pullAlgorithm, cancelAlgorithm)
pub fn createReadableByteStream(realm: Realm, ctx: runtime.Context, source: Source) !*runtime.Instance {
    const stream_instance = try newStream(ctx);
    _ = try realm.wrap(stream_instance);
    // Step 4: SetUpReadableByteStreamController(..., 0, undefined).
    const controller = try newByteController(ctx, stream_instance, source, 0, null);
    try setUpByteController(realm, stream_instance, controller);
    return stream_instance;
}

/// ReadableStreamCancel(stream, reason). Returns an owned promise.
pub fn cancel(realm: Realm, stream_instance: *runtime.Instance, reason: Value) js.Error!Value {
    const stream = streamSlots(stream_instance);
    // Step 1: Set stream.[[disturbed]] to true.
    stream.disturbed = true;
    // Step 2: closed: resolved with undefined.
    if (stream.state == .closed) return realm.promiseResolvedWithUndefined();
    // Step 3: errored: rejected with the stored error.
    if (stream.state == .errored) return realm.promiseRejectedWith(stream.stored_error.?);
    // Step 4: Perform ! ReadableStreamClose(stream).
    close(realm, stream_instance);
    // Step 6: a BYOB reader's pending reads complete with undefined.
    if (stream.reader) |reader_instance| {
        const reader = readerSlots(reader_instance);
        if (reader.kind == .byob) {
            var requests = reader.read_into_requests;
            reader.read_into_requests = .empty;
            defer requests.deinit(reader.allocator);
            for (requests.items) |r| r.vtable.close(r.ctx, realm, null);
        }
    }
    // Step 7: Let sourceCancelPromise be ! stream.[[controller]].[[CancelSteps]](reason).
    const source_cancel_promise = try cancelSteps(realm, stream.controller.?, reason);
    defer js.dispose(source_cancel_promise);
    // Step 8: react with a fulfillment step that returns undefined.
    return transformToUndefined(realm, stream.allocator, source_cancel_promise);
}

/// "Reacting to" `promise` with a fulfillment step that returns undefined:
/// a new promise that fulfills with undefined or rejects with the reason.
fn transformToUndefined(realm: Realm, allocator: std.mem.Allocator, promise: Value) js.Error!Value {
    const deferred = try Deferred.init(realm);
    const result = try js.clone(deferred.promise);
    const ctx = try allocator.create(DeferredHolder);
    ctx.* = .{ .deferred = deferred, .allocator = allocator, .realm = realm };
    realm.react(promise, DeferredHolder, ctx, DeferredHolder.fulfillUndefined, DeferredHolder.rejectWith) catch {
        deferred.resolveUndefined(realm);
        ctx.finish();
    };
    return result;
}

/// A heap Deferred settled by one reaction.
const DeferredHolder = struct {
    deferred: Deferred,
    allocator: std.mem.Allocator,
    realm: Realm,

    fn finish(self: *DeferredHolder) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    fn fulfillUndefined(self: *DeferredHolder, _: Value) void {
        self.deferred.resolveUndefined(self.realm);
        self.finish();
    }

    fn rejectWith(self: *DeferredHolder, reason: Value) void {
        self.deferred.reject(self.realm, reason);
        self.finish();
    }
};

/// ReadableStreamClose(stream)
pub fn close(realm: Realm, stream_instance: *runtime.Instance) void {
    const stream = streamSlots(stream_instance);
    // Step 1: Assert: stream.[[state]] is "readable".
    // Step 2: Set stream.[[state]] to "closed".
    stream.state = .closed;
    // Steps 3-4: nothing more without a reader.
    const reader_instance = stream.reader orelse return;
    const reader = readerSlots(reader_instance);
    // Step 5: Resolve reader.[[closedPromise]] with undefined.
    if (reader.closed_promise) |closed| closed.resolveUndefined(realm);
    // Step 6: a default reader's pending reads complete as closed.
    if (reader.kind == .default) {
        var requests = reader.read_requests;
        reader.read_requests = .empty;
        defer requests.deinit(reader.allocator);
        for (requests.items) |r| r.vtable.close(r.ctx, realm);
    }
}

/// ReadableStreamError(stream, e)
pub fn errorStream(realm: Realm, stream_instance: *runtime.Instance, e: Value) void {
    const stream = streamSlots(stream_instance);
    // Steps 1-2: Assert readable; set errored.
    stream.state = .errored;
    // Step 3: Set stream.[[storedError]] to e.
    js.disposeOptional(&stream.stored_error);
    stream.stored_error = js.clone(e) catch null;
    // Steps 4-5: nothing more without a reader.
    const reader_instance = stream.reader orelse return;
    const reader = readerSlots(reader_instance);
    // Steps 6-7: reject reader.[[closedPromise]] with e, marked handled.
    if (reader.closed_promise) |closed| {
        closed.reject(realm, e);
        closed.markHandled();
    }
    // Steps 8-9: error the pending requests.
    switch (reader.kind) {
        .default => defaultReaderErrorReadRequests(realm, reader, e),
        .byob => byobReaderErrorReadIntoRequests(realm, reader, e),
    }
}

// ============================================================================
// § 4.9.2 Interfacing with controllers
// ============================================================================

/// ReadableStreamAddReadIntoRequest(stream, readRequest)
fn addReadIntoRequest(stream: *Stream, request: ReadIntoRequest) void {
    const reader = readerSlots(stream.reader.?);
    reader.read_into_requests.append(reader.allocator, request) catch request.vtable.drop(request.ctx);
}

/// ReadableStreamAddReadRequest(stream, readRequest)
fn addReadRequest(stream: *Stream, request: ReadRequest) void {
    const reader = readerSlots(stream.reader.?);
    reader.read_requests.append(reader.allocator, request) catch request.vtable.drop(request.ctx);
}

/// ReadableStreamFulfillReadIntoRequest(stream, chunk, done)
fn fulfillReadIntoRequest(realm: Realm, stream: *Stream, chunk: Value, done: bool) void {
    const reader = readerSlots(stream.reader.?);
    // Steps 4-5: take the first request.
    if (reader.read_into_requests.items.len == 0) return;
    const request = reader.read_into_requests.orderedRemove(0);
    // Steps 6-7
    if (done) request.vtable.close(request.ctx, realm, chunk) else request.vtable.chunk(request.ctx, realm, chunk);
}

/// ReadableStreamFulfillReadRequest(stream, chunk, done)
fn fulfillReadRequest(realm: Realm, stream: *Stream, chunk: Value, done: bool) void {
    const reader = readerSlots(stream.reader.?);
    if (reader.read_requests.items.len == 0) return;
    const request = reader.read_requests.orderedRemove(0);
    if (done) request.vtable.close(request.ctx, realm) else request.vtable.chunk(request.ctx, realm, chunk);
}

/// ReadableStreamGetNumReadIntoRequests(stream)
fn getNumReadIntoRequests(stream: *const Stream) usize {
    return readerSlots(stream.reader.?).read_into_requests.items.len;
}

/// ReadableStreamGetNumReadRequests(stream)
fn getNumReadRequests(stream: *const Stream) usize {
    return readerSlots(stream.reader.?).read_requests.items.len;
}

/// ReadableStreamHasBYOBReader(stream)
fn hasByobReader(stream: *const Stream) bool {
    const reader = stream.reader orelse return false;
    return readerSlots(reader).kind == .byob;
}

/// ReadableStreamHasDefaultReader(stream)
fn hasDefaultReader(stream: *const Stream) bool {
    const reader = stream.reader orelse return false;
    return readerSlots(reader).kind == .default;
}

// ============================================================================
// § 4.9.3 Readers
// ============================================================================

/// ReadableStreamReaderGenericCancel(reader, reason). Owned promise.
pub fn readerGenericCancel(realm: Realm, reader: *Reader, reason: Value) js.Error!Value {
    // Steps 1-3: Return ! ReadableStreamCancel(stream, reason).
    return cancel(realm, reader.stream.?, reason);
}

/// ReadableStreamReaderGenericInitialize(reader, stream)
fn readerGenericInitialize(realm: Realm, reader_instance: *runtime.Instance, stream_instance: *runtime.Instance) js.Error!void {
    const reader = readerSlots(reader_instance);
    const stream = streamSlots(stream_instance);
    // Steps 1-2: link them.
    reader.stream = stream_instance;
    stream.reader = reader_instance;
    // Steps 3-5: the closed promise follows the stream's state.
    reader.closed_promise = switch (stream.state) {
        .readable => try Deferred.init(realm),
        .closed => try Deferred.initResolved(realm),
        .errored => blk: {
            const d = try Deferred.initRejected(realm, stream.stored_error.?);
            d.markHandled();
            break :blk d;
        },
    };
}

/// ReadableStreamReaderGenericRelease(reader)
fn readerGenericRelease(realm: Realm, reader_instance: *runtime.Instance) void {
    const reader = readerSlots(reader_instance);
    // Steps 1-3: Assert: stream is not undefined and stream.[[reader]] is reader.
    const stream_instance = reader.stream.?;
    const stream = streamSlots(stream_instance);
    const released = realm.typeError("Reader was released") catch null;
    defer if (released) |e| js.dispose(e);
    if (released) |e| {
        // Step 4: readable: reject the pending closed promise.
        if (stream.state == .readable and reader.closed_promise != null and reader.closed_promise.?.isPending()) {
            reader.closed_promise.?.reject(realm, e);
        } else if (Deferred.initRejected(realm, e)) |fresh| {
            // Step 5: otherwise a new promise rejected with a TypeError.
            if (reader.closed_promise) |old| old.deinit();
            reader.closed_promise = fresh;
        } else |_| {}
    }
    // Step 6: Set [[PromiseIsHandled]] to true.
    if (reader.closed_promise) |closed| closed.markHandled();
    // Step 7: Perform ! stream.[[controller]].[[ReleaseSteps]]().
    releaseSteps(stream.controller.?);
    // Steps 8-9: unlink.
    stream.reader = null;
    reader.stream = null;
}

/// ReadableStreamBYOBReaderErrorReadIntoRequests(reader, e)
fn byobReaderErrorReadIntoRequests(realm: Realm, reader: *Reader, e: Value) void {
    var requests = reader.read_into_requests;
    reader.read_into_requests = .empty;
    defer requests.deinit(reader.allocator);
    for (requests.items) |r| r.vtable.err(r.ctx, realm, e);
}

/// ReadableStreamBYOBReaderRead(reader, view, min, readIntoRequest).
/// `view` is borrowed.
pub fn byobReaderRead(realm: Realm, reader: *Reader, view: Value, min: u64, request: ReadIntoRequest) void {
    const stream_instance = reader.stream.?;
    const stream = streamSlots(stream_instance);
    // Step 3: Set stream.[[disturbed]] to true.
    stream.disturbed = true;
    // Step 4: errored: the error steps, given the stored error.
    if (stream.state == .errored) {
        request.vtable.err(request.ctx, realm, stream.stored_error.?);
        return;
    }
    // Step 5: Perform ! ReadableByteStreamControllerPullInto(controller, view, min, readIntoRequest).
    bytePullInto(realm, stream.controller.?, view, min, request);
}

/// ReadableStreamBYOBReaderRelease(reader)
pub fn byobReaderRelease(realm: Realm, reader_instance: *runtime.Instance) void {
    // Step 1
    readerGenericRelease(realm, reader_instance);
    // Steps 2-3: pending reads reject with a TypeError.
    const e = realm.typeError("Reader was released") catch return;
    defer js.dispose(e);
    byobReaderErrorReadIntoRequests(realm, readerSlots(reader_instance), e);
}

/// ReadableStreamDefaultReaderErrorReadRequests(reader, e)
fn defaultReaderErrorReadRequests(realm: Realm, reader: *Reader, e: Value) void {
    var requests = reader.read_requests;
    reader.read_requests = .empty;
    defer requests.deinit(reader.allocator);
    for (requests.items) |r| r.vtable.err(r.ctx, realm, e);
}

/// ReadableStreamDefaultReaderRead(reader, readRequest)
pub fn defaultReaderRead(realm: Realm, reader: *Reader, request: ReadRequest) void {
    const stream_instance = reader.stream.?;
    const stream = streamSlots(stream_instance);
    // Step 3: Set stream.[[disturbed]] to true.
    stream.disturbed = true;
    switch (stream.state) {
        // Step 4
        .closed => request.vtable.close(request.ctx, realm),
        // Step 5
        .errored => request.vtable.err(request.ctx, realm, stream.stored_error.?),
        // Step 6: Perform ! stream.[[controller]].[[PullSteps]](readRequest).
        .readable => pullSteps(realm, stream.controller.?, request),
    }
}

/// ReadableStreamDefaultReaderRelease(reader)
pub fn defaultReaderRelease(realm: Realm, reader_instance: *runtime.Instance) void {
    // Step 1
    readerGenericRelease(realm, reader_instance);
    // Steps 2-3: pending reads reject with a TypeError.
    const e = realm.typeError("Reader was released") catch return;
    defer js.dispose(e);
    defaultReaderErrorReadRequests(realm, readerSlots(reader_instance), e);
}

/// SetUpReadableStreamBYOBReader(reader, stream)
pub fn setUpByobReader(realm: Realm, reader_instance: *runtime.Instance, stream_instance: *runtime.Instance) !void {
    const stream = streamSlots(stream_instance);
    // Step 1: A locked stream is a TypeError.
    if (isLocked(stream)) return error.TypeError;
    // Step 2: So is one that is not a byte stream.
    if (byteControllerOf(stream.controller.?) == null) return error.TypeError;
    // Steps 3-4
    try readerGenericInitialize(realm, reader_instance, stream_instance);
}

/// SetUpReadableStreamDefaultReader(reader, stream)
pub fn setUpDefaultReader(realm: Realm, reader_instance: *runtime.Instance, stream_instance: *runtime.Instance) !void {
    const stream = streamSlots(stream_instance);
    // Step 1: A locked stream is a TypeError.
    if (isLocked(stream)) return error.TypeError;
    // Steps 2-3
    try readerGenericInitialize(realm, reader_instance, stream_instance);
}

// ============================================================================
// Controller internal methods, dispatched on the controller class
// (§ 4.6.4 / § 4.7.4 [[CancelSteps]], [[PullSteps]], [[ReleaseSteps]])
// ============================================================================

fn cancelSteps(realm: Realm, controller: *runtime.Instance, reason: Value) js.Error!Value {
    if (defaultControllerOf(controller)) |c| {
        // § 4.6.4 steps 1-4
        defaultResetQueue(c);
        const result = blk: {
            const s = c.source orelse break :blk realm.promiseResolvedWithUndefined();
            break :blk s.vtable.cancel(s.ctx, realm, controller, reason);
        };
        defaultClearAlgorithms(c);
        return result;
    }
    const c = byteControllerOf(controller).?;
    // § 4.7.4 steps 1-5
    byteClearPendingPullIntos(c);
    byteResetQueue(c);
    const result = blk: {
        const s = c.source orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk s.vtable.cancel(s.ctx, realm, controller, reason);
    };
    byteClearAlgorithms(c);
    return result;
}

fn pullSteps(realm: Realm, controller: *runtime.Instance, request: ReadRequest) void {
    if (defaultControllerOf(controller)) |c| return defaultPullSteps(realm, controller, c, request);
    bytePullSteps(realm, controller, byteControllerOf(controller).?, request);
}

fn releaseSteps(controller: *runtime.Instance) void {
    // § 4.6.4 [[ReleaseSteps]]: return.
    const c = byteControllerOf(controller) orelse return;
    // § 4.7.4 [[ReleaseSteps]]: keep only the first pending pull-into, detached
    // from any reader.
    if (c.pending_pull_intos.items.len == 0) return;
    c.pending_pull_intos.items[0].reader_type = .none;
    for (c.pending_pull_intos.items[1..]) |p| js.dispose(p.buffer);
    c.pending_pull_intos.shrinkRetainingCapacity(1);
}

/// § 4.6.4 [[PullSteps]](readRequest)
fn defaultPullSteps(realm: Realm, controller_instance: *runtime.Instance, c: *DefaultController, request: ReadRequest) void {
    const stream_instance = c.stream;
    // Step 2: take a queued chunk if there is one.
    if (c.queue.items.len > 0) {
        // 2.1 Let chunk be ! DequeueValue(this).
        const item = c.queue.orderedRemove(0);
        c.queue_total_size -= item.size;
        if (c.queue_total_size < 0) c.queue_total_size = 0;
        defer js.dispose(item.value);
        // 2.2-2.3: close once drained after a close request, else pull.
        if (c.close_requested and c.queue.items.len == 0) {
            defaultClearAlgorithms(c);
            close(realm, stream_instance);
        } else {
            defaultCallPullIfNeeded(realm, controller_instance);
        }
        // 2.4 Perform readRequest's chunk steps, given chunk.
        request.vtable.chunk(request.ctx, realm, item.value);
        return;
    }
    // Step 3: otherwise wait for one.
    addReadRequest(streamSlots(stream_instance), request);
    defaultCallPullIfNeeded(realm, controller_instance);
}

// ============================================================================
// § 4.9.4 Default controllers
// ============================================================================

pub fn newDefaultController(ctx: runtime.Context, stream_instance: *runtime.Instance, source: Source, hwm: f64, size: sw.SizeAlgorithm) !*runtime.Instance {
    const instance = try interfaces.ReadableStreamDefaultController.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(DefaultController);
    slots.* = .{ .allocator = ctx.allocator, .stream = stream_instance, .source = source, .size_algorithm = size, .strategy_hwm = hwm };
    instance.getState(interfaces.ReadableStreamDefaultController.State).own._internal = slots;
    return instance;
}

/// ReadableStreamDefaultControllerCallPullIfNeeded(controller)
fn defaultCallPullIfNeeded(realm: Realm, controller_instance: *runtime.Instance) void {
    const c = defaultControllerOf(controller_instance).?;
    // Steps 1-2
    if (!defaultShouldCallPull(c)) return;
    // Step 3: a pull in progress runs again when it finishes.
    if (c.pulling) {
        c.pull_again = true;
        return;
    }
    // Step 5: Set controller.[[pulling]] to true.
    c.pulling = true;
    // Step 6: Let pullPromise be the result of performing the pull algorithm.
    const pull_promise = blk: {
        const s = c.source orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk s.vtable.pull(s.ctx, realm, controller_instance);
    } catch return;
    defer js.dispose(pull_promise);
    // Steps 7-8
    realm.react(pull_promise, runtime.Instance, controller_instance, onDefaultPullFulfilled, onDefaultPullRejected) catch {};
}

fn onDefaultPullFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const c = defaultControllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 7.1 Set controller.[[pulling]] to false.
    c.pulling = false;
    // 7.2 Pull again if asked to meanwhile.
    if (c.pull_again) {
        c.pull_again = false;
        defaultCallPullIfNeeded(realm, controller_instance);
    }
}

fn onDefaultPullRejected(controller_instance: *runtime.Instance, e: Value) void {
    const realm = Realm.of(controller_instance) catch return;
    // 8.1 Perform ! ReadableStreamDefaultControllerError(controller, e).
    defaultControllerError(realm, controller_instance, e);
}

/// ReadableStreamDefaultControllerShouldCallPull(controller)
fn defaultShouldCallPull(c: *DefaultController) bool {
    const stream = streamSlots(c.stream);
    // Step 2
    if (!defaultCanCloseOrEnqueue(c)) return false;
    // Step 3
    if (!c.started) return false;
    // Step 4: a reader waiting for a chunk.
    if (isLocked(stream) and hasDefaultReader(stream) and getNumReadRequests(stream) > 0) return true;
    // Steps 5-8: room in the queue.
    return (defaultGetDesiredSize(c) orelse 0) > 0;
}

/// ReadableStreamDefaultControllerClearAlgorithms(controller)
fn defaultClearAlgorithms(c: *DefaultController) void {
    // Steps 1-2: drop the pull and cancel algorithms.
    if (c.source) |s| s.vtable.deinit(s.ctx, c.allocator);
    c.source = null;
    // Step 3: drop the size algorithm.
    switch (c.size_algorithm) {
        .callback => |f| js.dispose(f),
        else => {},
    }
    c.size_algorithm = .cleared;
}

/// ReadableStreamDefaultControllerClose(controller)
pub fn defaultControllerClose(realm: Realm, controller_instance: *runtime.Instance) void {
    const c = defaultControllerOf(controller_instance).?;
    // Step 1
    if (!defaultCanCloseOrEnqueue(c)) return;
    // Step 3: Set controller.[[closeRequested]] to true.
    c.close_requested = true;
    // Step 4: close now when nothing is queued.
    if (c.queue.items.len == 0) {
        defaultClearAlgorithms(c);
        close(realm, c.stream);
    }
}

/// ReadableStreamDefaultControllerEnqueue(controller, chunk), throwing its
/// abrupt completion into script (error.ExceptionPending): for the IDL method.
pub fn defaultControllerEnqueue(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) js.Error!void {
    if (try defaultControllerEnqueueCompletion(realm, controller_instance, chunk)) |e| {
        defer js.dispose(e);
        return realm.throwValue(e);
    }
}

/// ReadableStreamDefaultControllerEnqueue(controller, chunk), returning its
/// abrupt completion's value (owned), or null. A throwing size algorithm, or
/// a size EnqueueValueWithSize refuses, errors the stream first.
pub fn defaultControllerEnqueueCompletion(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) js.Error!?Value {
    const c = defaultControllerOf(controller_instance).?;
    // Step 1
    if (!defaultCanCloseOrEnqueue(c)) return null;
    const stream = streamSlots(c.stream);
    // Step 3: a waiting reader takes the chunk directly.
    if (isLocked(stream) and hasDefaultReader(stream) and getNumReadRequests(stream) > 0) {
        fulfillReadRequest(realm, stream, chunk, false);
    } else {
        // 4.1 Let result be the size algorithm's completion for chunk.
        const chunk_size: f64 = switch (c.size_algorithm) {
            .one, .cleared => 1,
            .callback => |f| blk: {
                const completion = try realm.call(f, null, &.{chunk});
                defer completion.deinit();
                switch (completion) {
                    .normal => |v| break :blk @import("v8").ffi.v8_Value_NumberValue(v, realm.context),
                    // 4.2 An abrupt completion errors the controller and is returned.
                    .thrown => |e| {
                        defaultControllerError(realm, controller_instance, e);
                        return try js.clone(e);
                    },
                }
            },
        };
        // 4.4 EnqueueValueWithSize: a size that is not a finite
        // non-negative number is a RangeError.
        if (std.math.isNan(chunk_size) or chunk_size < 0 or std.math.isInf(chunk_size)) {
            const e = try realm.rangeError("The chunk size must be a finite, non-negative number");
            // 4.5 Error the controller and return the completion.
            defaultControllerError(realm, controller_instance, e);
            return e;
        }
        const value = try js.clone(chunk);
        c.queue.append(c.allocator, .{ .value = value, .size = chunk_size }) catch {
            js.dispose(value);
            return error.OutOfMemory;
        };
        c.queue_total_size += chunk_size;
    }
    // Step 5: Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller).
    defaultCallPullIfNeeded(realm, controller_instance);
    return null;
}

/// ReadableStreamDefaultControllerError(controller, e)
pub fn defaultControllerError(realm: Realm, controller_instance: *runtime.Instance, e: Value) void {
    const c = defaultControllerOf(controller_instance).?;
    // Step 2: only a readable stream.
    if (streamSlots(c.stream).state != .readable) return;
    // Steps 3-5
    defaultResetQueue(c);
    defaultClearAlgorithms(c);
    errorStream(realm, c.stream, e);
}

/// ReadableStreamDefaultControllerGetDesiredSize(controller)
pub fn defaultGetDesiredSize(c: *const DefaultController) ?f64 {
    return switch (streamSlots(c.stream).state) {
        .errored => null,
        .closed => 0,
        .readable => c.strategy_hwm - c.queue_total_size,
    };
}

/// ReadableStreamDefaultControllerHasBackpressure(controller)
pub fn defaultHasBackpressure(c: *DefaultController) bool {
    return !defaultShouldCallPull(c);
}

/// ReadableStreamDefaultControllerCanCloseOrEnqueue(controller)
pub fn defaultCanCloseOrEnqueue(c: *const DefaultController) bool {
    return !c.close_requested and streamSlots(c.stream).state == .readable;
}

/// SetUpReadableStreamDefaultController(stream, controller, ...). The
/// algorithms and strategy are already in the controller's slots.
pub fn setUpDefaultController(realm: Realm, stream_instance: *runtime.Instance, controller_instance: *runtime.Instance) js.Error!void {
    const stream = streamSlots(stream_instance);
    const c = defaultControllerOf(controller_instance).?;
    // The controller's wrapper is what start() receives, and wrapping it
    // registers it with the wrapper cache.
    _ = try realm.wrap(controller_instance);
    // Steps 2-7: queue empty, flags false; strategy and algorithms in place.
    defaultResetQueue(c);
    // Step 8: Set stream.[[controller]] to controller.
    stream.controller = controller_instance;
    // Step 9: Let startResult be the result of performing startAlgorithm.
    const s = c.source.?;
    const start_value = switch (try s.vtable.start(s.ctx, realm, controller_instance)) {
        .normal => |v| v,
        .thrown => |e| {
            defer js.dispose(e);
            return realm.throwValue(e);
        },
    };
    defer js.dispose(start_value);
    // Step 10: Let startPromise be a promise resolved with startResult.
    const start_promise = try realm.promiseResolvedWith(start_value);
    defer js.dispose(start_promise);
    // Steps 11-12
    try realm.react(start_promise, runtime.Instance, controller_instance, onDefaultStartFulfilled, onDefaultStartRejected);
}

fn onDefaultStartFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const c = defaultControllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 11.1 Set controller.[[started]] to true.
    c.started = true;
    // 11.4 Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller).
    defaultCallPullIfNeeded(realm, controller_instance);
}

fn onDefaultStartRejected(controller_instance: *runtime.Instance, r: Value) void {
    const realm = Realm.of(controller_instance) catch return;
    // 12.1 Perform ! ReadableStreamDefaultControllerError(controller, r).
    defaultControllerError(realm, controller_instance, r);
}

// ============================================================================
// § 4.9.5 Byte stream controllers
// ============================================================================

pub fn newByteController(ctx: runtime.Context, stream_instance: *runtime.Instance, source: Source, hwm: f64, auto_allocate_chunk_size: ?u64) !*runtime.Instance {
    const instance = try interfaces.ReadableByteStreamController.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    const slots = try ctx.allocator.create(ByteController);
    slots.* = .{
        .allocator = ctx.allocator,
        .stream = stream_instance,
        .source = source,
        .strategy_hwm = hwm,
        .auto_allocate_chunk_size = auto_allocate_chunk_size,
    };
    instance.getState(interfaces.ReadableByteStreamController.State).own._internal = slots;
    return instance;
}

/// SetUpReadableByteStreamController(stream, controller, ...). The
/// algorithms, strategy and autoAllocateChunkSize are already in place.
pub fn setUpByteController(realm: Realm, stream_instance: *runtime.Instance, controller_instance: *runtime.Instance) js.Error!void {
    const stream = streamSlots(stream_instance);
    const c = byteControllerOf(controller_instance).?;
    _ = try realm.wrap(controller_instance);
    // Steps 3-12: flags false, no BYOB request, empty queue and pull-intos.
    byteResetQueue(c);
    // Step 13: Set stream.[[controller]] to controller.
    stream.controller = controller_instance;
    // Step 14: Let startResult be the result of performing startAlgorithm.
    const s = c.source.?;
    const start_value = switch (try s.vtable.start(s.ctx, realm, controller_instance)) {
        .normal => |v| v,
        .thrown => |e| {
            defer js.dispose(e);
            return realm.throwValue(e);
        },
    };
    defer js.dispose(start_value);
    // Step 15: Let startPromise be a promise resolved with startResult.
    const start_promise = try realm.promiseResolvedWith(start_value);
    defer js.dispose(start_promise);
    // Steps 16-17
    try realm.react(start_promise, runtime.Instance, controller_instance, onByteStartFulfilled, onByteStartRejected);
}

fn onByteStartFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const c = byteControllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 16.1 Set controller.[[started]] to true.
    c.started = true;
    // 16.4 Perform ! ReadableByteStreamControllerCallPullIfNeeded(controller).
    byteCallPullIfNeeded(realm, controller_instance);
}

fn onByteStartRejected(controller_instance: *runtime.Instance, r: Value) void {
    const realm = Realm.of(controller_instance) catch return;
    // 17.1 Perform ! ReadableByteStreamControllerError(controller, r).
    byteControllerError(realm, controller_instance, r);
}

/// ReadableByteStreamControllerCallPullIfNeeded(controller)
fn byteCallPullIfNeeded(realm: Realm, controller_instance: *runtime.Instance) void {
    const c = byteControllerOf(controller_instance).?;
    // Steps 1-2
    if (!byteShouldCallPull(c)) return;
    // Step 3
    if (c.pulling) {
        c.pull_again = true;
        return;
    }
    // Step 5
    c.pulling = true;
    // Step 6
    const pull_promise = blk: {
        const s = c.source orelse break :blk realm.promiseResolvedWithUndefined();
        break :blk s.vtable.pull(s.ctx, realm, controller_instance);
    } catch return;
    defer js.dispose(pull_promise);
    // Steps 7-8
    realm.react(pull_promise, runtime.Instance, controller_instance, onBytePullFulfilled, onBytePullRejected) catch {};
}

fn onBytePullFulfilled(controller_instance: *runtime.Instance, _: Value) void {
    const c = byteControllerOf(controller_instance) orelse return;
    const realm = Realm.of(controller_instance) catch return;
    // 7.1-7.2
    c.pulling = false;
    if (c.pull_again) {
        c.pull_again = false;
        byteCallPullIfNeeded(realm, controller_instance);
    }
}

fn onBytePullRejected(controller_instance: *runtime.Instance, e: Value) void {
    const realm = Realm.of(controller_instance) catch return;
    // 8.1
    byteControllerError(realm, controller_instance, e);
}

/// ReadableByteStreamControllerClearAlgorithms(controller)
fn byteClearAlgorithms(c: *ByteController) void {
    if (c.source) |s| s.vtable.deinit(s.ctx, c.allocator);
    c.source = null;
}

/// ReadableByteStreamControllerClearPendingPullIntos(controller)
fn byteClearPendingPullIntos(c: *ByteController) void {
    // Step 1
    byteInvalidateByobRequest(c);
    // Step 2
    for (c.pending_pull_intos.items) |p| js.dispose(p.buffer);
    c.pending_pull_intos.clearRetainingCapacity();
}

/// ReadableByteStreamControllerClose(controller). A misaligned pending
/// read errors the stream and is thrown (error.ExceptionPending).
pub fn byteControllerClose(realm: Realm, controller_instance: *runtime.Instance) js.Error!void {
    const c = byteControllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    // Step 2
    if (c.close_requested or stream.state != .readable) return;
    // Step 3: queued bytes close once drained.
    if (c.queue_total_size > 0) {
        c.close_requested = true;
        return;
    }
    // Step 4: a partially filled element cannot be completed.
    if (c.pending_pull_intos.items.len > 0) {
        const first = c.pending_pull_intos.items[0];
        if (first.bytes_filled % first.element_size != 0) {
            const e = try realm.typeError("Insufficient bytes to fill elements in the given buffer");
            defer js.dispose(e);
            byteControllerError(realm, controller_instance, e);
            return realm.throwValue(e);
        }
    }
    // Steps 5-6
    byteClearAlgorithms(c);
    close(realm, c.stream);
}

/// ReadableByteStreamControllerCommitPullIntoDescriptor(stream, pullIntoDescriptor).
/// Consumes the descriptor's buffer.
fn byteCommitPullIntoDescriptor(realm: Realm, stream: *Stream, descriptor: PullInto) void {
    // Steps 1-4: done when the stream is closed.
    const done = stream.state == .closed;
    // Step 5
    const filled_view = byteConvertPullIntoDescriptor(descriptor) orelse return;
    defer js.dispose(filled_view);
    // Steps 6-7
    switch (descriptor.reader_type) {
        .default => fulfillReadRequest(realm, stream, filled_view, done),
        .byob => fulfillReadIntoRequest(realm, stream, filled_view, done),
        .none => {},
    }
}

/// ReadableByteStreamControllerConvertPullIntoDescriptor(pullIntoDescriptor).
/// Consumes the descriptor's buffer; returns an owned view.
fn byteConvertPullIntoDescriptor(descriptor: PullInto) ?Value {
    defer js.dispose(descriptor.buffer);
    // Step 5: Let buffer be ! TransferArrayBuffer(pullIntoDescriptor's buffer).
    const buffer = js.transferBuffer(descriptor.buffer) orelse return null;
    defer js.dispose(buffer);
    // Step 6: Construct(view constructor, « buffer, byte offset, bytesFilled ÷ elementSize »).
    return js.newView(descriptor.view_kind, buffer, descriptor.byte_offset, descriptor.bytes_filled / descriptor.element_size) catch null;
}

/// ReadableByteStreamControllerEnqueue(controller, chunk). `chunk` is
/// borrowed. A failed transfer is thrown (error.ExceptionPending).
pub fn byteControllerEnqueue(realm: Realm, controller_instance: *runtime.Instance, chunk: Value) js.Error!void {
    const c = byteControllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    // Step 2
    if (c.close_requested or stream.state != .readable) return;
    // Steps 3-5
    const info = js.describeView(chunk) orelse return throwTypeError(realm, "chunk is not an ArrayBufferView");
    const buffer = try js.viewBuffer(chunk);
    defer js.dispose(buffer);
    // Step 6: a detached buffer is a TypeError.
    if (js.isDetachedBuffer(buffer)) return throwTypeError(realm, "chunk's buffer is detached");
    // Step 7: Let transferredBuffer be ? TransferArrayBuffer(buffer).
    const transferred = js.transferBuffer(buffer) orelse return throwTypeError(realm, "chunk's buffer cannot be transferred");
    var transferred_owned = true;
    defer if (transferred_owned) js.dispose(transferred);
    // Step 8: the first pending pull-into gives up its buffer.
    if (c.pending_pull_intos.items.len > 0) {
        const first = &c.pending_pull_intos.items[0];
        // 8.2
        if (js.isDetachedBuffer(first.buffer)) return throwTypeError(realm, "The BYOB request's buffer has been detached");
        // 8.3
        byteInvalidateByobRequest(c);
        // 8.4
        const moved = js.transferBuffer(first.buffer) orelse return throwTypeError(realm, "The BYOB request's buffer cannot be transferred");
        js.dispose(first.buffer);
        first.buffer = moved;
        // 8.5
        if (first.reader_type == .none) try byteEnqueueDetachedPullIntoToQueue(realm, controller_instance, c);
    }
    if (hasDefaultReader(stream)) {
        // 9.1
        byteProcessReadRequestsUsingQueue(realm, c);
        if (getNumReadRequests(stream) == 0) {
            // 9.2
            byteEnqueueChunkToQueue(c, transferred, info.byte_offset, info.byte_length);
            transferred_owned = false;
        } else {
            // 9.3.2: a default-reader pull-into is superseded by this chunk.
            if (c.pending_pull_intos.items.len > 0) {
                const shifted = byteShiftPendingPullInto(c);
                js.dispose(shifted.buffer);
            }
            // 9.3.3-9.3.4
            const view = try js.newView(.uint8, transferred, info.byte_offset, info.byte_length);
            defer js.dispose(view);
            fulfillReadRequest(realm, stream, view, false);
        }
    } else if (hasByobReader(stream)) {
        // 10.1
        byteEnqueueChunkToQueue(c, transferred, info.byte_offset, info.byte_length);
        transferred_owned = false;
        // 10.2-10.3
        var filled = byteProcessPullIntoDescriptorsUsingQueue(c);
        defer filled.deinit(c.allocator);
        for (filled.items) |d| byteCommitPullIntoDescriptor(realm, stream, d);
    } else {
        // 11.2
        byteEnqueueChunkToQueue(c, transferred, info.byte_offset, info.byte_length);
        transferred_owned = false;
    }
    // Step 12
    byteCallPullIfNeeded(realm, controller_instance);
}

/// ReadableByteStreamControllerEnqueueChunkToQueue(controller, buffer, byteOffset, byteLength).
/// Takes ownership of `buffer`.
fn byteEnqueueChunkToQueue(c: *ByteController, buffer: Value, byte_offset: usize, byte_length: usize) void {
    c.queue.append(c.allocator, .{ .buffer = buffer, .byte_offset = byte_offset, .byte_length = byte_length }) catch {
        js.dispose(buffer);
        return;
    };
    c.queue_total_size += byte_length;
}

/// ReadableByteStreamControllerEnqueueClonedChunkToQueue(controller, buffer, byteOffset, byteLength)
fn byteEnqueueClonedChunkToQueue(realm: Realm, controller_instance: *runtime.Instance, c: *ByteController, buffer: Value, byte_offset: usize, byte_length: usize) js.Error!void {
    // Step 1: Let cloneResult be CloneArrayBuffer(buffer, byteOffset, byteLength, %ArrayBuffer%).
    const clone_buffer = js.allocateBuffer(byte_length) orelse {
        const e = try realm.rangeError("Array buffer allocation failed");
        defer js.dispose(e);
        // Step 2: error the controller and return the completion.
        byteControllerError(realm, controller_instance, e);
        return realm.throwValue(e);
    };
    if (js.bufferBytes(buffer)) |src| {
        if (js.bufferBytes(clone_buffer)) |dst| {
            if (byte_offset + byte_length <= src.len) @memcpy(dst[0..byte_length], src[byte_offset..][0..byte_length]);
        }
    }
    // Step 3
    byteEnqueueChunkToQueue(c, clone_buffer, 0, byte_length);
}

/// ReadableByteStreamControllerEnqueueDetachedPullIntoToQueue(controller, pullIntoDescriptor)
fn byteEnqueueDetachedPullIntoToQueue(realm: Realm, controller_instance: *runtime.Instance, c: *ByteController) js.Error!void {
    const first = c.pending_pull_intos.items[0];
    // Step 2
    if (first.bytes_filled > 0) try byteEnqueueClonedChunkToQueue(realm, controller_instance, c, first.buffer, first.byte_offset, first.bytes_filled);
    // Step 3
    const shifted = byteShiftPendingPullInto(c);
    js.dispose(shifted.buffer);
}

/// ReadableByteStreamControllerError(controller, e)
pub fn byteControllerError(realm: Realm, controller_instance: *runtime.Instance, e: Value) void {
    const c = byteControllerOf(controller_instance).?;
    // Step 2
    if (streamSlots(c.stream).state != .readable) return;
    // Steps 3-6
    byteClearPendingPullIntos(c);
    byteResetQueue(c);
    byteClearAlgorithms(c);
    errorStream(realm, c.stream, e);
}

/// ReadableByteStreamControllerFillHeadPullIntoDescriptor(controller, size, pullIntoDescriptor)
fn byteFillHeadPullIntoDescriptor(descriptor: *PullInto, size: usize) void {
    descriptor.bytes_filled += size;
}

/// ReadableByteStreamControllerFillPullIntoDescriptorFromQueue(controller, pullIntoDescriptor)
fn byteFillPullIntoDescriptorFromQueue(c: *ByteController, descriptor: *PullInto) bool {
    // Steps 1-2
    const max_bytes_to_copy = @min(c.queue_total_size, descriptor.byte_length - descriptor.bytes_filled);
    const max_bytes_filled = descriptor.bytes_filled + max_bytes_to_copy;
    // Steps 3-4
    var total_remaining = max_bytes_to_copy;
    var ready = false;
    // Steps 7-9: only whole elements, and at least the minimum fill.
    const remainder = max_bytes_filled % descriptor.element_size;
    const max_aligned = max_bytes_filled - remainder;
    if (max_aligned >= descriptor.minimum_fill) {
        total_remaining = max_aligned - descriptor.bytes_filled;
        ready = true;
    }
    const dest = js.bufferBytes(descriptor.buffer) orelse return ready;
    // Step 11
    while (total_remaining > 0 and c.queue.items.len > 0) {
        const head = &c.queue.items[0];
        const bytes_to_copy = @min(total_remaining, head.byte_length);
        const dest_start = descriptor.byte_offset + descriptor.bytes_filled;
        // 11.7-11.8: CanCopyDataBlockBytes, then CopyDataBlockBytes.
        if (js.bufferBytes(head.buffer)) |src| {
            if (dest_start + bytes_to_copy <= dest.len and head.byte_offset + bytes_to_copy <= src.len) {
                @memcpy(dest[dest_start..][0..bytes_to_copy], src[head.byte_offset..][0..bytes_to_copy]);
            }
        }
        // 11.9-11.10
        if (head.byte_length == bytes_to_copy) {
            const entry = c.queue.orderedRemove(0);
            js.dispose(entry.buffer);
        } else {
            head.byte_offset += bytes_to_copy;
            head.byte_length -= bytes_to_copy;
        }
        // 11.11-11.13
        c.queue_total_size -= bytes_to_copy;
        byteFillHeadPullIntoDescriptor(descriptor, bytes_to_copy);
        total_remaining -= bytes_to_copy;
    }
    // Step 13
    return ready;
}

/// ReadableByteStreamControllerFillReadRequestFromQueue(controller, readRequest)
fn byteFillReadRequestFromQueue(realm: Realm, c: *ByteController, request: ReadRequest) void {
    // Steps 2-4
    const entry = c.queue.orderedRemove(0);
    defer js.dispose(entry.buffer);
    c.queue_total_size -= entry.byte_length;
    // Step 5
    byteHandleQueueDrain(realm, c);
    // Steps 6-7
    const view = js.newView(.uint8, entry.buffer, entry.byte_offset, entry.byte_length) catch return request.vtable.drop(request.ctx);
    defer js.dispose(view);
    request.vtable.chunk(request.ctx, realm, view);
}

/// ReadableByteStreamControllerGetBYOBRequest(controller)
pub fn byteGetByobRequest(realm: Realm, controller_instance: *runtime.Instance) ?*runtime.Instance {
    const c = byteControllerOf(controller_instance).?;
    // Step 1
    if (c.byob_request == null and c.pending_pull_intos.items.len > 0) {
        const first = c.pending_pull_intos.items[0];
        // 1.2 Construct(%Uint8Array%, « buffer, byteOffset + bytesFilled, byteLength − bytesFilled »)
        const view = js.newView(.uint8, first.buffer, first.byte_offset + first.bytes_filled, first.byte_length - first.bytes_filled) catch return null;
        // 1.3-1.6
        const request = interfaces.ReadableStreamBYOBRequest.init(c.allocator, controller_instance.ctx) catch {
            js.dispose(view);
            return null;
        };
        const slots = c.allocator.create(ByobRequest) catch {
            js.dispose(view);
            return null;
        };
        slots.* = .{ .allocator = c.allocator, .controller = controller_instance, .view = view };
        request.getState(interfaces.ReadableStreamBYOBRequest.State).own._internal = slots;
        _ = realm.wrap(request) catch {};
        c.byob_request = request;
    }
    // Step 2
    return c.byob_request;
}

/// ReadableByteStreamControllerGetDesiredSize(controller)
pub fn byteGetDesiredSize(c: *const ByteController) ?f64 {
    return switch (streamSlots(c.stream).state) {
        .errored => null,
        .closed => 0,
        .readable => c.strategy_hwm - @as(f64, @floatFromInt(c.queue_total_size)),
    };
}

/// ReadableByteStreamControllerHandleQueueDrain(controller)
fn byteHandleQueueDrain(realm: Realm, c: *ByteController) void {
    // Step 2: drained after a close request: close.
    if (c.queue_total_size == 0 and c.close_requested) {
        byteClearAlgorithms(c);
        close(realm, c.stream);
    } else {
        // Step 3
        const controller_instance = streamSlots(c.stream).controller.?;
        byteCallPullIfNeeded(realm, controller_instance);
    }
}

/// ReadableByteStreamControllerInvalidateBYOBRequest(controller)
fn byteInvalidateByobRequest(c: *ByteController) void {
    const request_instance = c.byob_request orelse return;
    if (byobRequestOf(request_instance)) |request| {
        // Steps 2-3
        request.controller = null;
        js.disposeOptional(&request.view);
    }
    // Step 4
    c.byob_request = null;
}

/// ReadableByteStreamControllerProcessPullIntoDescriptorsUsingQueue(controller).
/// The returned descriptors are shifted off the queue and owned by the caller.
fn byteProcessPullIntoDescriptorsUsingQueue(c: *ByteController) std.ArrayList(PullInto) {
    var filled: std.ArrayList(PullInto) = .empty;
    // Step 3
    while (c.pending_pull_intos.items.len > 0) {
        if (c.queue_total_size == 0) break;
        const descriptor = &c.pending_pull_intos.items[0];
        if (byteFillPullIntoDescriptorFromQueue(c, descriptor)) {
            const shifted = byteShiftPendingPullInto(c);
            filled.append(c.allocator, shifted) catch js.dispose(shifted.buffer);
        }
    }
    return filled;
}

/// ReadableByteStreamControllerProcessReadRequestsUsingQueue(controller)
fn byteProcessReadRequestsUsingQueue(realm: Realm, c: *ByteController) void {
    const stream = streamSlots(c.stream);
    const reader = readerSlots(stream.reader.?);
    // Step 3
    while (reader.read_requests.items.len > 0) {
        if (c.queue_total_size == 0) return;
        const request = reader.read_requests.orderedRemove(0);
        byteFillReadRequestFromQueue(realm, c, request);
    }
}

/// ReadableByteStreamControllerPullInto(controller, view, min, readIntoRequest).
/// `view` is borrowed.
fn bytePullInto(realm: Realm, controller_instance: *runtime.Instance, view: Value, min: u64, request: ReadIntoRequest) void {
    const c = byteControllerOf(controller_instance).?;
    const stream = streamSlots(c.stream);
    // Steps 2-4: element size and constructor from the view's kind.
    const info = js.describeView(view) orelse {
        const e = realm.typeError("view is not an ArrayBufferView") catch return request.vtable.drop(request.ctx);
        defer js.dispose(e);
        return request.vtable.err(request.ctx, realm, e);
    };
    const element_size = info.kind.elementSize();
    // Step 5: Let minimumFill be min × elementSize.
    const minimum_fill: usize = @as(usize, @intCast(min)) * element_size;
    // Steps 10-12: Let bufferResult be TransferArrayBuffer(view.[[ViewedArrayBuffer]]).
    const view_buffer = js.viewBuffer(view) catch return request.vtable.drop(request.ctx);
    defer js.dispose(view_buffer);
    const buffer = js.transferBuffer(view_buffer) orelse {
        // Step 11: an abrupt completion goes to the error steps.
        const e = realm.typeError("The view's buffer cannot be transferred") catch return request.vtable.drop(request.ctx);
        defer js.dispose(e);
        return request.vtable.err(request.ctx, realm, e);
    };
    // Step 13
    var descriptor = PullInto{
        .buffer = buffer,
        .buffer_byte_length = info.buffer_byte_length,
        .byte_offset = info.byte_offset,
        .byte_length = info.byte_length,
        .bytes_filled = 0,
        .minimum_fill = minimum_fill,
        .element_size = element_size,
        .view_kind = info.kind,
        .reader_type = .byob,
    };
    // Step 14: behind other pending reads.
    if (c.pending_pull_intos.items.len > 0) {
        c.pending_pull_intos.append(c.allocator, descriptor) catch {
            js.dispose(buffer);
            return request.vtable.drop(request.ctx);
        };
        addReadIntoRequest(stream, request);
        return;
    }
    // Step 15: closed: an empty view of the same kind, as a close.
    if (stream.state == .closed) {
        defer js.dispose(buffer);
        const empty = js.newView(info.kind, buffer, info.byte_offset, 0) catch return request.vtable.drop(request.ctx);
        defer js.dispose(empty);
        return request.vtable.close(request.ctx, realm, empty);
    }
    // Step 16: fill from queued bytes.
    if (c.queue_total_size > 0) {
        if (byteFillPullIntoDescriptorFromQueue(c, &descriptor)) {
            // 16.1
            const filled_view = byteConvertPullIntoDescriptor(descriptor) orelse return request.vtable.drop(request.ctx);
            defer js.dispose(filled_view);
            byteHandleQueueDrain(realm, c);
            return request.vtable.chunk(request.ctx, realm, filled_view);
        }
        // 16.2: nothing more is coming.
        if (c.close_requested) {
            js.dispose(descriptor.buffer);
            const e = realm.typeError("Insufficient bytes to fill elements in the given buffer") catch return request.vtable.drop(request.ctx);
            defer js.dispose(e);
            byteControllerError(realm, controller_instance, e);
            return request.vtable.err(request.ctx, realm, e);
        }
    }
    // Steps 17-19
    c.pending_pull_intos.append(c.allocator, descriptor) catch {
        js.dispose(descriptor.buffer);
        return request.vtable.drop(request.ctx);
    };
    addReadIntoRequest(stream, request);
    byteCallPullIfNeeded(realm, controller_instance);
}

/// § 4.7.4 [[PullSteps]](readRequest)
fn bytePullSteps(realm: Realm, controller_instance: *runtime.Instance, c: *ByteController, request: ReadRequest) void {
    const stream = streamSlots(c.stream);
    // Step 3: take queued bytes.
    if (c.queue_total_size > 0) return byteFillReadRequestFromQueue(realm, c, request);
    // Step 5: auto-allocate a buffer for the source to fill.
    if (c.auto_allocate_chunk_size) |size| {
        const buffer = js.allocateBuffer(@intCast(size)) orelse {
            const e = realm.rangeError("Array buffer allocation failed") catch return request.vtable.drop(request.ctx);
            defer js.dispose(e);
            return request.vtable.err(request.ctx, realm, e);
        };
        c.pending_pull_intos.append(c.allocator, .{
            .buffer = buffer,
            .buffer_byte_length = @intCast(size),
            .byte_offset = 0,
            .byte_length = @intCast(size),
            .bytes_filled = 0,
            .minimum_fill = 1,
            .element_size = 1,
            .view_kind = .uint8,
            .reader_type = .default,
        }) catch {
            js.dispose(buffer);
            return request.vtable.drop(request.ctx);
        };
    }
    // Steps 6-7
    addReadRequest(stream, request);
    byteCallPullIfNeeded(realm, controller_instance);
}

/// ReadableByteStreamControllerRespond(controller, bytesWritten). Throws
/// (error.ExceptionPending) per steps 4-5.
pub fn byteRespond(realm: Realm, controller_instance: *runtime.Instance, bytes_written: u64) js.Error!void {
    const c = byteControllerOf(controller_instance).?;
    if (c.pending_pull_intos.items.len == 0) return throwTypeError(realm, "There is no pending read to respond to");
    const first = &c.pending_pull_intos.items[0];
    const state = streamSlots(c.stream).state;
    if (state == .closed) {
        // Step 4
        if (bytes_written != 0) return throwTypeError(realm, "bytesWritten must be 0 when the stream is closed");
    } else {
        // Step 5
        if (bytes_written == 0) return throwTypeError(realm, "bytesWritten must be greater than 0 when the stream is readable");
        if (first.bytes_filled + bytes_written > first.byte_length) {
            const e = try realm.rangeError("bytesWritten out of range");
            defer js.dispose(e);
            return realm.throwValue(e);
        }
    }
    // Step 6: Set firstDescriptor's buffer to ! TransferArrayBuffer(its buffer).
    const moved = js.transferBuffer(first.buffer) orelse return throwTypeError(realm, "The BYOB request's buffer cannot be transferred");
    js.dispose(first.buffer);
    first.buffer = moved;
    // Step 7
    try byteRespondInternal(realm, controller_instance, @intCast(bytes_written));
}

/// ReadableByteStreamControllerRespondInClosedState(controller, firstDescriptor)
fn byteRespondInClosedState(realm: Realm, c: *ByteController) void {
    const stream = streamSlots(c.stream);
    // Step 2: a detached pull-into just goes.
    if (c.pending_pull_intos.items[0].reader_type == .none) {
        const shifted = byteShiftPendingPullInto(c);
        js.dispose(shifted.buffer);
    }
    // Step 4: each BYOB read completes, empty.
    if (hasByobReader(stream)) {
        var filled: std.ArrayList(PullInto) = .empty;
        defer filled.deinit(c.allocator);
        while (filled.items.len < getNumReadIntoRequests(stream) and c.pending_pull_intos.items.len > 0) {
            filled.append(c.allocator, byteShiftPendingPullInto(c)) catch break;
        }
        for (filled.items) |d| byteCommitPullIntoDescriptor(realm, stream, d);
    }
}

/// ReadableByteStreamControllerRespondInReadableState(controller, bytesWritten, pullIntoDescriptor)
fn byteRespondInReadableState(realm: Realm, controller_instance: *runtime.Instance, c: *ByteController, bytes_written: usize) js.Error!void {
    const stream = streamSlots(c.stream);
    const descriptor = &c.pending_pull_intos.items[0];
    // Step 2
    byteFillHeadPullIntoDescriptor(descriptor, bytes_written);
    // Step 3: a detached pull-into feeds the queue.
    if (descriptor.reader_type == .none) {
        try byteEnqueueDetachedPullIntoToQueue(realm, controller_instance, c);
        var filled = byteProcessPullIntoDescriptorsUsingQueue(c);
        defer filled.deinit(c.allocator);
        for (filled.items) |d| byteCommitPullIntoDescriptor(realm, stream, d);
        return;
    }
    // Step 4: not yet at the minimum fill: wait for more.
    if (descriptor.bytes_filled < descriptor.minimum_fill) return;
    // Step 5
    var shifted = byteShiftPendingPullInto(c);
    // Steps 6-8: a trailing partial element goes back to the queue.
    const remainder = shifted.bytes_filled % shifted.element_size;
    if (remainder > 0) {
        const end = shifted.byte_offset + shifted.bytes_filled;
        byteEnqueueClonedChunkToQueue(realm, controller_instance, c, shifted.buffer, end - remainder, remainder) catch |err| {
            js.dispose(shifted.buffer);
            return err;
        };
    }
    shifted.bytes_filled -= remainder;
    // Step 9
    var filled = byteProcessPullIntoDescriptorsUsingQueue(c);
    defer filled.deinit(c.allocator);
    // Steps 10-11
    byteCommitPullIntoDescriptor(realm, stream, shifted);
    for (filled.items) |d| byteCommitPullIntoDescriptor(realm, stream, d);
}

/// ReadableByteStreamControllerRespondInternal(controller, bytesWritten)
fn byteRespondInternal(realm: Realm, controller_instance: *runtime.Instance, bytes_written: usize) js.Error!void {
    const c = byteControllerOf(controller_instance).?;
    // Step 3
    byteInvalidateByobRequest(c);
    // Steps 4-6
    if (streamSlots(c.stream).state == .closed) {
        byteRespondInClosedState(realm, c);
    } else {
        try byteRespondInReadableState(realm, controller_instance, c, bytes_written);
    }
    // Step 7
    byteCallPullIfNeeded(realm, controller_instance);
}

/// ReadableByteStreamControllerRespondWithNewView(controller, view). `view`
/// is borrowed. Throws (error.ExceptionPending) per steps 5-9.
pub fn byteRespondWithNewView(realm: Realm, controller_instance: *runtime.Instance, view: Value) js.Error!void {
    const c = byteControllerOf(controller_instance).?;
    if (c.pending_pull_intos.items.len == 0) return throwTypeError(realm, "There is no pending read to respond to");
    const info = js.describeView(view) orelse return throwTypeError(realm, "view is not an ArrayBufferView");
    const first = &c.pending_pull_intos.items[0];
    // Steps 5-6
    if (streamSlots(c.stream).state == .closed) {
        if (info.byte_length != 0) return throwTypeError(realm, "The view's length must be 0 when the stream is closed");
    } else {
        if (info.byte_length == 0) return throwTypeError(realm, "The view's length must be greater than 0 when the stream is readable");
    }
    // Steps 7-9
    if (first.byte_offset + first.bytes_filled != info.byte_offset) return throwRange(realm, "The region specified by view does not match byobRequest");
    if (first.buffer_byte_length != info.buffer_byte_length) return throwRange(realm, "The buffer of view has different capacity than byobRequest");
    if (first.bytes_filled + info.byte_length > first.byte_length) return throwRange(realm, "The region specified by view is larger than byobRequest");
    // Steps 10-11: Set firstDescriptor's buffer to ? TransferArrayBuffer(view.[[ViewedArrayBuffer]]).
    const view_buffer = try js.viewBuffer(view);
    defer js.dispose(view_buffer);
    const moved = js.transferBuffer(view_buffer) orelse return throwTypeError(realm, "The view's buffer cannot be transferred");
    js.dispose(first.buffer);
    first.buffer = moved;
    // Step 12
    try byteRespondInternal(realm, controller_instance, info.byte_length);
}

fn throwRange(realm: Realm, message: []const u8) js.Error {
    const e = realm.rangeError(message) catch |err| return err;
    defer js.dispose(e);
    return realm.throwValue(e);
}

/// ReadableByteStreamControllerShiftPendingPullInto(controller)
fn byteShiftPendingPullInto(c: *ByteController) PullInto {
    return c.pending_pull_intos.orderedRemove(0);
}

/// ReadableByteStreamControllerShouldCallPull(controller)
fn byteShouldCallPull(c: *ByteController) bool {
    const stream = streamSlots(c.stream);
    // Steps 2-4
    if (stream.state != .readable or c.close_requested or !c.started) return false;
    // Steps 5-6: a reader waiting.
    if (hasDefaultReader(stream) and getNumReadRequests(stream) > 0) return true;
    if (hasByobReader(stream) and getNumReadIntoRequests(stream) > 0) return true;
    // Steps 7-10
    return (byteGetDesiredSize(c) orelse 0) > 0;
}

// ============================================================================
// Read requests backed by a promise (the public read() methods)
// ============================================================================

/// A read request that settles a promise with a ReadableStreamReadResult.
pub const PromiseReadRequest = struct {
    deferred: Deferred,
    allocator: std.mem.Allocator,

    pub fn create(realm: Realm, allocator: std.mem.Allocator) !*PromiseReadRequest {
        const self = try allocator.create(PromiseReadRequest);
        self.* = .{ .deferred = try Deferred.init(realm), .allocator = allocator };
        return self;
    }

    fn finish(self: *PromiseReadRequest) void {
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    fn settle(self: *PromiseReadRequest, realm: Realm, value: Value, done: bool) void {
        if (js.resultObject(realm, value, done, .dictionary)) |result| {
            defer js.dispose(result);
            self.deferred.resolve(realm, result);
        } else |_| {}
        self.finish();
    }

    fn chunk(ctx: *anyopaque, realm: Realm, value: Value) void {
        const self: *PromiseReadRequest = @ptrCast(@alignCast(ctx));
        self.settle(realm, value, false);
    }

    fn closeDefault(ctx: *anyopaque, realm: Realm) void {
        const self: *PromiseReadRequest = @ptrCast(@alignCast(ctx));
        const undef = realm.undefinedValue() catch return self.finish();
        defer js.dispose(undef);
        self.settle(realm, undef, true);
    }

    fn closeByob(ctx: *anyopaque, realm: Realm, value: ?Value) void {
        const self: *PromiseReadRequest = @ptrCast(@alignCast(ctx));
        if (value) |v| return self.settle(realm, v, true);
        const undef = realm.undefinedValue() catch return self.finish();
        defer js.dispose(undef);
        self.settle(realm, undef, true);
    }

    fn err(ctx: *anyopaque, realm: Realm, e: Value) void {
        const self: *PromiseReadRequest = @ptrCast(@alignCast(ctx));
        self.deferred.reject(realm, e);
        self.finish();
    }

    fn drop(ctx: *anyopaque) void {
        const self: *PromiseReadRequest = @ptrCast(@alignCast(ctx));
        self.finish();
    }

    const read_vtable = ReadRequest.VTable{ .chunk = chunk, .close = closeDefault, .err = err, .drop = drop };
    const read_into_vtable = ReadIntoRequest.VTable{ .chunk = chunk, .close = closeByob, .err = err, .drop = drop };

    pub fn asReadRequest(self: *PromiseReadRequest) ReadRequest {
        return .{ .ctx = self, .vtable = &read_vtable };
    }

    pub fn asReadIntoRequest(self: *PromiseReadRequest) ReadIntoRequest {
        return .{ .ctx = self, .vtable = &read_into_vtable };
    }
};

// ============================================================================
// ReadableStreamPipeTo (§ 4.9.1)
// ============================================================================

const PipeState = struct {
    allocator: std.mem.Allocator,
    source: *runtime.Instance,
    dest: *runtime.Instance,
    reader: *runtime.Instance,
    writer: *runtime.Instance,
    prevent_close: bool,
    prevent_abort: bool,
    prevent_cancel: bool,
    signal: ?*runtime.Instance,
    shutting_down: bool = false,
    /// The last write's promise, or null before any write.
    current_write: ?Value = null,
    promise: Deferred,
    /// Pending reactions, read requests and the pipe itself, each holding one reference.
    refs: usize = 1,
    /// A shutdown action to run once writes finish, and the error it carries.
    pending_action: ?Action = null,
    pending_error: ?Value = null,
    finalized: bool = false,
    /// abortAlgorithm is on the signal and holds a reference.
    abort_registered: bool = false,
    /// Bumped by every write, so a wait for writes can tell one started meanwhile.
    write_count: usize = 0,
    waited_write_count: usize = 0,

    const Action = enum { abort_dest, cancel_source, close_dest, abort_both, none };

    fn retain(self: *PipeState) *PipeState {
        self.refs += 1;
        return self;
    }

    fn release(self: *PipeState) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        js.disposeOptional(&self.current_write);
        js.disposeOptional(&self.pending_error);
        self.promise.deinit();
        self.allocator.destroy(self);
    }
};

/// ReadableStreamPipeTo(source, dest, preventClose, preventAbort, preventCancel, signal).
/// Returns an owned promise.
pub fn pipeTo(
    realm: Realm,
    source: *runtime.Instance,
    dest: *runtime.Instance,
    prevent_close: bool,
    prevent_abort: bool,
    prevent_cancel: bool,
    signal: ?*runtime.Instance,
) js.Error!Value {
    const allocator = streamSlots(source).allocator;
    // Steps 9-10: Acquire the reader and the writer.
    const reader = acquireDefaultReader(realm, source) catch return error.V8Failure;
    const writer = sw.acquireWriter(realm, dest) catch {
        defaultReaderRelease(realm, reader);
        return error.V8Failure;
    };
    // The pipe holds both through Zig pointers; wrapping registers them with
    // the wrapper cache, which keeps streams-graph objects for the realm.
    _ = realm.wrap(reader) catch {};
    _ = realm.wrap(writer) catch {};
    // Step 11: Set source.[[disturbed]] to true.
    streamSlots(source).disturbed = true;
    // Steps 12-13
    const state = try allocator.create(PipeState);
    state.* = .{
        .allocator = allocator,
        .source = source,
        .dest = dest,
        .reader = reader,
        .writer = writer,
        .prevent_close = prevent_close,
        .prevent_abort = prevent_abort,
        .prevent_cancel = prevent_cancel,
        .signal = signal,
        .promise = try Deferred.init(realm),
    };
    const result = try js.clone(state.promise.promise);

    // Step 14: the signal.
    if (signal) |sig| {
        if (interfaces.AbortSignal.get_aborted(sig) catch false) {
            // 14.2 If signal is aborted, perform abortAlgorithm and return promise.
            pipeAbortAlgorithm(state);
            state.release();
            return result;
        }
        // 14.3 Add abortAlgorithm to signal.
        if (abort_algorithms.add(sig, .{ .ctx = state.retain(), .run = pipeAbortAlgorithmErased })) |_| {
            state.abort_registered = true;
        } else |_| {
            state.refs -= 1;
        }
    }

    // Step 15, "errors must be propagated forward".
    const source_slots = streamSlots(source);
    if (source_slots.state == .errored) {
        pipeSourceErrored(state, source_slots.stored_error.?);
    } else if (readerSlots(reader).closed_promise) |closed| {
        realm.react(closed.promise, PipeState, state.retain(), pipeIgnore, onPipeSourceErrored) catch {
            state.refs -= 1;
        };
    }
    // "Errors must be propagated backward".
    const dest_slots = sw.streamOf(dest).?;
    if (dest_slots.state == .errored) {
        pipeDestErrored(state, dest_slots.stored_error.?);
    } else if (sw.writerOf(writer).?.closed_promise) |closed| {
        realm.react(closed.promise, PipeState, state.retain(), pipeIgnore, onPipeDestErrored) catch {
            state.refs -= 1;
        };
    }
    // "Closing must be propagated forward".
    if (source_slots.state == .closed) {
        pipeSourceClosed(state);
    } else if (readerSlots(reader).closed_promise) |closed| {
        realm.react(closed.promise, PipeState, state.retain(), onPipeSourceClosed, pipeIgnore) catch {
            state.refs -= 1;
        };
    }
    // "Closing must be propagated backward".
    if (sw.closeQueuedOrInFlight(dest_slots) or dest_slots.state == .closed) {
        const dest_closed = try realm.typeError("the destination writable stream closed before all data could be piped to it");
        defer js.dispose(dest_closed);
        if (!prevent_cancel) {
            pipeShutdownWithAction(state, .cancel_source, dest_closed);
        } else {
            pipeShutdown(state, dest_closed);
        }
    }
    // The pipe loop.
    pipeStep(state);
    state.release();
    return result;
}

fn pipeIgnore(state: *PipeState, _: Value) void {
    state.release();
}

/// "Errors must be propagated forward".
fn pipeSourceErrored(state: *PipeState, stored_error: Value) void {
    if (!state.prevent_abort) {
        pipeShutdownWithAction(state, .abort_dest, stored_error);
    } else {
        pipeShutdown(state, stored_error);
    }
}

/// "Errors must be propagated backward".
fn pipeDestErrored(state: *PipeState, stored_error: Value) void {
    if (!state.prevent_cancel) {
        pipeShutdownWithAction(state, .cancel_source, stored_error);
    } else {
        pipeShutdown(state, stored_error);
    }
}

/// "Closing must be propagated forward".
fn pipeSourceClosed(state: *PipeState) void {
    if (!state.prevent_close) {
        pipeShutdownWithAction(state, .close_dest, null);
    } else {
        pipeShutdown(state, null);
    }
}

fn onPipeSourceErrored(state: *PipeState, e: Value) void {
    defer state.release();
    pipeSourceErrored(state, e);
}

fn onPipeDestErrored(state: *PipeState, e: Value) void {
    defer state.release();
    pipeDestErrored(state, e);
}

fn onPipeSourceClosed(state: *PipeState, _: Value) void {
    defer state.release();
    pipeSourceClosed(state);
}

fn pipeAbortAlgorithmErased(ctx: *anyopaque) void {
    const state: *PipeState = @ptrCast(@alignCast(ctx));
    // The signal ran and dropped the algorithm: its reference is ours to end.
    state.abort_registered = false;
    pipeAbortAlgorithm(state);
    state.release();
}

/// Step 14.1: the abort algorithm.
fn pipeAbortAlgorithm(state: *PipeState) void {
    const realm = Realm.of(state.source) catch return;
    // 14.1.1 Let error be signal's abort reason.
    const reason = interfaces.AbortSignal.get_reason(state.signal.?) catch runtime.JSValue.jsUndefined;
    const err = realm.fromRuntime(reason) catch return;
    defer js.dispose(err);
    // 14.1.2-14.1.5: abort dest and/or cancel source, per the prevent flags.
    const action: PipeState.Action = if (!state.prevent_abort and !state.prevent_cancel)
        .abort_both
    else if (!state.prevent_abort)
        .abort_dest
    else if (!state.prevent_cancel)
        .cancel_source
    else
        .none;
    pipeShutdownWithAction(state, action, err);
}

/// One iteration: wait for the writer to be ready, then read one chunk.
fn pipeStep(state: *PipeState) void {
    if (state.shutting_down) return;
    const realm = Realm.of(state.source) catch return;
    const writer = sw.writerOf(state.writer) orelse return;
    const ready = writer.ready_promise orelse return;
    realm.react(ready.promise, PipeState, state.retain(), pipeReadyFulfilled, pipeIgnore) catch {
        state.refs -= 1;
    };
}

fn pipeReadyFulfilled(state: *PipeState, _: Value) void {
    defer state.release();
    if (state.shutting_down) return;
    const realm = Realm.of(state.source) catch return;
    const reader = readerOf(state.reader) orelse return;
    if (reader.stream == null) return;
    defaultReaderRead(realm, reader, .{ .ctx = state.retain(), .vtable = &pipe_read_vtable });
}

const pipe_read_vtable = ReadRequest.VTable{
    .chunk = pipeReadChunk,
    .close = pipeReadClose,
    .err = pipeReadError,
    .drop = pipeReadDrop,
};

fn pipeReadChunk(ctx: *anyopaque, realm: Realm, chunk: Value) void {
    const state: *PipeState = @ptrCast(@alignCast(ctx));
    defer state.release();
    // Write the chunk; the write's outcome is observed through dest's state.
    const writer = sw.writerOf(state.writer) orelse return;
    if (writer.stream != null) {
        if (sw.writerWrite(realm, writer, chunk)) |write_promise| {
            @import("v8").ffi.v8_Promise_MarkAsHandled(write_promise);
            js.disposeOptional(&state.current_write);
            state.current_write = write_promise;
            state.write_count += 1;
        } else |_| {}
    }
    // Next iteration after a microtask, as a resolved promise would.
    js.queueMicrotask(realm, PipeState, state.retain(), pipeContinue);
}

fn pipeContinue(state: *PipeState) void {
    pipeStep(state);
    state.release();
}

fn pipeReadClose(ctx: *anyopaque, _: Realm) void {
    const state: *PipeState = @ptrCast(@alignCast(ctx));
    state.release();
}

fn pipeReadError(ctx: *anyopaque, _: Realm, _: Value) void {
    const state: *PipeState = @ptrCast(@alignCast(ctx));
    state.release();
}

fn pipeReadDrop(ctx: *anyopaque) void {
    const state: *PipeState = @ptrCast(@alignCast(ctx));
    state.release();
}

/// "Shutdown with an action".
fn pipeShutdownWithAction(state: *PipeState, action: PipeState.Action, original_error: ?Value) void {
    // Steps 1-2
    if (state.shutting_down) return;
    state.shutting_down = true;
    state.pending_action = action;
    if (original_error) |e| state.pending_error = js.clone(e) catch null;
    // Step 3: let queued writes finish first while dest is writable.
    pipeAfterWrites(state);
}

/// "Shutdown".
fn pipeShutdown(state: *PipeState, err: ?Value) void {
    if (state.shutting_down) return;
    state.shutting_down = true;
    state.pending_action = null;
    if (err) |e| state.pending_error = js.clone(e) catch null;
    pipeAfterWrites(state);
}

/// Step 3 of both shutdowns: wait for every read chunk to be written while
/// dest is writable and not closing, then continue.
fn pipeAfterWrites(state: *PipeState) void {
    const realm = Realm.of(state.source) catch return;
    const dest = sw.streamOf(state.dest).?;
    if (dest.state == .writable and !sw.closeQueuedOrInFlight(dest)) {
        if (state.current_write) |w| {
            state.waited_write_count = state.write_count;
            realm.react(w, PipeState, state.retain(), pipeWriteSettled, pipeWriteSettled) catch {
                state.refs -= 1;
                pipeDoTheRest(state);
            };
            return;
        }
    }
    pipeDoTheRest(state);
}

fn pipeWriteSettled(state: *PipeState, _: Value) void {
    defer state.release();
    // Another write may have started meanwhile; wait for that one too.
    if (state.write_count != state.waited_write_count) return pipeAfterWrites(state);
    pipeDoTheRest(state);
}

/// Steps 4-6 of "shutdown with an action", or step 4 of "shutdown".
fn pipeDoTheRest(state: *PipeState) void {
    const realm = Realm.of(state.source) catch return;
    const action = state.pending_action orelse {
        pipeFinalize(state, state.pending_error);
        return;
    };
    const err = state.pending_error;
    const p: ?Value = switch (action) {
        .abort_dest => blk: {
            const e = err orelse break :blk null;
            break :blk sw.abort(realm, state.dest, e) catch null;
        },
        .cancel_source => blk: {
            const e = err orelse break :blk null;
            break :blk cancel(realm, state.source, e) catch null;
        },
        .close_dest => sw.writerCloseWithErrorPropagation(realm, sw.writerOf(state.writer).?) catch null,
        .abort_both => pipeAbortBoth(realm, state, err),
        .none => realm.promiseResolvedWithUndefined() catch null,
    };
    const promise = p orelse {
        pipeFinalize(state, err);
        return;
    };
    defer js.dispose(promise);
    // Steps 5-6: finalize with the original error, or the action's error.
    realm.react(promise, PipeState, state.retain(), pipeActionFulfilled, pipeActionRejected) catch {
        state.refs -= 1;
        pipeFinalize(state, err);
    };
}

/// "Getting a promise to wait for all" of the abort algorithm's actions.
fn pipeAbortBoth(realm: Realm, state: *PipeState, err: ?Value) ?Value {
    const e = err orelse (realm.undefinedValue() catch return null);
    defer if (err == null) js.dispose(e);
    const dest = sw.streamOf(state.dest).?;
    const source = streamSlots(state.source);
    const a = if (dest.state == .writable) sw.abort(realm, state.dest, e) catch null else realm.promiseResolvedWithUndefined() catch null;
    const b = if (source.state == .readable) cancel(realm, state.source, e) catch null else realm.promiseResolvedWithUndefined() catch null;
    return waitForAll(realm, state.allocator, &.{ a, b });
}

/// WebIDL "get a promise for waiting for all" of `promises` (each owned and
/// consumed). Owned result.
fn waitForAll(realm: Realm, allocator: std.mem.Allocator, promises: []const ?Value) ?Value {
    const all = allocator.create(WaitAll) catch return null;
    all.* = .{ .deferred = Deferred.init(realm) catch {
        allocator.destroy(all);
        return null;
    }, .allocator = allocator, .realm = realm, .remaining = 1 };
    for (promises) |maybe| {
        const p = maybe orelse continue;
        defer js.dispose(p);
        all.remaining += 1;
        realm.react(p, WaitAll, all, WaitAll.fulfilled, WaitAll.rejected) catch {
            all.remaining -= 1;
        };
    }
    const result = js.clone(all.deferred.promise) catch null;
    WaitAll.fulfilled(all, undefined);
    return result;
}

const WaitAll = struct {
    deferred: Deferred,
    allocator: std.mem.Allocator,
    realm: Realm,
    remaining: usize,
    rejected_once: bool = false,

    fn done(self: *WaitAll) void {
        self.remaining -= 1;
        if (self.remaining > 0) return;
        self.deferred.deinit();
        self.allocator.destroy(self);
    }

    fn fulfilled(self: *WaitAll, _: Value) void {
        if (self.remaining == 1 and !self.rejected_once) self.deferred.resolveUndefined(self.realm);
        self.done();
    }

    fn rejected(self: *WaitAll, reason: Value) void {
        if (!self.rejected_once) {
            self.rejected_once = true;
            self.deferred.reject(self.realm, reason);
        }
        self.done();
    }
};

fn pipeActionFulfilled(state: *PipeState, _: Value) void {
    defer state.release();
    pipeFinalize(state, state.pending_error);
}

fn pipeActionRejected(state: *PipeState, new_error: Value) void {
    defer state.release();
    pipeFinalize(state, new_error);
}

/// "Finalize", optionally with an error.
fn pipeFinalize(state: *PipeState, err: ?Value) void {
    if (state.finalized) return;
    state.finalized = true;
    const realm = Realm.of(state.source) catch return;
    // Step 1: Perform ! WritableStreamDefaultWriterRelease(writer).
    if (sw.writerOf(state.writer)) |w| {
        if (w.stream != null) sw.writerRelease(realm, state.writer);
    }
    // Steps 2-3: release the reader.
    if (readerOf(state.reader)) |r| {
        if (r.stream != null) defaultReaderRelease(realm, state.reader);
    }
    // Step 4: remove abortAlgorithm from signal, ending its reference.
    if (state.signal) |sig| {
        if (state.abort_registered) {
            state.abort_registered = false;
            abort_algorithms.remove(sig, state);
            state.release();
        }
    }
    // Steps 5-6
    if (err) |e| state.promise.reject(realm, e) else state.promise.resolveUndefined(realm);
}

// ============================================================================
// ReadableStreamDefaultTee (§ 4.9.1)
// ============================================================================

const DefaultTee = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    reader: *runtime.Instance,
    reading: bool = false,
    read_again: bool = false,
    canceled1: bool = false,
    canceled2: bool = false,
    reason1: ?Value = null,
    reason2: ?Value = null,
    branch1: ?*runtime.Instance = null,
    branch2: ?*runtime.Instance = null,
    cancel_promise: Deferred,
};

/// A tee branch's source: pull and cancel route to the shared tee state.
const TeeBranch = struct {
    tee: *anyopaque,
    second: bool,
    byte: bool,

    fn start(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
        return .{ .normal = try realm.undefinedValue() };
    }

    fn pull(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
        const self: *TeeBranch = @ptrCast(@alignCast(ctx.?));
        if (self.byte) {
            byteTeePull(realm, @ptrCast(@alignCast(self.tee)), self.second);
        } else {
            defaultTeePull(realm, @ptrCast(@alignCast(self.tee)));
        }
        return realm.promiseResolvedWithUndefined();
    }

    fn cancelBranch(ctx: ?*anyopaque, realm: Realm, _: *runtime.Instance, reason: Value) js.Error!Value {
        const self: *TeeBranch = @ptrCast(@alignCast(ctx.?));
        if (self.byte) return teeCancel(ByteTee, realm, @ptrCast(@alignCast(self.tee)), self.second, reason);
        return teeCancel(DefaultTee, realm, @ptrCast(@alignCast(self.tee)), self.second, reason);
    }

    fn deinitBranch(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *TeeBranch = @ptrCast(@alignCast(ctx.?));
        allocator.destroy(self);
    }

    const vtable = Source.VTable{ .start = start, .pull = pull, .cancel = cancelBranch, .deinit = deinitBranch };
};

/// ReadableStreamTee(stream, cloneForBranch2) with cloneForBranch2 false.
/// Returns the two branches.
pub fn tee(realm: Realm, stream_instance: *runtime.Instance) ![2]*runtime.Instance {
    const stream = streamSlots(stream_instance);
    // Step 3: a byte stream tees as bytes.
    if (byteControllerOf(stream.controller.?) != null) return byteTee(realm, stream_instance);
    return defaultTee(realm, stream_instance);
}

fn defaultTee(realm: Realm, stream_instance: *runtime.Instance) ![2]*runtime.Instance {
    const allocator = streamSlots(stream_instance).allocator;
    // Step 3: Let reader be ? AcquireReadableStreamDefaultReader(stream).
    const reader = try acquireDefaultReader(realm, stream_instance);
    _ = try realm.wrap(reader);
    // Steps 4-12
    const state = try allocator.create(DefaultTee);
    state.* = .{ .allocator = allocator, .stream = stream_instance, .reader = reader, .cancel_promise = try Deferred.init(realm) };
    // Steps 16-18: the branches.
    state.branch1 = try createReadableStream(realm, stream_instance.ctx, try teeSource(allocator, state, false, false), 1, .one);
    state.branch2 = try createReadableStream(realm, stream_instance.ctx, try teeSource(allocator, state, true, false), 1, .one);
    // Step 19: upon rejection of reader.[[closedPromise]], error both branches.
    if (readerSlots(reader).closed_promise) |closed| {
        try realm.react(closed.promise, DefaultTee, state, defaultTeeClosedFulfilled, defaultTeeClosedRejected);
    }
    // Step 20
    return .{ state.branch1.?, state.branch2.? };
}

fn teeSource(allocator: std.mem.Allocator, state: anytype, second: bool, byte: bool) !Source {
    const branch = try allocator.create(TeeBranch);
    branch.* = .{ .tee = state, .second = second, .byte = byte };
    return .{ .ctx = branch, .vtable = &TeeBranch.vtable };
}

fn defaultTeeClosedFulfilled(_: *DefaultTee, _: Value) void {}

fn defaultTeeClosedRejected(state: *DefaultTee, r: Value) void {
    const realm = Realm.of(state.stream) catch return;
    // 19.1-19.3
    defaultControllerError(realm, streamSlots(state.branch1.?).controller.?, r);
    defaultControllerError(realm, streamSlots(state.branch2.?).controller.?, r);
    if (!state.canceled1 or !state.canceled2) state.cancel_promise.resolveUndefined(realm);
}

/// Step 13: pullAlgorithm.
fn defaultTeePull(realm: Realm, state: *DefaultTee) void {
    // 13.1 Already reading: read again afterwards.
    if (state.reading) {
        state.read_again = true;
        return;
    }
    // 13.2
    state.reading = true;
    // 13.3-13.4
    const reader = readerOf(state.reader) orelse return;
    if (reader.stream == null) return;
    defaultReaderRead(realm, reader, .{ .ctx = state, .vtable = &default_tee_read_vtable });
}

const default_tee_read_vtable = ReadRequest.VTable{
    .chunk = defaultTeeChunk,
    .close = defaultTeeClose,
    .err = defaultTeeError,
    .drop = teeDrop,
};

fn teeDrop(_: *anyopaque) void {}

const TeeChunk = struct {
    state: *DefaultTee,
    chunk: Value,
};

fn defaultTeeChunk(ctx: *anyopaque, realm: Realm, chunk: Value) void {
    const state: *DefaultTee = @ptrCast(@alignCast(ctx));
    // 1. Queue a microtask for the rest.
    const task = state.allocator.create(TeeChunk) catch return;
    task.* = .{ .state = state, .chunk = js.clone(chunk) catch {
        state.allocator.destroy(task);
        return;
    } };
    js.queueMicrotask(realm, TeeChunk, task, defaultTeeChunkMicrotask);
}

fn defaultTeeChunkMicrotask(task: *TeeChunk) void {
    const state = task.state;
    defer {
        js.dispose(task.chunk);
        state.allocator.destroy(task);
    }
    const realm = Realm.of(state.stream) catch return;
    // 1.1 Set readAgain to false.
    state.read_again = false;
    // 1.4-1.5 Enqueue the chunk to each branch not canceled.
    if (!state.canceled1) {
        if (defaultControllerEnqueueCompletion(realm, streamSlots(state.branch1.?).controller.?, task.chunk) catch null) |e| js.dispose(e);
    }
    if (!state.canceled2) {
        if (defaultControllerEnqueueCompletion(realm, streamSlots(state.branch2.?).controller.?, task.chunk) catch null) |e| js.dispose(e);
    }
    // 1.6-1.7
    state.reading = false;
    if (state.read_again) defaultTeePull(realm, state);
}

fn defaultTeeClose(ctx: *anyopaque, realm: Realm) void {
    const state: *DefaultTee = @ptrCast(@alignCast(ctx));
    // Close steps 1-4
    state.reading = false;
    if (!state.canceled1) defaultControllerClose(realm, streamSlots(state.branch1.?).controller.?);
    if (!state.canceled2) defaultControllerClose(realm, streamSlots(state.branch2.?).controller.?);
    if (!state.canceled1 or !state.canceled2) state.cancel_promise.resolveUndefined(realm);
}

fn defaultTeeError(ctx: *anyopaque, _: Realm, _: Value) void {
    const state: *DefaultTee = @ptrCast(@alignCast(ctx));
    // Error steps 1: Set reading to false.
    state.reading = false;
}

/// Steps 14-15 (cancel1Algorithm / cancel2Algorithm), for both tee kinds.
fn teeCancel(comptime T: type, realm: Realm, state: *T, second: bool, reason: Value) js.Error!Value {
    // 1-2: record this branch's cancelation.
    if (second) {
        state.canceled2 = true;
        js.disposeOptional(&state.reason2);
        state.reason2 = try js.clone(reason);
    } else {
        state.canceled1 = true;
        js.disposeOptional(&state.reason1);
        state.reason1 = try js.clone(reason);
    }
    // 3: both canceled: cancel the stream with the composite reason.
    if (state.canceled1 and state.canceled2) {
        const composite = try js.arrayFrom(realm, &.{ state.reason1.?, state.reason2.? });
        defer js.dispose(composite);
        const cancel_result = try cancel(realm, state.stream, composite);
        defer js.dispose(cancel_result);
        state.cancel_promise.resolve(realm, cancel_result);
    }
    // 4: Return cancelPromise.
    return js.clone(state.cancel_promise.promise);
}

// ============================================================================
// ReadableByteStreamTee (§ 4.9.1)
// ============================================================================

const ByteTee = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    reader: *runtime.Instance,
    reading: bool = false,
    read_again_for_branch1: bool = false,
    read_again_for_branch2: bool = false,
    canceled1: bool = false,
    canceled2: bool = false,
    reason1: ?Value = null,
    reason2: ?Value = null,
    branch1: ?*runtime.Instance = null,
    branch2: ?*runtime.Instance = null,
    cancel_promise: Deferred,
};

fn byteTee(realm: Realm, stream_instance: *runtime.Instance) ![2]*runtime.Instance {
    const allocator = streamSlots(stream_instance).allocator;
    // Step 3
    const reader = try acquireDefaultReader(realm, stream_instance);
    _ = try realm.wrap(reader);
    // Steps 4-13
    const state = try allocator.create(ByteTee);
    state.* = .{ .allocator = allocator, .stream = stream_instance, .reader = reader, .cancel_promise = try Deferred.init(realm) };
    // Steps 21-23
    state.branch1 = try createReadableByteStream(realm, stream_instance.ctx, try teeSource(allocator, state, false, true));
    state.branch2 = try createReadableByteStream(realm, stream_instance.ctx, try teeSource(allocator, state, true, true));
    // Step 24: Perform forwardReaderError, given reader.
    byteTeeForwardReaderError(realm, state, reader);
    // Step 25
    return .{ state.branch1.?, state.branch2.? };
}

const ForwardError = struct {
    state: *ByteTee,
    this_reader: *runtime.Instance,
};

/// Step 14: forwardReaderError(thisReader).
fn byteTeeForwardReaderError(realm: Realm, state: *ByteTee, this_reader: *runtime.Instance) void {
    const closed = readerSlots(this_reader).closed_promise orelse return;
    const ctx = state.allocator.create(ForwardError) catch return;
    ctx.* = .{ .state = state, .this_reader = this_reader };
    realm.react(closed.promise, ForwardError, ctx, forwardErrorFulfilled, forwardErrorRejected) catch state.allocator.destroy(ctx);
}

fn forwardErrorFulfilled(ctx: *ForwardError, _: Value) void {
    ctx.state.allocator.destroy(ctx);
}

fn forwardErrorRejected(ctx: *ForwardError, r: Value) void {
    const state = ctx.state;
    defer state.allocator.destroy(ctx);
    // 14.1.1 If thisReader is not reader, return.
    if (ctx.this_reader != state.reader) return;
    const realm = Realm.of(state.stream) catch return;
    // 14.1.2-14.1.4
    byteControllerError(realm, streamSlots(state.branch1.?).controller.?, r);
    byteControllerError(realm, streamSlots(state.branch2.?).controller.?, r);
    if (!state.canceled1 or !state.canceled2) state.cancel_promise.resolveUndefined(realm);
}

/// Steps 17-18: pull1Algorithm / pull2Algorithm.
fn byteTeePull(realm: Realm, state: *ByteTee, second: bool) void {
    // 1: already reading: read again for this branch afterwards.
    if (state.reading) {
        if (second) state.read_again_for_branch2 = true else state.read_again_for_branch1 = true;
        return;
    }
    // 2
    state.reading = true;
    // 3-5: a BYOB request on this branch means a BYOB read into its view.
    const branch = if (second) state.branch2.? else state.branch1.?;
    const byob_request = byteGetByobRequest(realm, streamSlots(branch).controller.?);
    if (byob_request) |req| {
        if (byobRequestOf(req)) |slots| {
            if (slots.view) |view| return byteTeePullWithByobReader(realm, state, view, second);
        }
    }
    byteTeePullWithDefaultReader(realm, state);
}

/// Step 15: pullWithDefaultReader.
fn byteTeePullWithDefaultReader(realm: Realm, state: *ByteTee) void {
    // 15.1: switch from a BYOB reader back to a default reader.
    if (readerOf(state.reader)) |r| {
        if (r.kind == .byob) {
            byobReaderRelease(realm, state.reader);
            state.reader = acquireDefaultReader(realm, state.stream) catch return;
            _ = realm.wrap(state.reader) catch {};
            byteTeeForwardReaderError(realm, state, state.reader);
        }
    }
    // 15.2-15.3
    const reader = readerOf(state.reader) orelse return;
    if (reader.stream == null) return;
    defaultReaderRead(realm, reader, .{ .ctx = state, .vtable = &byte_tee_read_vtable });
}

const byte_tee_read_vtable = ReadRequest.VTable{
    .chunk = byteTeeDefaultChunk,
    .close = byteTeeDefaultClose,
    .err = byteTeeError,
    .drop = teeDrop,
};

const ByteTeeChunk = struct {
    state: *ByteTee,
    chunk: Value,
    /// For a BYOB read: which branch it filled.
    for_branch2: bool = false,
    byob: bool = false,
};

fn byteTeeDefaultChunk(ctx: *anyopaque, realm: Realm, chunk: Value) void {
    const state: *ByteTee = @ptrCast(@alignCast(ctx));
    const task = state.allocator.create(ByteTeeChunk) catch return;
    task.* = .{ .state = state, .chunk = js.clone(chunk) catch {
        state.allocator.destroy(task);
        return;
    } };
    js.queueMicrotask(realm, ByteTeeChunk, task, byteTeeDefaultChunkMicrotask);
}

/// CloneAsUint8Array(O). Owned.
fn cloneAsUint8Array(view: Value) ?Value {
    const info = js.describeView(view) orelse return null;
    const buffer = js.viewBuffer(view) catch return null;
    defer js.dispose(buffer);
    const clone_buffer = js.allocateBuffer(info.byte_length) orelse return null;
    defer js.dispose(clone_buffer);
    if (js.bufferBytes(buffer)) |src| {
        if (js.bufferBytes(clone_buffer)) |dst| {
            if (info.byte_offset + info.byte_length <= src.len) @memcpy(dst[0..info.byte_length], src[info.byte_offset..][0..info.byte_length]);
        }
    }
    return js.newView(.uint8, clone_buffer, 0, info.byte_length) catch null;
}

fn byteTeeDefaultChunkMicrotask(task: *ByteTeeChunk) void {
    const state = task.state;
    defer {
        js.dispose(task.chunk);
        state.allocator.destroy(task);
    }
    const realm = Realm.of(state.stream) catch return;
    // 1.1-1.2
    state.read_again_for_branch1 = false;
    state.read_again_for_branch2 = false;
    // 1.3-1.4: the second branch gets a copy unless one is canceled.
    var chunk2: Value = task.chunk;
    var chunk2_owned = false;
    if (!state.canceled1 and !state.canceled2) {
        if (cloneAsUint8Array(task.chunk)) |copy| {
            chunk2 = copy;
            chunk2_owned = true;
        }
    }
    defer if (chunk2_owned) js.dispose(chunk2);
    // 1.5-1.6
    if (!state.canceled1) byteControllerEnqueue(realm, streamSlots(state.branch1.?).controller.?, task.chunk) catch {};
    if (!state.canceled2) byteControllerEnqueue(realm, streamSlots(state.branch2.?).controller.?, chunk2) catch {};
    // 1.7-1.9
    state.reading = false;
    if (state.read_again_for_branch1) {
        byteTeePull(realm, state, false);
    } else if (state.read_again_for_branch2) {
        byteTeePull(realm, state, true);
    }
}

fn byteTeeDefaultClose(ctx: *anyopaque, realm: Realm) void {
    const state: *ByteTee = @ptrCast(@alignCast(ctx));
    // Close steps 1-6
    state.reading = false;
    const c1 = streamSlots(state.branch1.?).controller.?;
    const c2 = streamSlots(state.branch2.?).controller.?;
    if (!state.canceled1) byteControllerClose(realm, c1) catch {};
    if (!state.canceled2) byteControllerClose(realm, c2) catch {};
    if (byteControllerOf(c1).?.pending_pull_intos.items.len > 0) byteRespond(realm, c1, 0) catch {};
    if (byteControllerOf(c2).?.pending_pull_intos.items.len > 0) byteRespond(realm, c2, 0) catch {};
    if (!state.canceled1 or !state.canceled2) state.cancel_promise.resolveUndefined(realm);
}

fn byteTeeError(ctx: *anyopaque, _: Realm, _: Value) void {
    const state: *ByteTee = @ptrCast(@alignCast(ctx));
    state.reading = false;
}

const ByobTeeRead = struct {
    state: *ByteTee,
    for_branch2: bool,
};

/// Step 16: pullWithBYOBReader(view, forBranch2). `view` is borrowed.
fn byteTeePullWithByobReader(realm: Realm, state: *ByteTee, view: Value, for_branch2: bool) void {
    // 16.1: switch to a BYOB reader.
    if (readerOf(state.reader)) |r| {
        if (r.kind == .default) {
            defaultReaderRelease(realm, state.reader);
            state.reader = acquireByobReader(realm, state.stream) catch return;
            _ = realm.wrap(state.reader) catch {};
            byteTeeForwardReaderError(realm, state, state.reader);
        }
    }
    const ctx = state.allocator.create(ByobTeeRead) catch return;
    ctx.* = .{ .state = state, .for_branch2 = for_branch2 };
    const reader = readerOf(state.reader) orelse return;
    if (reader.stream == null) return;
    // 16.5 Perform ! ReadableStreamBYOBReaderRead(reader, view, 1, readIntoRequest).
    byobReaderRead(realm, reader, view, 1, .{ .ctx = ctx, .vtable = &byob_tee_read_vtable });
}

const byob_tee_read_vtable = ReadIntoRequest.VTable{
    .chunk = byobTeeChunk,
    .close = byobTeeClose,
    .err = byobTeeError,
    .drop = byobTeeDrop,
};

fn byobTeeDrop(ctx: *anyopaque) void {
    const read: *ByobTeeRead = @ptrCast(@alignCast(ctx));
    read.state.allocator.destroy(read);
}

fn byobTeeChunk(ctx: *anyopaque, realm: Realm, chunk: Value) void {
    const read: *ByobTeeRead = @ptrCast(@alignCast(ctx));
    const state = read.state;
    const for_branch2 = read.for_branch2;
    state.allocator.destroy(read);
    const task = state.allocator.create(ByteTeeChunk) catch return;
    task.* = .{ .state = state, .chunk = js.clone(chunk) catch {
        state.allocator.destroy(task);
        return;
    }, .for_branch2 = for_branch2, .byob = true };
    js.queueMicrotask(realm, ByteTeeChunk, task, byobTeeChunkMicrotask);
}

fn byobTeeChunkMicrotask(task: *ByteTeeChunk) void {
    const state = task.state;
    defer {
        js.dispose(task.chunk);
        state.allocator.destroy(task);
    }
    const realm = Realm.of(state.stream) catch return;
    // 1.1-1.2
    state.read_again_for_branch1 = false;
    state.read_again_for_branch2 = false;
    // 1.3-1.4
    const byob_branch = if (task.for_branch2) state.branch2.? else state.branch1.?;
    const other_branch = if (task.for_branch2) state.branch1.? else state.branch2.?;
    const byob_canceled = if (task.for_branch2) state.canceled2 else state.canceled1;
    const other_canceled = if (task.for_branch2) state.canceled1 else state.canceled2;
    const byob_controller = streamSlots(byob_branch).controller.?;
    const other_controller = streamSlots(other_branch).controller.?;
    if (!other_canceled) {
        // 1.5: clone for the other branch.
        const cloned = cloneAsUint8Array(task.chunk) orelse return;
        defer js.dispose(cloned);
        if (!byob_canceled) byteRespondWithNewView(realm, byob_controller, task.chunk) catch {};
        byteControllerEnqueue(realm, other_controller, cloned) catch {};
    } else if (!byob_canceled) {
        // 1.6
        byteRespondWithNewView(realm, byob_controller, task.chunk) catch {};
    }
    // 1.7-1.9
    state.reading = false;
    if (state.read_again_for_branch1) {
        byteTeePull(realm, state, false);
    } else if (state.read_again_for_branch2) {
        byteTeePull(realm, state, true);
    }
}

fn byobTeeClose(ctx: *anyopaque, realm: Realm, chunk: ?Value) void {
    const read: *ByobTeeRead = @ptrCast(@alignCast(ctx));
    const state = read.state;
    const for_branch2 = read.for_branch2;
    state.allocator.destroy(read);
    // Close steps 1-7
    state.reading = false;
    const byob_branch = if (for_branch2) state.branch2.? else state.branch1.?;
    const other_branch = if (for_branch2) state.branch1.? else state.branch2.?;
    const byob_canceled = if (for_branch2) state.canceled2 else state.canceled1;
    const other_canceled = if (for_branch2) state.canceled1 else state.canceled2;
    const byob_controller = streamSlots(byob_branch).controller.?;
    const other_controller = streamSlots(other_branch).controller.?;
    if (!byob_canceled) byteControllerClose(realm, byob_controller) catch {};
    if (!other_canceled) byteControllerClose(realm, other_controller) catch {};
    if (chunk) |view| {
        if (!byob_canceled) byteRespondWithNewView(realm, byob_controller, view) catch {};
        if (!other_canceled and byteControllerOf(other_controller).?.pending_pull_intos.items.len > 0) byteRespond(realm, other_controller, 0) catch {};
    }
    if (!byob_canceled or !other_canceled) state.cancel_promise.resolveUndefined(realm);
}

fn byobTeeError(ctx: *anyopaque, _: Realm, _: Value) void {
    const read: *ByobTeeRead = @ptrCast(@alignCast(ctx));
    read.state.reading = false;
    read.state.allocator.destroy(read);
}

// ============================================================================
// Async iteration (§ 4.2.5) with WebIDL's asynchronous iterator machinery
// (next() and return() chain on the ongoing promise)
// ============================================================================

pub const AsyncIterator = struct {
    allocator: std.mem.Allocator,
    stream: *runtime.Instance,
    reader: *runtime.Instance,
    prevent_cancel: bool,
    /// The ongoing promise, owned.
    ongoing: ?Value = null,
    is_finished: bool = false,
    /// The last promise handed to script.
    returned: ?Value = null,
};

/// The asynchronous iterator initialization steps, and the iterator object.
/// Returns an owned object.
pub fn values(realm: Realm, stream_instance: *runtime.Instance, prevent_cancel: bool) !Value {
    const allocator = streamSlots(stream_instance).allocator;
    // Steps 1-2: Let reader be ? AcquireReadableStreamDefaultReader(stream).
    const reader = try acquireDefaultReader(realm, stream_instance);
    _ = try realm.wrap(reader);
    const it = try allocator.create(AsyncIterator);
    // Steps 3-4
    it.* = .{ .allocator = allocator, .stream = stream_instance, .reader = reader, .prevent_cancel = prevent_cancel };
    const ffi = @import("v8").ffi;
    const obj = ffi.v8_AsyncIterator_New(realm.isolate, realm.context, it, iteratorNextShim, iteratorReturnShim) orelse {
        allocator.destroy(it);
        return error.V8Failure;
    };
    return @ptrCast(obj);
}

fn iteratorGive(it: *AsyncIterator, promise: Value) *@import("v8").ffi.Promise {
    js.disposeOptional(&it.returned);
    it.returned = promise;
    return @ptrCast(promise);
}

fn iteratorNextShim(_: *@import("v8").ffi.Isolate, _: *@import("v8").ffi.Context, ptr: ?*anyopaque) callconv(.c) ?*@import("v8").ffi.Promise {
    const it: *AsyncIterator = @ptrCast(@alignCast(ptr orelse return null));
    const realm = Realm.of(it.stream) catch return null;
    const p = iteratorNext(realm, it) catch return null;
    return iteratorGive(it, p);
}

fn iteratorReturnShim(_: *@import("v8").ffi.Isolate, _: *@import("v8").ffi.Context, ptr: ?*anyopaque) callconv(.c) ?*@import("v8").ffi.Promise {
    const it: *AsyncIterator = @ptrCast(@alignCast(ptr orelse return null));
    const realm = Realm.of(it.stream) catch return null;
    const undef = realm.undefinedValue() catch return null;
    defer js.dispose(undef);
    const p = iteratorReturn(realm, it, undef) catch return null;
    return iteratorGive(it, p);
}

/// WebIDL § 3.7.10.2 %AsyncIteratorPrototype%.next(): run nextSteps after the
/// ongoing promise settles, or now. Owned promise.
fn iteratorNext(realm: Realm, it: *AsyncIterator) js.Error!Value {
    const deferred = try Deferred.init(realm);
    const step = try it.allocator.create(IterStep);
    step.* = .{ .it = it, .deferred = deferred, .kind = .next, .arg = null };
    const result = try js.clone(deferred.promise);
    if (it.ongoing) |ongoing| {
        // 7: afterOngoingPromise = PerformPromiseThen(ongoing, nextSteps, nextSteps)
        try realm.react(ongoing, IterStep, step, IterStep.run, IterStep.run);
    } else {
        // 8
        step.run(undefined);
    }
    // 9: Set object's ongoing promise to afterOngoingPromise.
    js.disposeOptional(&it.ongoing);
    it.ongoing = try js.clone(result);
    return result;
}

/// WebIDL %AsyncIteratorPrototype%.return(value). Owned promise.
fn iteratorReturn(realm: Realm, it: *AsyncIterator, value: Value) js.Error!Value {
    const deferred = try Deferred.init(realm);
    const step = try it.allocator.create(IterStep);
    step.* = .{ .it = it, .deferred = deferred, .kind = .ret, .arg = try js.clone(value) };
    const result = try js.clone(deferred.promise);
    if (it.ongoing) |ongoing| {
        try realm.react(ongoing, IterStep, step, IterStep.run, IterStep.run);
    } else {
        step.run(undefined);
    }
    return result;
}

const IterStep = struct {
    it: *AsyncIterator,
    deferred: Deferred,
    kind: enum { next, ret },
    arg: ?Value,

    fn finish(self: *IterStep) void {
        js.disposeOptional(&self.arg);
        self.deferred.deinit();
        self.it.allocator.destroy(self);
    }

    fn run(self: *IterStep, _: Value) void {
        const realm = Realm.of(self.it.stream) catch return self.finish();
        switch (self.kind) {
            .next => self.runNext(realm),
            .ret => self.runReturn(realm),
        }
    }

    fn resolveResult(self: *IterStep, realm: Realm, value: Value, done: bool) void {
        if (js.resultObject(realm, value, done, .iterator)) |r| {
            defer js.dispose(r);
            self.deferred.resolve(realm, r);
        } else |_| {}
    }

    /// nextSteps.
    fn runNext(self: *IterStep, realm: Realm) void {
        const it = self.it;
        // 2: finished: { value: undefined, done: true }.
        if (it.is_finished) {
            if (realm.undefinedValue()) |undef| {
                defer js.dispose(undef);
                self.resolveResult(realm, undef, true);
            } else |_| {}
            return self.finish();
        }
        // 4: get the next iteration result - § 4.2.5 steps 1-5.
        const reader = readerOf(it.reader) orelse return self.finish();
        if (reader.stream == null) {
            if (realm.typeError("The iterator's reader was released")) |e| {
                defer js.dispose(e);
                self.deferred.reject(realm, e);
            } else |_| {}
            return self.finish();
        }
        defaultReaderRead(realm, reader, .{ .ctx = self, .vtable = &iter_read_vtable });
    }

    /// returnSteps, then fulfillSteps: { value, done: true }.
    fn runReturn(self: *IterStep, realm: Realm) void {
        const it = self.it;
        const value = self.arg orelse return self.finish();
        // 2: finished already.
        if (it.is_finished) {
            self.resolveResult(realm, value, true);
            return self.finish();
        }
        // 3: Set object's is finished to true.
        it.is_finished = true;
        // 4: the asynchronous iterator return steps (§ 4.2.5).
        const reader_instance = it.reader;
        const reader = readerOf(reader_instance) orelse return self.finish();
        if (reader.stream == null) {
            self.resolveResult(realm, value, true);
            return self.finish();
        }
        if (!it.prevent_cancel) {
            // 4.1-4.3: cancel, release, then wait for the cancelation.
            const result = readerGenericCancel(realm, reader, value) catch return self.finish();
            defer js.dispose(result);
            defaultReaderRelease(realm, reader_instance);
            realm.react(result, IterStep, self, IterStep.returnFulfilled, IterStep.returnRejected) catch self.finish();
            return;
        }
        // 5-6
        defaultReaderRelease(realm, reader_instance);
        self.resolveResult(realm, value, true);
        self.finish();
    }

    fn returnFulfilled(self: *IterStep, _: Value) void {
        const realm = Realm.of(self.it.stream) catch return self.finish();
        if (self.arg) |v| self.resolveResult(realm, v, true);
        self.finish();
    }

    fn returnRejected(self: *IterStep, reason: Value) void {
        const realm = Realm.of(self.it.stream) catch return self.finish();
        self.deferred.reject(realm, reason);
        self.finish();
    }

    // The read request of "get the next iteration result".
    fn readChunk(ctx: *anyopaque, realm: Realm, chunk: Value) void {
        const self: *IterStep = @ptrCast(@alignCast(ctx));
        // chunk steps: resolve with chunk -> { value: chunk, done: false }.
        self.resolveResult(realm, chunk, false);
        self.finish();
    }

    fn readClose(ctx: *anyopaque, realm: Realm) void {
        const self: *IterStep = @ptrCast(@alignCast(ctx));
        // close steps: release the reader; end of iteration.
        defaultReaderRelease(realm, self.it.reader);
        self.it.is_finished = true;
        if (realm.undefinedValue()) |undef| {
            defer js.dispose(undef);
            self.resolveResult(realm, undef, true);
        } else |_| {}
        self.finish();
    }

    fn readError(ctx: *anyopaque, realm: Realm, e: Value) void {
        const self: *IterStep = @ptrCast(@alignCast(ctx));
        // error steps: release the reader; reject (rejectSteps: finished).
        defaultReaderRelease(realm, self.it.reader);
        self.it.is_finished = true;
        self.deferred.reject(realm, e);
        self.finish();
    }

    fn readDrop(ctx: *anyopaque) void {
        const self: *IterStep = @ptrCast(@alignCast(ctx));
        self.finish();
    }
};

const iter_read_vtable = ReadRequest.VTable{
    .chunk = IterStep.readChunk,
    .close = IterStep.readClose,
    .err = IterStep.readError,
    .drop = IterStep.readDrop,
};

// ============================================================================
// Engine-provided sources (CreateReadableStream for Zig callers)
// ============================================================================

/// A source whose start does nothing and whose pull and cancel resolve.
pub const noop_source = Source{ .ctx = null, .vtable = &noop_source_vtable };

const noop_source_vtable = Source.VTable{
    .start = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!js.Completion {
            return .{ .normal = try realm.undefinedValue() };
        }
    }.f,
    .pull = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance) js.Error!Value {
            return realm.promiseResolvedWithUndefined();
        }
    }.f,
    .cancel = struct {
        fn f(_: ?*anyopaque, realm: Realm, _: *runtime.Instance, _: Value) js.Error!Value {
            return realm.promiseResolvedWithUndefined();
        }
    }.f,
    .deinit = struct {
        fn f(_: ?*anyopaque, _: std.mem.Allocator) void {}
    }.f,
};
