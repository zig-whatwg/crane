//! Implementation for the TextEncoderCommon mixin (Encoding §7.4):
//! encoding (always "utf-8"), shared by TextEncoder and TextEncoderStream.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const TextEncoderCommon = interfaces.TextEncoderCommon;

pub const State = TextEncoderCommon.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for encoding (Encoding §7.4): "The encoding getter steps are to
/// return 'utf-8'."
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = instance;
    return runtime.DOMString.initInterned("utf-8");
}
