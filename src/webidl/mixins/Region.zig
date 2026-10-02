//! Auto-generated mixin: Region
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RegionImpl = @import("impls").Region;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CSSOMString = @import("typedefs").CSSOMString;
const Range = @import("interfaces").Range;

pub const impl = @import("impls").Region;

/// The impl's process-wide hooks, installed once at process start
/// (crane.Process, through the root's process_hooks).
pub fn installHooks() void {
    const impls = @import("impls");
    if (comptime @hasDecl(impls, "Region")) {
        if (comptime @hasDecl(impls.Region, "installHooks")) impls.Region.installHooks();
    }
}

pub fn get_regionOverset(instance: *runtime.Instance) anyerror!CSSOMString {
    return try RegionImpl.get_regionOverset(instance);
}

pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    return try RegionImpl.call_getRegionFlowRanges(instance);
}
