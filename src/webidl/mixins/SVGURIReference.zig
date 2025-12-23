//! Auto-generated mixin: SVGURIReference
//! Delegates to impl for actual implementation.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const SVGURIReferenceImpl = @import("impls").SVGURIReference;

// Re-export types from impl
pub const impl = @import("impls").SVGURIReference;

pub fn get_href(instance: *runtime.Instance) !*runtime.Instance {
    return SVGURIReferenceImpl.get_href(instance);
}

