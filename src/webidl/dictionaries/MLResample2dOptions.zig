//! WebIDL dictionary: MLResample2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLResample2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?*const anyopaque = null,
    scales: ?*const anyopaque = null,
    sizes: ?*const anyopaque = null,
    axes: ?*const anyopaque = null,
};
