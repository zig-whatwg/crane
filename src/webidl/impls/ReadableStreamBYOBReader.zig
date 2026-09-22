//! ReadableStreamBYOBReader Implementation
//!
//! WHATWG Streams Standard § 4.5: https://streams.spec.whatwg.org/#byob-reader-class
//!
//! The IDL surface only; the slots and algorithms are in `streams_readable.zig`.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const sw = @import("streams_writable.zig");

pub const State = interfaces.ReadableStreamBYOBReader.State;
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

/// `new ReadableStreamBYOBReader(stream)` - § 4.5.3:
/// Perform ? SetUpReadableStreamBYOBReader(this, stream).
pub fn call_constructor(ctx: runtime.Context, stream: *runtime.Instance) !*runtime.Instance {
    _ = srd.streamOf(stream) orelse return error.TypeError;
    const realm = try js.Realm.ofContext(ctx);
    const reader = try srd.newReader(ctx, .byob);
    errdefer runtime.Instance.deinit(reader);
    try srd.setUpByobReader(realm, reader, stream);
    return reader;
}

/// `closed` - § 4.3.3.
pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    return js.toReturn(reader.closed_promise.?.promise);
}

/// `cancel(reason)` - § 4.3.3.
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    if (reader.stream == null)
        return sw.give(&reader.returned, try realm.promiseRejectedWithTypeError("The reader has been released"));
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(&reader.returned, try srd.readerGenericCancel(realm, reader, r));
}

fn rejectWith(realm: js.Realm, reader: *srd.Reader, err: js.Error!js.Value) !runtime.JSValue {
    const e = try err;
    defer js.dispose(e);
    return sw.give(&reader.returned, try realm.promiseRejectedWith(e));
}

/// `read(view, options)` - § 4.5.3.
pub fn call_read(instance: *runtime.Instance, view: typedefs.ArrayBufferView, options: webidl.Opt(dictionaries.ReadableStreamBYOBReaderReadOptions)) anyerror!runtime.JSValue {
    // The IDL value owns its reference to the view object.
    const view_js: js.Value = @ptrCast(@alignCast(view.jsHandle() orelse return error.TypeError));
    defer js.dispose(view_js);
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    const info = js.describeView(view_js) orelse return error.TypeError;
    const opts = if (options.was_passed) options.value else dictionaries.ReadableStreamBYOBReaderReadOptions{};
    const min: u64 = opts.min orelse 1;
    // Steps 1-3: an empty view, an empty buffer or a detached one.
    if (info.byte_length == 0) return rejectWith(realm, reader, realm.typeError("view must have non-zero byteLength"));
    if (info.buffer_byte_length == 0) return rejectWith(realm, reader, realm.typeError("view's buffer must have non-zero byteLength"));
    if (info.buffer_detached) return rejectWith(realm, reader, realm.typeError("view's buffer has been detached"));
    // Step 4: min must be positive.
    if (min == 0) return rejectWith(realm, reader, realm.typeError("options.min must be greater than 0"));
    // Steps 5-6: and fit in the view.
    if (min > info.length) return rejectWith(realm, reader, realm.rangeError("options.min must be no greater than the view's length"));
    // Step 7: a released reader.
    if (reader.stream == null) return rejectWith(realm, reader, realm.typeError("The reader has been released"));
    // Steps 8-9
    const request = try srd.PromiseReadRequest.create(realm, reader.allocator);
    const promise = try js.clone(request.deferred.promise);
    // Step 10: Perform ! ReadableStreamBYOBReaderRead(this, view, options["min"], readIntoRequest).
    srd.byobReaderRead(realm, reader, view_js, min, request.asReadIntoRequest());
    // Step 11
    return sw.give(&reader.returned, promise);
}

/// `releaseLock()` - § 4.5.3.
pub fn call_releaseLock(instance: *runtime.Instance) anyerror!void {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    if (reader.stream == null) return;
    srd.byobReaderRelease(try js.Realm.of(instance), instance);
}
