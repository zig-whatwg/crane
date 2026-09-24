//! Auto-generated mixin: SVGFilterPrimitiveStandardAttributes
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGFilterPrimitiveStandardAttributesImpl = @import("impls").SVGFilterPrimitiveStandardAttributes;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGAnimatedLength = @import("interfaces").SVGAnimatedLength;
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;

pub const impl = @import("impls").SVGFilterPrimitiveStandardAttributes;

pub fn get_x(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFilterPrimitiveStandardAttributesImpl.get_x(instance);
}

pub fn get_y(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFilterPrimitiveStandardAttributesImpl.get_y(instance);
}

pub fn get_width(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFilterPrimitiveStandardAttributesImpl.get_width(instance);
}

pub fn get_height(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFilterPrimitiveStandardAttributesImpl.get_height(instance);
}

pub fn get_result(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGFilterPrimitiveStandardAttributesImpl.get_result(instance);
}
