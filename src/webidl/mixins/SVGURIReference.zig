//! Auto-generated mixin: SVGURIReference
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGURIReferenceImpl = @import("impls").SVGURIReference;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGAnimatedString = @import("interfaces").SVGAnimatedString;

pub const impl = @import("impls").SVGURIReference;

/// Extended attributes: [SameObject]
pub fn get_href(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGURIReferenceImpl.get_href(instance);
}
