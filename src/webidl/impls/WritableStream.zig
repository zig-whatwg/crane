//! WritableStream Implementation
//!
//! WHATWG Streams Standard § 5.2: https://streams.spec.whatwg.org/#ws-class
//!
//! The IDL surface only. The internal slots and abstract operations live in
//! `streams_writable.zig`, shared with the writer and the controller.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const WritableStream = interfaces.WritableStream;
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");

pub const State = WritableStream.State;
pub const InternalState = sw.Stream;
pub const StreamState = sw.StreamState;

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

/// `new WritableStream(underlyingSink, strategy)` - § 5.2.4.
pub fn call_constructor(ctx: runtime.Context, underlyingSink: webidl.Opt(runtime.JSValue), strategy: webidl.Opt(dictionaries.QueuingStrategy)) !*runtime.Instance {
    const realm = try js.Realm.ofContext(ctx);
    const strat = if (strategy.was_passed) strategy.value else dictionaries.QueuingStrategy{};

    // Step 1: If underlyingSink is missing, set it to null. It is typed
    // `object`, so undefined is "missing" and every other non-object throws.
    var sink_object: ?js.Value = null;
    defer js.disposeOptional(&sink_object);
    if (underlyingSink.was_passed) switch (underlyingSink.value) {
        .undefined => {},
        .handle => {
            const value = try realm.fromRuntime(underlyingSink.value);
            if (!js.isObject(value)) {
                js.dispose(value);
                return error.TypeError;
            }
            sink_object = value;
        },
        else => return error.TypeError,
    };

    // Steps 2-3: convert to the UnderlyingSink dictionary; a present `type`
    // is a RangeError.
    const dict = try sw.convertUnderlyingSink(realm, ctx.allocator, sink_object);
    var sink: ?sw.Sink = sw.sinkFromUnderlyingSink(dict);
    errdefer if (sink) |s| s.vtable.deinit(s.ctx, ctx.allocator);

    // Step 5: Let sizeAlgorithm be ! ExtractSizeAlgorithm(strategy).
    var size = try sw.extractSizeAlgorithm(strat);
    errdefer if (size == .callback) js.dispose(size.callback);

    // Step 6: Let highWaterMark be ? ExtractHighWaterMark(strategy, 1).
    const high_water_mark = try sw.extractHighWaterMark(strat, 1);

    // Step 4: Perform ! InitializeWritableStream(this).
    const instance = try sw.newStream(ctx);

    // Step 7: Perform ? SetUpWritableStreamDefaultControllerFromUnderlyingSink(
    // this, underlyingSink, underlyingSinkDict, highWaterMark, sizeAlgorithm).
    const controller = sw.newController(ctx, instance, sink.?, high_water_mark, size) catch |err| {
        runtime.Instance.deinit(instance);
        return err;
    };
    // The controller owns the algorithms from here.
    sink = null;
    size = .one;
    sw.setUpController(realm, instance, controller) catch |err| {
        // start() threw, after the controller was wrapped and handed to
        // script: it can still be reached and points at this stream, so the
        // stream is registered with the wrapper cache too and both live until
        // teardown instead of being freed under that reference.
        _ = realm.wrap(instance) catch {};
        return err;
    };
    return instance;
}

/// `locked` - § 5.2.4: Return ! IsWritableStreamLocked(this).
pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
    const stream = sw.streamOf(instance) orelse return error.TypeError;
    return sw.isLocked(stream);
}

/// `abort(reason)` - § 5.2.4.
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const stream = sw.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: A locked stream rejects with a TypeError.
    if (sw.isLocked(stream))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot abort a stream that is locked to a writer"));
    // Step 2: Return ! WritableStreamAbort(this, reason).
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(&stream.returned, try sw.abort(realm, instance, r));
}

/// `close()` - § 5.2.4.
pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const stream = sw.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: A locked stream rejects with a TypeError.
    if (sw.isLocked(stream))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot close a stream that is locked to a writer"));
    // Step 2: So does one already closing.
    if (sw.closeQueuedOrInFlight(stream))
        return sw.give(&stream.returned, try realm.promiseRejectedWithTypeError("Cannot close a stream that is already closing"));
    // Step 3: Return ! WritableStreamClose(this).
    return sw.give(&stream.returned, try sw.close(realm, instance));
}

/// `getWriter()` - § 5.2.4: Return ? AcquireWritableStreamDefaultWriter(this).
pub fn call_getWriter(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = sw.streamOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    return sw.acquireWriter(realm, instance);
}

/// Post-construction hook the V8 binding calls for every WritableStream.
/// The start algorithm already ran inside the constructor, where § 5.5.4
/// SetUpWritableStreamDefaultController step 15 puts it - so a throwing
/// start() is the constructor's exception - and there is nothing left to do.
/// The engine's controller wrapper, agent and realm handles it passes are
/// unused, and unnamed: they are the adapter's, not this impl's.
pub fn invokePendingStartCallback(
    instance: *runtime.Instance,
    _: *anyopaque,
    _: *anyopaque,
    _: *anyopaque,
) void {
    _ = instance;
}

/// WritableStreamCloseQueuedOrInFlight(stream), for code outside this family.
pub fn writableStreamCloseQueuedOrInFlight(internal: *const InternalState) bool {
    return sw.closeQueuedOrInFlight(internal);
}

/// For TransformStreamErrorWritableAndUnblockWrite step 2:
/// WritableStreamDefaultControllerErrorIfNeeded(stream.[[controller]], e).
pub fn writableStreamStartErroring(instance: *runtime.Instance, reason: runtime.JSValue) void {
    const stream = sw.streamOf(instance) orelse return;
    const controller = stream.controller orelse return;
    const realm = js.Realm.of(instance) catch return;
    const e = realm.fromRuntime(reason) catch return;
    defer js.dispose(e);
    sw.controllerErrorIfNeeded(realm, controller, e);
}
