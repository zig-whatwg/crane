//! WritableStreamDefaultWriter Implementation
//!
//! WHATWG Streams Standard § 5.3: https://streams.spec.whatwg.org/#default-writer-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_writable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const WritableStreamDefaultWriter = interfaces.WritableStreamDefaultWriter;
const js = @import("streams_js.zig");
const sw = @import("streams_writable.zig");

pub const State = WritableStreamDefaultWriter.State;
pub const InternalState = sw.Writer;

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

/// `new WritableStreamDefaultWriter(stream)` - § 5.3.3:
/// Perform ? SetUpWritableStreamDefaultWriter(this, stream).
pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    _ = sw.streamOf(stream) orelse return error.TypeError;
    const realm = try js.Realm.ofContext(ctx);
    const writer = try sw.newWriter(ctx);
    errdefer runtime.Instance.deinit(writer);
    try sw.setUpWriter(realm, writer, stream);
    return writer;
}

/// `closed` - § 5.3.3: Return this.[[closedPromise]].
pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    return js.toReturn(writer.closed_promise.?.promise);
}

/// `desiredSize` - § 5.3.3.
pub fn get_desiredSize(instance: *runtime.Instance) anyerror!?f64 {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    // Step 1: If this.[[stream]] is undefined, throw a TypeError.
    if (writer.stream == null) return error.TypeError;
    // Step 2: Return ! WritableStreamDefaultWriterGetDesiredSize(this).
    return sw.writerGetDesiredSize(writer);
}

/// `ready` - § 5.3.3: Return this.[[readyPromise]].
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    return js.toReturn(writer.ready_promise.?.promise);
}

/// `abort(reason)` - § 5.3.3.
pub fn call_abort(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: A released writer rejects with a TypeError.
    if (writer.stream == null)
        return sw.give(&writer.returned, try realm.promiseRejectedWithTypeError("The writer has been released"));
    // Step 2: Return ! WritableStreamDefaultWriterAbort(this, reason).
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(&writer.returned, try sw.writerAbort(realm, writer, r));
}

/// `close()` - § 5.3.3.
pub fn call_close(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Steps 1-2: A released writer rejects with a TypeError.
    const stream_instance = writer.stream orelse
        return sw.give(&writer.returned, try realm.promiseRejectedWithTypeError("The writer has been released"));
    // Step 3: So does a stream already closing.
    if (sw.closeQueuedOrInFlight(sw.streamOf(stream_instance).?))
        return sw.give(&writer.returned, try realm.promiseRejectedWithTypeError("The stream is already closing"));
    // Step 4: Return ! WritableStreamDefaultWriterClose(this).
    return sw.give(&writer.returned, try sw.writerClose(realm, writer));
}

/// `releaseLock()` - § 5.3.3.
pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    // Steps 1-2: If this.[[stream]] is undefined, return.
    if (writer.stream == null) return;
    // Steps 3-4: Perform ! WritableStreamDefaultWriterRelease(this).
    sw.writerRelease(try js.Realm.of(instance), instance);
}

/// `write(chunk)` - § 5.3.3.
pub fn call_write(instance: *runtime.Instance, chunk: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const writer = sw.writerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    // Step 1: A released writer rejects with a TypeError.
    if (writer.stream == null)
        return sw.give(&writer.returned, try realm.promiseRejectedWithTypeError("The writer has been released"));
    // Step 2: Return ! WritableStreamDefaultWriterWrite(this, chunk).
    const c = try realm.fromOptional(chunk);
    defer js.dispose(c);
    return sw.give(&writer.returned, try sw.writerWrite(realm, writer, c));
}
