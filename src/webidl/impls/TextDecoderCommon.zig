//! Implementation for the TextDecoderCommon mixin (Encoding §7.1):
//! encoding, fatal, and ignoreBOM, shared by TextDecoder and TextDecoderStream.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const TextDecoderCommon = interfaces.TextDecoderCommon;

pub const State = TextDecoderCommon.State;

pub const ImplError = error{
    InvalidState,
};

pub const InternalState = struct {};

/// Getter for encoding (Encoding §7.1): ASCII-lowercased name of this's encoding.
pub fn get_encoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    if (instance.stateAs(interfaces.TextDecoder.State)) |state| {
        return state.own.encoding;
    }
    if (dom.text_stream.decoderStreamProps(instance)) |props| {
        return runtime.DOMString.initOwned(try std.ascii.allocLowerString(instance.ctx.allocator, props.whatwg_name));
    }
    return error.InvalidState;
}

/// Getter for fatal (Encoding §7.1): true if this's error mode is "fatal".
pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
    if (instance.stateAs(interfaces.TextDecoder.State)) |state| {
        return state.own.fatal;
    }
    if (dom.text_stream.decoderStreamProps(instance)) |props| {
        return props.fatal;
    }
    return error.InvalidState;
}

/// Getter for ignoreBOM (Encoding §7.1): value of this's ignore BOM flag.
pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
    if (instance.stateAs(interfaces.TextDecoder.State)) |state| {
        return state.own.ignoreBOM;
    }
    if (dom.text_stream.decoderStreamProps(instance)) |props| {
        return props.ignore_bom;
    }
    return error.InvalidState;
}
