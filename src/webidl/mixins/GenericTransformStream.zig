//! Auto-generated mixin: GenericTransformStream
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GenericTransformStreamImpl = @import("impls").GenericTransformStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const ReadableStream = @import("interfaces").ReadableStream;
const WritableStream = @import("interfaces").WritableStream;

pub const impl = @import("impls").GenericTransformStream;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "GenericTransformStream")) {
        if (comptime @hasDecl(impls.GenericTransformStream, "installHooks")) impls.GenericTransformStream.installHooks();
    }
}

pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try GenericTransformStreamImpl.get_readable(instance);
}

pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try GenericTransformStreamImpl.get_writable(instance);
}
