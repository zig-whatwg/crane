//! ReadableStream Implementation
//!
//! WHATWG Streams Standard § 4.2: https://streams.spec.whatwg.org/#rs-class
//!
//! The IDL surface only. The internal slots and abstract operations live in
//! `streams_readable.zig`, shared with the readers and controllers.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const ReadableStream = interfaces.ReadableStream;
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const sw = @import("streams_writable.zig");

pub const State = ReadableStream.State;
pub const InternalState = srd.Stream;
pub const StreamState = srd.StreamState;

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |slots| {
        state.own._internal = null;
        slots.deinit();
    }
}

/// `new ReadableStream(underlyingSource, strategy)` - § 4.2.4.
pub fn call_constructor(ctx: runtime.Context, underlyingSource: webidl.Opt(runtime.JSValue), strategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    const realm = try js.Realm.ofContext(ctx);
    const strat = if (strategy.was_passed) strategy.value else dictionaries.QueuingStrategy{};

    // Step 1: If underlyingSource is missing, set it to null. It is typed
    // `object`: undefined is "missing", any other non-object throws.
    var source_object: ?js.Value = null;
    defer js.disposeOptional(&source_object);
    if (underlyingSource.was_passed) switch (underlyingSource.value) {
        .undefined => {},
        .handle => {
            const value = try realm.fromRuntime(underlyingSource.value);
            if (!js.isObject(value)) {
                js.dispose(value);
                return error.TypeError;
            }
            source_object = value;
        },
        else => return error.TypeError,
    };

    // Step 2: convert to the UnderlyingSource dictionary.
    const dict = try srd.convertUnderlyingSource(realm, ctx.allocator, source_object);
    var source: ?srd.Source = srd.sourceFromUnderlyingSource(dict);
    errdefer if (source) |s| s.vtable.deinit(s.ctx, ctx.allocator);

    if (dict.bytes) {
        // Step 4.1: a byte stream takes no size function.
        if (strat.size != null) return error.RangeError;
        // Step 4.2: Let highWaterMark be ? ExtractHighWaterMark(strategy, 0).
        const hwm = try sw.extractHighWaterMark(strat, 0);
        // SetUpReadableByteStreamControllerFromUnderlyingSource step 9.
        if (dict.auto_allocate_chunk_size) |size| {
            if (size == 0) return error.TypeError;
        }
        // Step 3: Perform ! InitializeReadableStream(this).
        const instance = try srd.newStream(ctx);
        // Step 4.3: SetUpReadableByteStreamControllerFromUnderlyingSource.
        const controller = srd.newByteController(ctx, instance, source.?, hwm, dict.auto_allocate_chunk_size) catch |err| {
            runtime.Instance.deinit(instance);
            return err;
        };
        source = null;
        srd.setUpByteController(realm, instance, controller) catch |err| {
            _ = realm.wrap(instance) catch {};
            return err;
        };
        return instance;
    }

    // Step 5.2: Let sizeAlgorithm be ! ExtractSizeAlgorithm(strategy).
    var size = try sw.extractSizeAlgorithm(strat);
    errdefer if (size == .callback) js.dispose(size.callback);
    // Step 5.3: Let highWaterMark be ? ExtractHighWaterMark(strategy, 1).
    const hwm = try sw.extractHighWaterMark(strat, 1);
    // Step 3: Perform ! InitializeReadableStream(this).
    const instance = try srd.newStream(ctx);
    // Step 5.4: SetUpReadableStreamDefaultControllerFromUnderlyingSource.
    const controller = srd.newDefaultController(ctx, instance, source.?, hwm, size) catch |err| {
        runtime.Instance.deinit(instance);
        return err;
    };
    source = null;
    size = .one;
    srd.setUpDefaultController(realm, instance, controller) catch |err| {
        // start() threw after the controller reached script; both stay
        // registered with the wrapper cache instead of being freed under it.
        _ = realm.wrap(instance) catch {};
        return err;
    };
    return instance;
}

/// `ReadableStream.from(asyncIterable)` - § 4.2.4:
/// Return ? ReadableStreamFromIterable(asyncIterable).
pub fn call_static_from(instance: *runtime.Instance, asyncIterable: runtime.JSValue) anyerror!*runtime.Instance {
    const realm = try js.Realm.of(instance);
    const iterable = try realm.fromRuntime(asyncIterable);
    defer js.dispose(iterable);
    return @import("streams_from.zig").fromIterable(realm, instance.ctx, iterable);
}

