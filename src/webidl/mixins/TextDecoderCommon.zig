//! Auto-generated mixin: TextDecoderCommon
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TextDecoderCommonImpl = @import("impls").TextDecoderCommon;

// Re-export types from impl
pub const impl = @import("impls").TextDecoderCommon;

pub fn get_encoding(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return TextDecoderCommonImpl.get_encoding(instance);
}

pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
    return TextDecoderCommonImpl.get_fatal(instance);
}

pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
    return TextDecoderCommonImpl.get_ignoreBOM(instance);
}

