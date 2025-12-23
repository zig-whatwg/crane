//! Auto-generated mixin: GenericTransformStream
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const GenericTransformStreamImpl = @import("impls").GenericTransformStream;

// Re-export types from impl
pub const impl = @import("impls").GenericTransformStream;

pub fn get_readable(instance: *runtime.Instance) !*runtime.Instance {
    return GenericTransformStreamImpl.get_readable(instance);
}

pub fn get_writable(instance: *runtime.Instance) !*runtime.Instance {
    return GenericTransformStreamImpl.get_writable(instance);
}