/// `locked` - § 4.2.4.
pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    return srd.isLocked(stream);
}

/// `cancel(reason)` - § 4.2.4.
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: A locked stream rejects with a TypeError.
    if (srd.isLocked(stream))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot cancel a stream that is locked to a reader"));
    // Step 2: Return ! ReadableStreamCancel(this, reason).
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(&stream.returned, try srd.cancel(realm, instance, r));
}

/// `getReader(options)` - § 4.2.4.
pub fn call_getReader(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ReadableStreamGetReaderOptions)) anyerror!typedefs.ReadableStreamReader {
    _ = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const opts = if (options.was_passed) options.value else dictionaries.ReadableStreamGetReaderOptions{};
    // Step 1: no mode: a default reader.
    if (opts.mode == null) return .{ .readable_stream_default_reader = try srd.acquireDefaultReader(realm, instance) };
    // Steps 2-3: mode "byob": a BYOB reader.
    return .{ .readable_stream_byobreader = try srd.acquireByobReader(realm, instance) };
}

/// The `readable` or `writable` member of a ReadableWritablePair arrives as
/// the V8 object; recover the instance it wraps.
fn unwrapPairMember(ptr: *const anyopaque) ?*runtime.Instance {
    const v8 = @import("v8");
    const untagged = v8.pointer_tag.untagPointer(ptr);
    if (untagged.tag == .runtime_instance) return @ptrCast(@alignCast(untagged.ptr));
    const value: *v8.ffi.Value = @ptrCast(untagged.ptr);
    if (!v8.ffi.v8_Value_IsObject(value)) return null;
    const obj: *v8.ffi.Object = @ptrCast(value);
    if (v8.ffi.v8_Object_InternalFieldCount(obj) == 0) return null;
    const instance_ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0) orelse return null;
    return @ptrCast(@alignCast(instance_ptr));
}

/// `pipeThrough(transform, options)` - § 4.2.4.
pub fn call_pipeThrough(instance: *runtime.Instance, transform: dictionaries.ReadableWritablePair, options: webidl.Opt(dictionaries.StreamPipeOptions)) anyerror!*runtime.Instance {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // The pair's members must be a WritableStream and a ReadableStream.
    const writable = unwrapPairMember(@ptrCast(transform.writable)) orelse return error.TypeError;
    const readable = unwrapPairMember(@ptrCast(transform.readable)) orelse return error.TypeError;
    const dest = sw.streamOf(writable) orelse return error.TypeError;
    _ = srd.streamOf(readable) orelse return error.TypeError;
    // Steps 1-2: neither end may be locked.
    if (srd.isLocked(stream)) return error.TypeError;
    if (sw.isLocked(dest)) return error.TypeError;
    // Steps 3-4
    const opts = if (options.was_passed) options.value else dictionaries.StreamPipeOptions{};
    const promise = try srd.pipeTo(realm, instance, writable, opts.preventClose orelse false, opts.preventAbort orelse false, opts.preventCancel orelse false, opts.signal);
    // Step 5: Set promise.[[PromiseIsHandled]] to true.
    @import("v8").ffi.v8_Promise_MarkAsHandled(promise);
    js.dispose(promise);
    // Step 6: Return transform["readable"].
    return readable;
}

/// `pipeTo(destination, options)` - § 4.2.4.
pub fn call_pipeTo(instance: *runtime.Instance, destination: *runtime.Instance, options: webidl.Opt(dictionaries.StreamPipeOptions)) anyerror!runtime.JSValue {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const dest = sw.streamOf(destination) orelse
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("pipeTo's destination is not a WritableStream"));
    // Step 1: a locked source rejects with a TypeError.
    if (srd.isLocked(stream))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot pipe a locked stream"));
    // Step 2: so does a locked destination.
    if (sw.isLocked(dest))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot pipe to a locked stream"));
    // Steps 3-4
    const opts = if (options.was_passed) options.value else dictionaries.StreamPipeOptions{};
    return sw.give(&stream.returned, try srd.pipeTo(realm, instance, destination, opts.preventClose orelse false, opts.preventAbort orelse false, opts.preventCancel orelse false, opts.signal));
}

