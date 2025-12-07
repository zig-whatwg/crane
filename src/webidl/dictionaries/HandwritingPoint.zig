//! WebIDL dictionary: HandwritingPoint
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const HandwritingPoint = struct {
    x: f64,
    y: f64,
    t: ?typedefs.DOMHighResTimeStamp = null,
};
