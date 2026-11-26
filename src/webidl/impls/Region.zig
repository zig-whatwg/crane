//! Implementation for the Region mixin (CSS Regions):
//! regionOverset and getRegionFlowRanges(), included by Element.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const Region = interfaces.Region;

pub const State = Region.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Getter for regionOverset (CSS Regions not supported - empty string).
pub fn get_regionOverset(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    _ = instance;
    return .{ .empty = {} };
}

/// Operation: getRegionFlowRanges (CSS Regions not supported - null).
pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    _ = instance;
    return null;
}
