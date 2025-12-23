//! Auto-generated mixin: HTMLAttributionSrcElementUtils
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLAttributionSrcElementUtilsImpl = @import("impls").HTMLAttributionSrcElementUtils;

// Re-export types from impl
pub const impl = @import("impls").HTMLAttributionSrcElementUtils;

pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    return HTMLAttributionSrcElementUtilsImpl.get_attributionSrc(instance);
}

pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.JSValue) !void {
    return HTMLAttributionSrcElementUtilsImpl.set_attributionSrc(instance, value);
}

