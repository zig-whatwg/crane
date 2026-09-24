//! Auto-generated mixin: SVGTests
//! Its members' delegates to the mixin's impl, which every interface that
//! includes it inherits by alias.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SVGTestsImpl = @import("impls").SVGTests;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const SVGStringList = @import("interfaces").SVGStringList;

pub const impl = @import("impls").SVGTests;

/// Extended attributes: [SameObject]
pub fn get_requiredExtensions(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGTestsImpl.get_requiredExtensions(instance);
}

/// Extended attributes: [SameObject]
pub fn get_systemLanguage(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return try SVGTestsImpl.get_systemLanguage(instance);
}
