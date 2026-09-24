//! Auto-generated mixin: SVGElementInstance
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGElementInstanceImpl = @import("impls").SVGElementInstance;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGUseElement = @import("interfaces").SVGUseElement;
const SVGElement = @import("interfaces").SVGElement;

pub const impl = @import("impls").SVGElementInstance;

/// Extended attributes: [SameObject]
pub fn get_correspondingElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try SVGElementInstanceImpl.get_correspondingElement(instance);
}

/// Extended attributes: [SameObject]
pub fn get_correspondingUseElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    return try SVGElementInstanceImpl.get_correspondingUseElement(instance);
}
