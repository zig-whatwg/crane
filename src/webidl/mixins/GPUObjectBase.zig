//! Auto-generated mixin: GPUObjectBase
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUObjectBaseImpl = @import("impls").GPUObjectBase;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").GPUObjectBase;

pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try GPUObjectBaseImpl.get_label(instance);
}

pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try GPUObjectBaseImpl.set_label(instance, value);
}
