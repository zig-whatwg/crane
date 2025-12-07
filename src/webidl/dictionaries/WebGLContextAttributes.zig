//! WebIDL dictionary: WebGLContextAttributes
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const v8 = @import("v8");
const enums = @import("enums");

pub const WebGLContextAttributes = struct {
    alpha: ?bool = null,
    depth: ?bool = null,
    stencil: ?bool = null,
    antialias: ?bool = null,
    premultipliedAlpha: ?bool = null,
    preserveDrawingBuffer: ?bool = null,
    powerPreference: ?enums.WebGLPowerPreference = null,
    failIfMajorPerformanceCaveat: ?bool = null,
    desynchronized: ?bool = null,
    xrCompatible: ?bool = null,
};
