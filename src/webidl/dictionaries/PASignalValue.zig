//! WebIDL dictionary: PASignalValue
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");

pub const PASignalValue = struct {
    baseValue: runtime.DOMString,
    scale: ?f64 = null,
    offset: ?*const anyopaque = null,
};
