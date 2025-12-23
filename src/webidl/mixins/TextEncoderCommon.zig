//! Auto-generated mixin: TextEncoderCommon
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const TextEncoderCommonImpl = @import("impls").TextEncoderCommon;

// Re-export types from impl
pub const impl = @import("impls").TextEncoderCommon;

pub fn get_encoding(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return TextEncoderCommonImpl.get_encoding(instance);
}

