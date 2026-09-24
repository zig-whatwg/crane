//! Auto-generated mixin: HTMLAttributionSrcElementUtils
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLAttributionSrcElementUtilsImpl = @import("impls").HTMLAttributionSrcElementUtils;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const USVString = @import("typedefs").USVString;

pub const impl = @import("impls").HTMLAttributionSrcElementUtils;

/// Extended attributes: [CEReactions], [SecureContext]
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    return try HTMLAttributionSrcElementUtilsImpl.get_attributionSrc(instance);
}

/// Extended attributes: [CEReactions], [SecureContext]
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    // [CEReactions] - Trigger Custom Element lifecycle callbacks
    runtime.CEReactions.begin();
    defer runtime.CEReactions.end();

    try HTMLAttributionSrcElementUtilsImpl.set_attributionSrc(instance, value);
}
