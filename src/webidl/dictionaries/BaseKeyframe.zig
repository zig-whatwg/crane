//! WebIDL dictionary: BaseKeyframe
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const BaseKeyframe = struct {
    offset: ?f64 = null,
    easing: ?runtime.DOMString = null,
    composite: ?enums.CompositeOperationOrAuto = null,
};
