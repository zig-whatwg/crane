//! WebIDL dictionary: GPURequestAdapterOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const typedefs = @import("typedefs");
const enums = @import("enums");

pub const GPURequestAdapterOptions = struct {
    featureLevel: ?runtime.DOMString = null,
    powerPreference: ?enums.GPUPowerPreference = null,
    forceFallbackAdapter: ?bool = null,
    xrCompatible: ?bool = null,
};
