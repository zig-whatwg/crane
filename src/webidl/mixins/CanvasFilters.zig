//! Auto-generated mixin: CanvasFilters
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasFiltersImpl = @import("impls").CanvasFilters;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const DOMString = @import("typedefs").DOMString;

pub const impl = @import("impls").CanvasFilters;

pub fn get_filter(instance: *runtime.Instance) anyerror!DOMString {
    return try CanvasFiltersImpl.get_filter(instance);
}

pub fn set_filter(instance: *runtime.Instance, value: DOMString) anyerror!void {
    try CanvasFiltersImpl.set_filter(instance, value);
}
