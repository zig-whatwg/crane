//! Auto-generated mixin: ReadableStreamGenericReader
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ReadableStreamGenericReaderImpl = @import("impls").ReadableStreamGenericReader;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");

pub const impl = @import("impls").ReadableStreamGenericReader;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "ReadableStreamGenericReader")) {
        if (comptime @hasDecl(impls.ReadableStreamGenericReader, "installHooks")) impls.ReadableStreamGenericReader.installHooks();
    }
}

pub fn get_closed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return try ReadableStreamGenericReaderImpl.get_closed(instance);
}

pub fn call_cancel(instance: *runtime.Instance, reason: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    return try ReadableStreamGenericReaderImpl.call_cancel(instance, reason);
}

/// WebIDL: operations whose return type is a promise - an exception in
/// their steps becomes a rejected promise.
pub const promise_returning = .{
    "call_cancel",
};
