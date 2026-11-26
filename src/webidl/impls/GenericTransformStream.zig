//! Implementation for the GenericTransformStream mixin (Streams §7):
//! readable and writable, shared by CompressionStream, DecompressionStream,
//! SFrameDecryptorStream, SFrameEncryptorStream, TextDecoderStream, and
//! TextEncoderStream.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const GenericTransformStream = interfaces.GenericTransformStream;

pub const State = GenericTransformStream.State;

pub const ImplError = error{
    TypeError,
    InvalidState,
    NotImplemented,
};

pub const InternalState = struct {};

fn backingTransform(instance: *runtime.Instance) anyerror!*runtime.Instance {
    if (dom.streams_transform.genericTransformOf(instance)) |transform| {
        return transform;
    }
    if (instance.stateAs(interfaces.SFrameDecryptorStream.State) != null or
        instance.stateAs(interfaces.SFrameEncryptorStream.State) != null)
    {
        return error.NotImplemented;
    }
    return error.InvalidState;
}

/// Getter for readable (Streams §7): return this's transform's readable side.
pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const transform = try backingTransform(instance);
    return interfaces.TransformStream.get_readable(transform);
}

/// Getter for writable (Streams §7): return this's transform's writable side.
pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const transform = try backingTransform(instance);
    return interfaces.TransformStream.get_writable(transform);
}
