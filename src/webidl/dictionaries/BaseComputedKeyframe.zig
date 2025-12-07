//! WebIDL dictionary: BaseComputedKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const BaseComputedKeyframe = struct {
    offset: ?f64 = null,
    computedOffset: ?f64 = null,
    easing: ?runtime.DOMString = null,
    composite: ?enums.CompositeOperationOrAuto = null,
};
