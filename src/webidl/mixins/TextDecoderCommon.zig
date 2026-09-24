//! Auto-generated mixin: TextDecoderCommon
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextDecoderCommonImpl = @import("impls").TextDecoderCommon;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").TextDecoderCommon;

pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
    return try TextDecoderCommonImpl.get_encoding(instance);
}

pub fn get_fatal(instance: *runtime.Instance) anyerror!bool {
    return try TextDecoderCommonImpl.get_fatal(instance);
}

pub fn get_ignoreBOM(instance: *runtime.Instance) anyerror!bool {
    return try TextDecoderCommonImpl.get_ignoreBOM(instance);
}
