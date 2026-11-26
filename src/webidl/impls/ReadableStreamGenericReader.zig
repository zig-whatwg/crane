//! Implementation for the ReadableStreamGenericReader mixin (Streams §4.4):
//! closed and cancel(reason), shared by ReadableStreamDefaultReader and
//! ReadableStreamBYOBReader.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const dom = @import("dom");
const js = dom.streams_js;
const srd = dom.streams_readable;
const sw = dom.streams_writable;
const ReadableStreamGenericReader = interfaces.ReadableStreamGenericReader;

pub const State = ReadableStreamGenericReader.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    OutOfMemory,
};

pub const InternalState = struct {};

/// Getter for closed (Streams §4.4.2): returns this reader's [[closedPromise]].
pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    return js.toReturnKept(reader.closed_promise.?.promise);
}

/// Operation: cancel (Streams §4.4.3):
/// 1. If this.[[stream]] is undefined, return a promise rejected with a TypeError.
/// 2. Return ! ReadableStreamReaderGenericCancel(this, reason).
pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    const reader = srd.readerOf(instance) orelse return error.TypeError;
    const realm = try js.Realm.of(instance);
    if (reader.stream == null)
        return sw.give(try realm.promiseRejectedWithTypeError("The reader has been released"));
    const r = try realm.fromOptional(reason);
    defer js.dispose(r);
    return sw.give(try srd.readerGenericCancel(realm, reader, r));
}
