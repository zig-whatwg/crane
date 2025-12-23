//! Auto-generated mixin: Region
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const RegionImpl = @import("impls").Region;

// Re-export types from impl
pub const impl = @import("impls").Region;

pub fn get_regionOverset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return RegionImpl.get_regionOverset(instance);
}

pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!void {
    return RegionImpl.call_getRegionFlowRanges(instance);
}

