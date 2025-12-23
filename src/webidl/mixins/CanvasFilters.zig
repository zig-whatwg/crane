//! Auto-generated mixin: CanvasFilters
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const CanvasFiltersImpl = @import("impls").CanvasFilters;

// Re-export types from impl
pub const impl = @import("impls").CanvasFilters;

pub fn get_filter(instance: *runtime.Instance) anyerror!typedefs.DOMString {
    return CanvasFiltersImpl.get_filter(instance);
}

pub fn set_filter(instance: *runtime.Instance, value: typedefs.DOMString) !void {
    return CanvasFiltersImpl.set_filter(instance, value);
}

