//! ReadableStreamDefaultReader Implementation
//!
//! WHATWG Streams Standard § 4.4: https://streams.spec.whatwg.org/#default-reader-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_readable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const sw = @import("streams_writable.zig");

pub const State = interfaces.ReadableStreamDefaultReader.State;
pub const InternalState = srd.Reader;

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

/// `new ReadableStreamDefaultReader(stream)` - § 4.4.3:
/// Perform ? SetUpReadableStreamDefaultReader(this, stream).
pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    _ = srd.streamOf(stream) orelse return error.TypeError;
    const realm = try js.Realm.ofContext(ctx);
    const reader = try srd.newReader(ctx, .default);
    errdefer runtime.Instance.deinit(reader);
    try srd.setUpDefaultReader(realm, reader, stream);
    return reader;
}

/// `closed` - § 4.3.3: Return this.[[closedPromise]].
pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    return js.toReturn(reader.closed_promise.?.promise);
}

/// `cancel(reason)` - § 4.3.3.
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: a released reader rejects with a TypeError.
    if (reader.stream == null)
        return sw.give(&reader.returned, try realm.promiseRejectedWithTypeError("The reader has been released"));
    // Step 2: Return ! ReadableStreamReaderGenericCancel(this, reason).
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(&reader.returned, try srd.readerGenericCancel(realm, reader, r));
}

/// `read()` - § 4.4.3.
pub fn call_read(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: a released reader rejects with a TypeError.
    if (reader.stream == null)
        return sw.give(&reader.returned, try realm.promiseRejectedWithTypeError("The reader has been released"));
    // Steps 2-3: a promise, and a read request that settles it.
    const request = try srd.PromiseReadRequest.create(realm, reader.allocator);
    const promise = try js.clone(request.deferred.promise);
    // Step 4: Perform ! ReadableStreamDefaultReaderRead(this, readRequest).
    srd.defaultReaderRead(realm, reader, request.asReadRequest());
    // Step 5: Return promise.
    return sw.give(&reader.returned, promise);
}

/// `releaseLock()` - § 4.4.3.
pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    // Step 1: If this.[[stream]] is undefined, return.
    if (reader.stream == null) return;
    // Step 2: Perform ! ReadableStreamDefaultReaderRelease(this).
    srd.defaultReaderRelease(try js.Realm.of(instance), instance);
}
