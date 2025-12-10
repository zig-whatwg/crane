//! WebIDL dictionary: PASignalValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const typedefs = @import("typedefs");

pub const PASignalValue = struct {
    baseValue: runtime.DOMString,
    scale: ?f64 = null,
    offset: ?runtime.JSValue = null,
};
