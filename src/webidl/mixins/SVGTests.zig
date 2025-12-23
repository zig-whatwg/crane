//! Auto-generated mixin: SVGTests
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGTestsImpl = @import("impls").SVGTests;

// Re-export types from impl
pub const impl = @import("impls").SVGTests;

pub fn get_requiredExtensions(instance: *runtime.Instance) !*runtime.Instance {
    return SVGTestsImpl.get_requiredExtensions(instance);
}

pub fn get_systemLanguage(instance: *runtime.Instance) !*runtime.Instance {
    return SVGTestsImpl.get_systemLanguage(instance);
}

