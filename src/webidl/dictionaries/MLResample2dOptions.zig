//! WebIDL dictionary: MLResample2dOptions
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const MLOperatorOptions = @import("MLOperatorOptions.zig").MLOperatorOptions;

pub const MLResample2dOptions = struct {
    // Inherited from MLOperatorOptions
    base: MLOperatorOptions,

    mode: ?anyopaque = null,
    scales: ?anyopaque = null,
    sizes: ?anyopaque = null,
    axes: ?anyopaque = null,
};