/// `tee()` - § 4.2.4: Return ? ReadableStreamTee(this, false).
pub fn call_tee(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const branches = try srd.tee(realm, instance);
    const b1 = try realm.wrap(branches[0]);
    const b2 = try realm.wrap(branches[1]);
    return sw.give(&stream.returned, try js.arrayFrom(realm, &.{ b1, b2 }));
}

/// `values(options)` - § 4.2.5 async iterator.
pub fn call_values(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ReadableStreamIteratorOptions)) anyerror!runtime.JSValue {
    const stream = srd.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const opts = if (options.was_passed) options.value else dictionaries.ReadableStreamIteratorOptions{};
    return sw.give(&stream.returned, try srd.values(realm, instance, opts.preventCancel orelse false));
}

/// `[Symbol.asyncIterator](options)` - the same iterator as values().
pub fn call_getAsyncIterator(instance: *runtime.Instance, options: webidl.Opt(dictionaries.ReadableStreamIteratorOptions)) anyerror!runtime.JSValue {
    return call_values(instance, options);
}

/// Post-construction hooks the V8 binding calls. The start algorithm already
/// ran inside the constructor, where SetUpReadableStreamDefaultController
/// step 9 puts it, so there is nothing left to do.
pub fn invokePendingStartCallback(instance: *runtime.Instance, controller_v8: *anyopaque, v8_isolate: *anyopaque, v8_context: *anyopaque) void {
    _ = instance;
    _ = controller_v8;
    _ = v8_isolate;
    _ = v8_context;
}

pub fn invokePendingByteStartCallback(instance: *runtime.Instance, controller_v8: *anyopaque, v8_isolate: *anyopaque, v8_context: *anyopaque) void {
    _ = instance;
    _ = controller_v8;
    _ = v8_isolate;
    _ = v8_context;
}

// ============================================================================
// Zig-sourced streams (Blob.stream())
// ============================================================================

/// An underlying source implemented in Zig.
pub const ZigUnderlyingSource = struct {
    /// Called when the stream needs more data, with the controller.
    pull: ?*const fn (*runtime.Instance, ?*anyopaque) anyerror!void = null,
    /// Called when the stream is canceled.
    cancel: ?*const fn (?*const anyopaque, ?*anyopaque) anyerror!void = null,
    context: ?*anyopaque = null,
    is_byte_stream: bool = false,
    auto_allocate_chunk_size: ?u64 = null,
};

const ZigSource = struct {
    source: ZigUnderlyingSource,

    fn start(_: ?*anyopaque, realm: js.Realm, _: *runtime.Instance) js.Error!js.Completion {
        return .{ .normal = try realm.undefinedValue() };
    }

    fn pull(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
        const self: *ZigSource = @ptrCast(@alignCast(ctx.?));
        if (self.source.pull) |f| f(controller, self.source.context) catch |err| {
            const e = try realm.typeError(@errorName(err));
            defer js.dispose(e);
            return realm.promiseRejectedWith(e);
        };
        return realm.promiseResolvedWithUndefined();
    }

    fn cancel(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, reason: js.Value) js.Error!js.Value {
        const self: *ZigSource = @ptrCast(@alignCast(ctx.?));
        if (self.source.cancel) |f| f(@ptrCast(reason), self.source.context) catch {};
        return realm.promiseResolvedWithUndefined();
    }

    fn deinitSource(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
        const self: *ZigSource = @ptrCast(@alignCast(ctx.?));
        allocator.destroy(self);
    }

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancel, .deinit = deinitSource };
};

/// CreateReadableStream / CreateReadableByteStream over a Zig source.
pub fn createFromZigSource(allocator: std.mem.Allocator, ctx: runtime.Context, source: ZigUnderlyingSource) !*runtime.Instance {
    _ = allocator;
    const realm = js.Realm.ofContext(ctx) catch return error.NoEventLoop;
    const state = try ctx.allocator.create(ZigSource);
    state.* = .{ .source = source };
    const s = srd.Source{ .ctx = state, .vtable = &ZigSource.vtable };
    const stream = (if (source.is_byte_stream)
        srd.createReadableByteStream(realm, ctx, s)
    else
        srd.createReadableStream(realm, ctx, s, 1, .one)) catch return error.OutOfMemory;
    return stream;
}
