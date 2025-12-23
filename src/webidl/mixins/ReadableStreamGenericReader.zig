//! Auto-generated mixin: ReadableStreamGenericReader
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ReadableStreamGenericReaderImpl = @import("impls").ReadableStreamGenericReader;

// Re-export types from impl
pub const impl = @import("impls").ReadableStreamGenericReader;

pub fn get_closed(instance: *runtime.Instance) anyerror!void {
    return ReadableStreamGenericReaderImpl.get_closed(instance);
}

pub fn call_cancel(instance: *runtime.Instance, reason: runtime.JSValue) anyerror!void {
    return ReadableStreamGenericReaderImpl.call_cancel(instance, reason);
}

